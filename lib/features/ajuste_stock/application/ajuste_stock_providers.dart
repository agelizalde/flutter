import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../auth/application/auth_controller.dart';
import '../../recepcion/application/recepcion_providers.dart' show ubicacionesApiProvider;
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/application/stock_providers.dart'
    show productosApiProvider, stockRepositoryProvider;
import '../../stock/domain/stock_models.dart' show ProductoSimple;
import '../data/ajuste_stock_api.dart';
import '../data/ajuste_stock_repository.dart';
import '../domain/ajuste_stock_models.dart';

final ajusteStockApiProvider = Provider<AjusteStockApi>((ref) {
  return AjusteStockApi(ref.watch(dioClientProvider).dio);
});

final ajusteStockRepositoryProvider = Provider<AjusteStockRepository>((ref) {
  return AjusteStockRepository(
    ref.watch(ajusteStockApiProvider),
    ref.watch(ubicacionesApiProvider),
    ref.watch(stockRepositoryProvider),
    ref.watch(productosApiProvider),
  );
});

/// Búsqueda + filtro de estado del historial (`AjusteStockHomeScreen`).
final ajusteStockBusquedaProvider = StateProvider<String>((ref) => '');
final ajusteStockEstadoFiltroProvider = StateProvider<String?>((ref) => null);

final ajustesStockListadoProvider =
    FutureProvider.family.autoDispose<List<AjusteStock>, (String query, String? estado)>((ref, params) async {
  enableSilentRefresh(ref);
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];

  final (q, estado) = params;
  return ref.watch(ajusteStockRepositoryProvider).listar(
    q: q.isEmpty ? null : q,
    estado: estado,
    idAlmacen: usuario!.idAlmacenSeleccionado,
    limit: 50,
  );
});

final ajusteStockDetalleProvider =
    FutureProvider.family.autoDispose<AjusteStockDetalle, int>((ref, idAjusteStock) {
  enableSilentRefresh(ref);
  return ref.watch(ajusteStockRepositoryProvider).obtenerDetalle(idAjusteStock);
});

/// Búsqueda de producto para agregar items nuevos al conteo.
final ajusteBusquedaProductoProvider = StateProvider<String>((ref) => '');

final ajusteResultadosProductoProvider =
    FutureProvider.autoDispose<List<ProductoSimple>>((ref) {
  final q = ref.watch(ajusteBusquedaProductoProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(ajusteStockRepositoryProvider).buscarProductos(q);
});

/// Búsqueda de ubicación para el conteo (bottom sheet del formulario nuevo).
final ajusteBusquedaUbicacionProvider = StateProvider<String>((ref) => '');

final ajusteResultadosUbicacionProvider = FutureProvider.autoDispose<List<UbicacionSimple>>((ref) async {
  final q = ref.watch(ajusteBusquedaUbicacionProvider).trim();
  if (q.isEmpty) return const [];
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];
  return ref.watch(ajusteStockRepositoryProvider).buscarUbicaciones(
    idAlmacen: usuario!.idAlmacenSeleccionado!,
    q: q,
  );
});
