import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../stock/application/stock_providers.dart' show proveedoresApiProvider;
import '../../stock/domain/stock_models.dart' show ProveedorSimple;
import '../data/oc_borrador_api.dart';
import '../domain/oc_borrador_models.dart';

final ocBorradorApiProvider = Provider<OcBorradorApi>((ref) {
  return OcBorradorApi(ref.watch(dioClientProvider).dio);
});

/// Búsqueda de proveedor en el paso 1 — mismo patrón que
/// `ocSimpleBusquedaProveedorProvider` (`oc_simple_providers.dart`).
final ocBorradorBusquedaProveedorProvider = StateProvider<String>((ref) => '');

final ocBorradorResultadosProveedorProvider =
    FutureProvider.autoDispose<List<ProveedorSimple>>((ref) {
  final q = ref.watch(ocBorradorBusquedaProveedorProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(proveedoresApiProvider).buscar(q: q);
});

/// Búsqueda de productos del paso 2. `idProveedor` != null = modo "Del
/// proveedor" (lista todos los suyos aunque `q` esté vacío); null = modo
/// "Todos" (catálogo completo, exige texto para no traer 600 filas).
typedef OcBorradorBusquedaProductos = ({String q, int? idProveedor});

final ocBorradorResultadosProductoProvider = FutureProvider.autoDispose
    .family<List<ProductoOcBorrador>, OcBorradorBusquedaProductos>((ref, busqueda) {
  final q = busqueda.q.trim();
  if (busqueda.idProveedor == null && q.isEmpty) return Future.value(const []);
  return ref.watch(ocBorradorApiProvider).buscarProductos(
        q: q,
        idProveedor: busqueda.idProveedor,
        limit: busqueda.idProveedor != null ? 100 : 30,
      );
});
