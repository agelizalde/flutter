import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../auth/application/auth_controller.dart';
import '../../recepcion/application/recepcion_providers.dart' show ubicacionesApiProvider;
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/application/stock_providers.dart'
    show productosApiProvider, stockRepositoryProvider;
import '../../stock/domain/stock_models.dart' show ExistenciaStock, ProductoConStock;
import '../data/traslados_api.dart';
import '../data/traslados_repository.dart';
import '../domain/traslado_models.dart';

final trasladosApiProvider = Provider<TrasladosApi>((ref) {
  return TrasladosApi(ref.watch(dioClientProvider).dio);
});

final trasladosRepositoryProvider = Provider<TrasladosRepository>((ref) {
  return TrasladosRepository(
    ref.watch(trasladosApiProvider),
    ref.watch(ubicacionesApiProvider),
    ref.watch(stockRepositoryProvider),
    ref.watch(productosApiProvider),
  );
});

/// Alertas de reacomodo ("Acomodos") del almacén base del usuario — ver
/// `traslados_ver.py::get_alertas_reacomodo`.
final trasladosAlertasProvider = FutureProvider.autoDispose<List<AlertaReacomodo>>((ref) async {
  enableSilentRefresh(ref);
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];
  return ref.watch(trasladosRepositoryProvider).alertasReacomodo(
    idAlmacen: usuario!.idAlmacenSeleccionado,
  );
});

/// Búsqueda + filtro de estado del historial (`TrasladosHistorialScreen`).
final trasladosBusquedaProvider = StateProvider<String>((ref) => '');
final trasladosEstadoFiltroProvider = StateProvider<String?>((ref) => null);

final trasladosListadoProvider =
    FutureProvider.family.autoDispose<List<Traslado>, (String query, String? estado)>((ref, params) async {
  enableSilentRefresh(ref);
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];

  final (q, estado) = params;
  return ref.watch(trasladosRepositoryProvider).listarTraslados(
    q: q.isEmpty ? null : q,
    estado: estado,
    idAlmacen: usuario!.idAlmacenSeleccionado,
    limit: 50,
  );
});

final trasladoDetalleProvider = FutureProvider.family.autoDispose<TrasladoDetalle, int>((ref, idTraspaso) {
  enableSilentRefresh(ref);
  return ref.watch(trasladosRepositoryProvider).obtenerDetalle(idTraspaso);
});

/// Búsqueda de producto para el flujo manual de traslado (mismo patrón que
/// `recepcionBusquedaProductoProvider`).
final trasladoBusquedaProductoProvider = StateProvider<String>((ref) => '');

final trasladoResultadosProductoProvider = FutureProvider.autoDispose<List<ProductoConStock>>((ref) {
  final q = ref.watch(trasladoBusquedaProductoProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(trasladosRepositoryProvider).buscarProductos(q);
});

final trasladoExistenciasDeProductoProvider =
    FutureProvider.family.autoDispose<List<ExistenciaStock>, int>((ref, idProducto) {
  return ref.watch(trasladosRepositoryProvider).existenciasDeProducto(idProducto);
});

/// Búsqueda de ubicación destino (bottom sheet del formulario de ejecutar).
final trasladoBusquedaUbicacionProvider = StateProvider<String>((ref) => '');

final trasladoResultadosUbicacionProvider = FutureProvider.autoDispose<List<UbicacionSimple>>((ref) async {
  final q = ref.watch(trasladoBusquedaUbicacionProvider).trim();
  if (q.isEmpty) return const [];
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];
  return ref.watch(trasladosRepositoryProvider).buscarUbicacionesDestino(
    idAlmacen: usuario!.idAlmacenSeleccionado!,
    q: q,
  );
});
