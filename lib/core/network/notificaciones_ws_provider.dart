import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import '../providers.dart';

/// Piloto de WebSocket para eventos en tiempo real (ver `/notificaciones/ws`
/// en el backend, mismo broker en memoria que ya usa el SSE de la web).
///
/// Expone el stream crudo de eventos ya decodificados (se descartan acá los
/// `CONEXION_OK`/`PING` de control, que solo sirven para el heartbeat). Cada
/// feature que lo consuma decide qué hacer con cada evento — ver
/// `firmas_providers.dart` para el primer caso de uso.
///
/// `autoDispose`: se conecta solo mientras algo lo esté mirando (misma
/// filosofía que `enableSilentRefresh`) y se desconecta solo al cerrar la
/// pantalla. Reconecta con backoff exponencial (1s → 30s tope) ante
/// cualquier corte — caída de red, backend reiniciando, etc.
final notificacionesWsProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) async* {
  final secureStorage = ref.watch(secureStorageProvider);

  var backoff = const Duration(seconds: 1);
  const backoffMax = Duration(seconds: 30);

  while (true) {
    final token = await secureStorage.readToken();
    if (token == null) {
      // Sin sesión todavía (o se cerró): no tiene sentido conectar, esperar
      // un poco y reintentar en vez de quemar el loop.
      await Future.delayed(const Duration(seconds: 5));
      continue;
    }

    final wsBase = Env.apiBaseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase/notificaciones/ws').replace(
      queryParameters: {'token': token},
    );

    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(uri);
      await channel.ready;
      backoff = const Duration(seconds: 1); // conectó: resetea el backoff

      await for (final raw in channel.stream) {
        final data = jsonDecode(raw as String) as Map<String, dynamic>;
        if (data['tipo'] == 'CONEXION_OK' || data['tipo'] == 'PING') continue;
        yield data;
      }
    } catch (_) {
      // Conexión rechazada o cortada a mitad de camino: cae al backoff de
      // abajo y reintenta. Sin conexión real no hay nada más que loguear acá
      // (mismo criterio best-effort que el resto de tiempo real).
    } finally {
      await channel?.sink.close();
    }

    await Future.delayed(backoff);
    backoff = backoff * 2 > backoffMax ? backoffMax : backoff * 2;
  }
});
