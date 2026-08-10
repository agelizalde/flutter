import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../data/picking_control_api.dart';
import '../data/picking_control_repository.dart';
import '../domain/picking_control_models.dart';

final pickingControlApiProvider = Provider<PickingControlApi>((ref) {
  return PickingControlApi(ref.watch(dioClientProvider).dio);
});

final pickingControlRepositoryProvider = Provider<PickingControlRepository>((ref) {
  return PickingControlRepository(ref.watch(pickingControlApiProvider));
});

/// Lista de subpedidos disponibles para controlar, refrescada cada 20s
/// mientras la pantalla esté abierta (mismo criterio que `misTareasProvider`
/// en Picking Operario) — así el controlador ve aparecer cajones recién
/// cerrados sin tener que hacer pull-to-refresh a mano.
final subpedidosControlProvider = FutureProvider.autoDispose<List<SubpedidoControl>>((ref) {
  enableSilentRefresh(ref, interval: const Duration(seconds: 20));
  return ref.watch(pickingControlRepositoryProvider).subpedidos();
});

/// Detalle de un subpedido en control (header + sesión activa + ítems),
/// parametrizado por `idPedidoSubpedido`. Se invalida manualmente tras
/// iniciar una sesión o revisar un ítem para reflejar el progreso.
final detalleControlProvider = FutureProvider.autoDispose.family<DetalleControl, int>((ref, idPedidoSubpedido) {
  return ref.watch(pickingControlRepositoryProvider).detalle(idPedidoSubpedido);
});
