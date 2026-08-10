import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../data/notificaciones_api.dart';
import '../data/notificaciones_repository.dart';
import '../domain/notificacion_model.dart';

final notificacionesApiProvider = Provider<NotificacionesApi>((ref) {
  return NotificacionesApi(ref.watch(dioClientProvider).dio);
});

final notificacionesRepositoryProvider = Provider<NotificacionesRepository>((ref) {
  return NotificacionesRepository(ref.watch(notificacionesApiProvider));
});

/// Historial reciente del usuario logueado (leídas y no leídas). Con
/// `enableSilentRefresh` — no hay SSE en esta app, el "tiempo real" es
/// pollear cada 15s, mismo patrón que `misSolicitudesPendientesProvider`/
/// `misTareasProvider`. El conteo de no leídas y el badge se derivan de
/// esta misma lista (`.where((n) => !n.leida).length`) en vez de pedir
/// `/notificaciones/no-leidas/count` aparte — un solo poll, una sola fuente
/// de verdad.
final misNotificacionesProvider = FutureProvider.autoDispose<List<Notificacion>>((ref) {
  enableSilentRefresh(ref);
  return ref.watch(notificacionesRepositoryProvider).misNotificaciones();
});
