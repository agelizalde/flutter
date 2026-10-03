import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/network/notificaciones_ws_provider.dart';
import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../recepcion/application/recepcion_providers.dart' show ubicacionesApiProvider;
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../data/productos_api.dart';
import '../data/proveedores_api.dart';
import '../data/stock_api.dart';
import '../data/stock_repository.dart';
import '../domain/stock_models.dart';

/// `true` si el evento del WS es un `STOCK_CAMBIO` (broadcast, sin
/// destinatario puntual — ver `stock_broadcast.py`). A diferencia de
/// firmas/recepciones/picking, acá no hay `id_usuario_destino`: cualquiera
/// que esté mirando ese producto/ubicación se tiene que enterar.
bool _esEventoStockCambio(Map<String, dynamic> evento) => evento['tipo_entidad'] == 'STOCK';

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

/// Resultados de búsqueda por nombre. Cualquier `STOCK_CAMBIO` invalida la
/// lista entera en vez de filtrar por producto — a diferencia de las
/// pantallas paramétricas (detalle, existencias de una ubicación), acá no
/// se sabe de antemano qué productos van a aparecer en el resultado, así
/// que no hay forma de filtrar sin sobre-invalidar igual.
final productoResultsProvider =
    FutureProvider.autoDispose<List<ProductoConStock>>((ref) {
      enableSilentRefresh(ref, interval: const Duration(seconds: 60));

      ref.listen(notificacionesWsProvider, (previous, next) {
        final evento = next.value;
        if (evento != null && _esEventoStockCambio(evento)) ref.invalidateSelf();
      });

      final q = ref.watch(stockSearchQueryProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(stockRepositoryProvider).buscarPorNombre(q);
    });

final ubicacionResultsProvider =
    FutureProvider.autoDispose<List<UbicacionStock>>((ref) {
      enableSilentRefresh(ref, interval: const Duration(seconds: 60));

      ref.listen(notificacionesWsProvider, (previous, next) {
        final evento = next.value;
        if (evento != null && _esEventoStockCambio(evento)) ref.invalidateSelf();
      });

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
      enableSilentRefresh(ref, interval: const Duration(seconds: 60));

      ref.listen(notificacionesWsProvider, (previous, next) {
        final evento = next.value;
        if (evento != null && _esEventoStockCambio(evento) && evento['id_ubicacion'] == idUbicacion) {
          ref.invalidateSelf();
        }
      });

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
      enableSilentRefresh(ref, interval: const Duration(seconds: 60));

      ref.listen(notificacionesWsProvider, (previous, next) {
        final evento = next.value;
        if (evento != null && _esEventoStockCambio(evento) && evento['id_producto'] == idProducto) {
          ref.invalidateSelf();
        }
      });

      return ref.watch(stockRepositoryProvider).detalleCompleto(idProducto);
    });

/// Ubicaciones dentro de una zona — paso "escanear zona" del buscador (ver
/// `ZonaUbicacionesScreen`). Catálogo completo (`UbicacionesApi.deZona`),
/// no la vista atada a stock.
final ubicacionesDeZonaProvider = FutureProvider.family
    .autoDispose<List<UbicacionSimple>, int>((ref, idZona) {
      enableSilentRefresh(ref);
      return ref.watch(ubicacionesApiProvider).deZona(idZona);
    });
