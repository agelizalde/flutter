import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../errors/app_exception.dart';
import '../network/dio_client.dart';

/// Procesa la cola de sincronización (CONTEXTO_WHEREHOUSE.md §6): toma las
/// entradas PENDIENTE en orden de creación y las reenvía al backend.
///
/// - Error de red (sin conexión) → se deja PENDIENTE, se reintenta después.
/// - 409 (conflicto de `row_version`) → pasa a CONFLICTO, no se reintenta sola.
/// - Otro error de negocio (400/422) → pasa a ERROR, no se reintenta sola.
/// - Éxito → se borra de la cola.
class SyncEngine {
  SyncEngine(this._db, this._dioClient);

  final AppDatabase _db;
  final DioClient _dioClient;

  bool _running = false;

  Future<void> processPending() async {
    if (_running) return;
    _running = true;
    try {
      final pendientes =
          await (_db.select(_db.syncQueueEntries)
                ..where((t) => t.estado.equals('PENDIENTE'))
                ..orderBy([(t) => OrderingTerm.asc(t.creadoEn)]))
              .get();

      for (final entry in pendientes) {
        await _processOne(entry);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _processOne(SyncQueueEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    if (entry.expectedVersion != null) {
      payload['expected_version'] = entry.expectedVersion;
    }

    try {
      await _dioClient.dio.request<dynamic>(
        entry.endpoint,
        data: payload,
        options: Options(method: entry.metodoHttp),
      );
      await _db.delete(_db.syncQueueEntries).delete(entry);
    } on DioException catch (e) {
      final error = e.error;
      if (error is NetworkException) {
        return; // sin conexión: se reintenta en la próxima pasada
      }
      final estado = error is ConflictException ? 'CONFLICTO' : 'ERROR';
      await _db
          .update(_db.syncQueueEntries)
          .replace(
            entry.copyWith(
              estado: estado,
              intentos: entry.intentos + 1,
              errorDetalle: Value(error.toString()),
            ),
          );
    }
  }
}
