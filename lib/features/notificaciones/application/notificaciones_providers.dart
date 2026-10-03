import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/notificaciones_ws_provider.dart';
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

/// Historial reciente del usuario logueado (leídas y no leídas). El "tiempo
/// real" ahora es el mismo canal WS que usan firmas/recepciones/picking
/// (`notificacionesWsProvider`, sobre `/notificaciones/ws` — ver
/// `notificaciones_rout.py`): acá no hace falta filtrar por `tipo`/
/// `tipo_entidad` como en esos módulos, cualquier evento que llegue por
/// este canal ES una notificación nueva para este mismo feed, así que
/// cualquiera dispara la invalidación. `enableSilentRefresh` con intervalo
/// largo queda como red de respaldo si el WS no logra conectar/reconectar.
/// El conteo de no leídas y el badge (`WherehouseBottomNav`) se derivan de
/// esta misma lista (`.where((n) => !n.leida).length`) en vez de pedir
/// `/notificaciones/no-leidas/count` aparte — una sola fuente de verdad, y
/// como el badge está siempre visible, esto además mantiene el WS conectado
/// mientras la app esté abierta, no solo en la pantalla de notificaciones.
final misNotificacionesProvider = FutureProvider.autoDispose<List<Notificacion>>((ref) {
  enableSilentRefresh(ref, interval: const Duration(seconds: 60));

  ref.listen(notificacionesWsProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });

  return ref.watch(notificacionesRepositoryProvider).misNotificaciones();
});
