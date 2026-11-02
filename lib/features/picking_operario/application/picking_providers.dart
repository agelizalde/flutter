import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/notificaciones_ws_provider.dart';
import '../../../core/providers.dart';
import '../../../core/utils/refresco_por_accion.dart';
import '../../auth/application/auth_controller.dart';
import '../data/picking_api.dart';
import '../data/picking_repository.dart';
import '../domain/picking_models.dart';

final pickingApiProvider = Provider<PickingApi>((ref) {
  return PickingApi(ref.watch(dioClientProvider).dio);
});

final pickingRepositoryProvider = Provider<PickingRepository>((ref) {
  return PickingRepository(ref.watch(pickingApiProvider));
});

/// Eventos del broker que corresponden a una asignación/reasignación de
/// picking (ver `notificar_evento_modulo_bulk("PICKING", ...)` en
/// `asignacion_datos_service.py`) — mismo `tipo_entidad` que usa CONTROL,
/// así que hay que distinguir por `tipo`.
bool _esEventoPickingAsignado(Map<String, dynamic> evento) {
  return evento['tipo_entidad'] == 'PEDIDO_SUBPEDIDO' &&
      (evento['tipo'] == 'PICKING_ASIGNADO' || evento['tipo'] == 'PICKING_REASIGNADO');
}

/// Mis tareas + sesión activa. Se refresca con cada acción del usuario
/// (`refrescarEnAcciones`) y apenas llega un evento de asignación por
/// `notificacionesWsProvider` — igual que `firmasPendientesProvider`.
///
/// Heartbeat de la sesión de zona: antes lo hacía el polling de esta misma
/// lista (cada `GET` actualiza `ultima_actividad_en` server-side). Sin
/// polling, un operario parado en la pantalla sin pickear nada perdería la
/// sesión por inactividad (`sesion_idle_timeout_minutos`, default 10), así
/// que se pega a `/zona/sesion/activa` cada minuto IGNORANDO la respuesta:
/// mantiene viva la sesión sin tocar la UI.
final misTareasProvider = FutureProvider.autoDispose<MisTareasResponse>((ref) {
  refrescarEnAcciones(ref);

  final repo = ref.watch(pickingRepositoryProvider);
  final heartbeat = Timer.periodic(const Duration(minutes: 1), (_) {
    repo.sesionActiva().catchError((_) => null);
  });
  ref.onDispose(heartbeat.cancel);

  ref.listen(notificacionesWsProvider, (previous, next) {
    final evento = next.value;
    if (evento != null && _esEventoPickingAsignado(evento)) {
      ref.invalidateSelf();
    }
  });

  return ref.watch(pickingRepositoryProvider).misTareas();
});

/// Config efectiva de Ajustes -> Operaciones -> Picking para el almacén real
/// de un subpedido (ver [PickingConfig]) — a diferencia de [misTareasProvider]
/// no necesita refresh periódico: no cambia mientras dura una sesión de
/// picking, así que basta con pedirla una vez por subpedido.
final pickingConfigProvider = FutureProvider.autoDispose.family<PickingConfig, int>((ref, idPedidoSubpedido) {
  return ref.watch(pickingRepositoryProvider).config(idPedidoSubpedido: idPedidoSubpedido);
});

/// Gatea la tarjeta "Picking" del Home (ver `_ModuloDeposito` en
/// `home_screen.dart`): además del permiso `app.picking.ver` (chequeado
/// igual que el resto de los módulos), hace falta que "Habilitar picking
/// app" esté prendido en Ajustes -> Operaciones -> Picking -> APP - Picking
/// para el almacén BASE del usuario — el "kill switch" completo del
/// módulo, independiente de los permisos de rol (ver
/// `picking_config_service.py::app_picking_habilitado`). Mismo criterio que
/// `tienePuntoVentaAsignadoProvider` (pos_providers.dart): `false` tanto si
/// no tiene el permiso como si la config lo apaga o el pedido falla —
/// nunca se propaga como error visible en el Home.
final pickingAppHabilitadoProvider = FutureProvider.autoDispose<bool>((ref) async {
  final usuario = ref.watch(authControllerProvider).value;
  if (usuario == null || !usuario.tienePermiso('app.picking.ver')) return false;
  try {
    return await ref.watch(pickingRepositoryProvider).appHabilitado();
  } catch (_) {
    return false;
  }
});

/// Tareas de devolución/despickeo pendientes para el usuario logueado — se
/// refresca con cada acción del usuario, igual que [misTareasProvider].
final tareasDespickeoProvider = FutureProvider.autoDispose<List<TareaDespickeo>>((ref) {
  refrescarEnAcciones(ref);
  return ref.watch(pickingRepositoryProvider).misTareasDespickeo();
});
