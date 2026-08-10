import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../data/productos_api.dart';
import '../data/proveedores_api.dart';
import '../data/stock_api.dart';
import '../data/stock_repository.dart';
import '../domain/stock_models.dart';

final stockApiProvider = Provider<StockApi>((ref) {
  return StockApi(ref.watch(dioClientProvider).dio);
});

final productosApiProvider = Provider<ProductosApi>((ref) {
  return ProductosApi(ref.watch(dioClientProvider).dio);
});

final proveedoresApiProvider = Provider<ProveedoresApi>((ref) {
  return ProveedoresApi(ref.watch(dioClientProvider).dio);
});

final stockRepositoryProvider = Provider<StockRepository>((ref) {
  return StockRepository(
    ref.watch(stockApiProvider),
    ref.watch(productosApiProvider),
    ref.watch(proveedoresApiProvider),
  );
});

enum StockSearchMode { nombre, ubicacion, proveedor }

final stockSearchModeProvider = StateProvider<StockSearchMode>(
  (ref) => StockSearchMode.nombre,
);

/// Texto de búsqueda ya debounceado (lo actualiza la UI con un Timer, ver
/// `StockSearchScreen`) — evita pegarle al backend en cada tecla.
final stockSearchQueryProvider = StateProvider<String>((ref) => '');

final productoResultsProvider =
    FutureProvider.autoDispose<List<ProductoConStock>>((ref) {
      enableSilentRefresh(ref);
      final q = ref.watch(stockSearchQueryProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(stockRepositoryProvider).buscarPorNombre(q);
    });

final ubicacionResultsProvider =
    FutureProvider.autoDispose<List<UbicacionStock>>((ref) {
      enableSilentRefresh(ref);
      final q = ref.watch(stockSearchQueryProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(stockRepositoryProvider).buscarUbicaciones(q);
    });

final proveedorResultsProvider =
    FutureProvider.autoDispose<List<ProveedorSimple>>((ref) {
      enableSilentRefresh(ref);
      final q = ref.watch(stockSearchQueryProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(stockRepositoryProvider).buscarProveedores(q);
    });

final existenciasPorUbicacionProvider = FutureProvider.family
    .autoDispose<List<ExistenciaStock>, int>((ref, idUbicacion) {
      enableSilentRefresh(ref);
      return ref
          .watch(stockRepositoryProvider)
          .existenciasDeUbicacion(idUbicacion);
    });

final productosPorProveedorProvider = FutureProvider.family
    .autoDispose<List<ProductoSimple>, int>((ref, idProveedor) {
      enableSilentRefresh(ref);
      return ref
          .watch(stockRepositoryProvider)
          .productosDeProveedor(idProveedor);
    });

final productoDetalleProvider = FutureProvider.family
    .autoDispose<ProductoStockDetalle, int>((ref, idProducto) {
      enableSilentRefresh(ref);
      return ref.watch(stockRepositoryProvider).detalleCompleto(idProducto);
    });
