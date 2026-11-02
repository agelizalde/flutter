import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/notificaciones_ws_provider.dart';
import '../../../core/providers.dart';
import '../../../core/utils/refresco_por_accion.dart';
import '../data/picking_control_api.dart';
import '../data/picking_control_repository.dart';
import '../domain/picking_control_models.dart';

final pickingControlApiProvider = Provider<PickingControlApi>((ref) {
  return PickingControlApi(ref.watch(dioClientProvider).dio);
});

final pickingControlRepositoryProvider = Provider<PickingControlRepository>((ref) {
  return PickingControlRepository(ref.watch(pickingControlApiProvider));
});

/// Eventos del broker que corresponden a una asignación/reasignación de
/// controlador (ver `notificar_evento_modulo("CONTROL", ...)` en
/// `picking_control_service.py`) — mismo `tipo_entidad` que usa PICKING,
/// así que hay que distinguir por `tipo`.
bool _esEventoControlAsignado(Map<String, dynamic> evento) {
  return evento['tipo_entidad'] == 'PEDIDO_SUBPEDIDO' &&
      (evento['tipo'] == 'CONTROL_ASIGNADO' || evento['tipo'] == 'CONTROL_REASIGNADO');
}

/// Lista de subpedidos disponibles para controlar. Se refresca con cada
/// acción del usuario (`refrescarEnAcciones`) y, además, apenas llega un
/// evento de asignación por `notificacionesWsProvider` — así el
/// controlador ve aparecer cajones recién asignados sin hacer
/// pull-to-refresh a mano.
final subpedidosControlProvider = FutureProvider.autoDispose<List<SubpedidoControl>>((ref) {
  refrescarEnAcciones(ref);

  ref.listen(notificacionesWsProvider, (previous, next) {
    final evento = next.value;
    if (evento != null && _esEventoControlAsignado(evento)) {
      ref.invalidateSelf();
    }
  });

  return ref.watch(pickingControlRepositoryProvider).subpedidos();
});

/// Detalle de un subpedido en control (header + sesión activa + ítems),
/// parametrizado por `idPedidoSubpedido`. Se invalida manualmente tras
/// iniciar una sesión o revisar un ítem para reflejar el progreso.
final detalleControlProvider = FutureProvider.autoDispose.family<DetalleControl, int>((ref, idPedidoSubpedido) {
  return ref.watch(pickingControlRepositoryProvider).detalle(idPedidoSubpedido);
});
