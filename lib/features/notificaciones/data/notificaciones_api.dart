import 'package:dio/dio.dart';

import '../domain/notificacion_model.dart';

/// Llamadas a `/notificaciones/*` (ver `notificaciones_rout.py`). Sin SSE
/// acá — esta app pollea (`enableSilentRefresh`), mismo criterio que el
/// resto de "mis tareas" del proyecto.
class NotificacionesApi {
  NotificacionesApi(this._dio);

  final Dio _dio;

  Future<List<Notificacion>> misNotificaciones({bool soloNoLeidas = false, int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/notificaciones/mis-notificaciones',
      queryParameters: {'solo_no_leidas': soloNoLeidas, 'limit': limit},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Notificacion.fromJson).toList();
  }

  Future<void> marcarLeida(int idNotificacion) {
    return _dio.post<void>('/notificaciones/$idNotificacion/marcar-leida');
  }

  Future<void> marcarTodasLeidas() {
    return _dio.post<void>('/notificaciones/marcar-todas-leidas');
  }
}
