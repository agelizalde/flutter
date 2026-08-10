import '../domain/notificacion_model.dart';
import 'notificaciones_api.dart';

class NotificacionesRepository {
  NotificacionesRepository(this._api);

  final NotificacionesApi _api;

  Future<List<Notificacion>> misNotificaciones() => _api.misNotificaciones();

  Future<void> marcarLeida(int idNotificacion) => _api.marcarLeida(idNotificacion);

  Future<void> marcarTodasLeidas() => _api.marcarTodasLeidas();
}
