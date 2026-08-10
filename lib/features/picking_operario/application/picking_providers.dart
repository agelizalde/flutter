import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../data/picking_api.dart';
import '../data/picking_repository.dart';
import '../domain/picking_models.dart';

final pickingApiProvider = Provider<PickingApi>((ref) {
  return PickingApi(ref.watch(dioClientProvider).dio);
});

final pickingRepositoryProvider = Provider<PickingRepository>((ref) {
  return PickingRepository(ref.watch(pickingApiProvider));
});

/// Mis tareas + sesión activa. Se refresca solo cada 20s mientras la
/// pantalla que lo mira esté abierta (`enableSilentRefresh`) — además de
/// mantener la lista al día, cada `GET /mis-tareas` hace `GET
/// .../zona/sesion/activa` server-side, que ya actualiza
/// `ultima_actividad_en`: este mismo provider actúa como heartbeat de la
/// sesión mientras `PickingTrabajoScreen` está abierta, sin necesitar un
/// timer de heartbeat separado.
final misTareasProvider = FutureProvider.autoDispose<MisTareasResponse>((ref) {
  enableSilentRefresh(ref, interval: const Duration(seconds: 20));
  return ref.watch(pickingRepositoryProvider).misTareas();
});

/// Tareas de devolución/despickeo pendientes para el usuario logueado — se
/// refresca cada 20s igual que [misTareasProvider] mientras la pantalla que
/// lo mira esté abierta.
final tareasDespickeoProvider = FutureProvider.autoDispose<List<TareaDespickeo>>((ref) {
  enableSilentRefresh(ref, interval: const Duration(seconds: 20));
  return ref.watch(pickingRepositoryProvider).misTareasDespickeo();
});
