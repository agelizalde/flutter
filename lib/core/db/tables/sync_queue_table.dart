import 'package:drift/drift.dart';

/// Cola de sincronización offline→online (ver CONTEXTO_WHEREHOUSE.md §6).
/// Toda escritura (completar tarea, confirmar traslado, etc.) se aplica
/// optimistamente en local y se encola acá; el SyncEngine la procesa cuando
/// hay conexión, en orden de creación.
class SyncQueueEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Entidad de negocio afectada, ej. 'traslado', 'tarea_picking'.
  TextColumn get entidad => text()();

  /// CREATE | UPDATE | ACTION (acciones como 'completar', 'confirmar').
  TextColumn get accion => text()();

  /// Path del endpoint backend a invocar (ej. '/traslados/ejecutar').
  TextColumn get endpoint => text()();

  /// Método HTTP del endpoint (POST/PATCH/etc.).
  TextColumn get metodoHttp => text()();

  /// Payload ya serializado en JSON.
  TextColumn get payloadJson => text()();

  /// `row_version` esperado, para detectar conflictos (CONTEXTO.md raíz §7.7).
  IntColumn get expectedVersion => integer().nullable()();

  IntColumn get intentos => integer().withDefault(const Constant(0))();

  /// PENDIENTE | ENVIADO | ERROR | CONFLICTO.
  TextColumn get estado => text().withDefault(const Constant('PENDIENTE'))();

  TextColumn get errorDetalle => text().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}
