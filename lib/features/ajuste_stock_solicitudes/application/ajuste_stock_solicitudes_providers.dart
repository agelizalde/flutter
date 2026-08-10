import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../auth/application/auth_controller.dart';
import '../../recepcion/application/recepcion_providers.dart' show ubicacionesApiProvider;
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../data/ajuste_stock_solicitudes_api.dart';
import '../data/ajuste_stock_solicitudes_repository.dart';
import '../domain/solicitud_models.dart';

final ajusteStockSolicitudesApiProvider = Provider<AjusteStockSolicitudesApi>((ref) {
  return AjusteStockSolicitudesApi(ref.watch(dioClientProvider).dio);
});

final ajusteStockSolicitudesRepositoryProvider = Provider<AjusteStockSolicitudesRepository>((ref) {
  return AjusteStockSolicitudesRepository(
    ref.watch(ajusteStockSolicitudesApiProvider),
    ref.watch(ubicacionesApiProvider),
  );
});

/// Tareas pendientes asignadas al usuario logueado. Con `enableSilentRefresh`
/// para que el banner del Home y "Mis solicitudes" se mantengan al día sin
/// que el usuario tenga que refrescar manualmente (mismo patrón que
/// `misTareasProvider` de Picking).
final misSolicitudesPendientesProvider =
    FutureProvider.autoDispose<List<SolicitudAjusteStock>>((ref) {
  enableSilentRefresh(ref);
  return ref.watch(ajusteStockSolicitudesRepositoryProvider).misTareas();
});

/// Búsqueda de ubicación para el formulario de "Solicitar control".
final solicitudBusquedaUbicacionProvider = StateProvider<String>((ref) => '');

final solicitudResultadosUbicacionProvider = FutureProvider.autoDispose<List<UbicacionSimple>>((ref) async {
  final q = ref.watch(solicitudBusquedaUbicacionProvider).trim();
  if (q.isEmpty) return const [];
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];
  return ref.watch(ajusteStockSolicitudesRepositoryProvider).buscarUbicaciones(
    idAlmacen: usuario!.idAlmacenSeleccionado!,
    q: q,
  );
});

/// Búsqueda de usuario a quien asignar la solicitud.
final solicitudBusquedaUsuarioProvider = StateProvider<String>((ref) => '');

final solicitudResultadosUsuarioProvider = FutureProvider.autoDispose<List<UsuarioAsignable>>((ref) async {
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];
  final q = ref.watch(solicitudBusquedaUsuarioProvider).trim();
  return ref.watch(ajusteStockSolicitudesRepositoryProvider).usuariosAsignables(
    idAlmacen: usuario!.idAlmacenSeleccionado!,
    q: q.isEmpty ? null : q,
  );
});
