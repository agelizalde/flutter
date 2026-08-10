import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../stock/application/stock_providers.dart' show proveedoresApiProvider;
import '../../stock/domain/stock_models.dart' show ProveedorSimple;
import '../data/oc_simple_api.dart';
import '../data/oc_simple_repository.dart';
import '../domain/oc_simple_models.dart';

final ocSimpleApiProvider = Provider<OcSimpleApi>((ref) {
  return OcSimpleApi(ref.watch(dioClientProvider).dio);
});

final ocSimpleRepositoryProvider = Provider<OcSimpleRepository>((ref) {
  return OcSimpleRepository(
    ref.watch(ocSimpleApiProvider),
    ref.watch(proveedoresApiProvider),
  );
});

/// Búsqueda de proveedor/producto en `OcSimpleScreen` — mismo patrón que
/// `recepcionBusquedaProveedorProvider`/`recepcionResultadosProveedorProvider`
/// en `recepcion_providers.dart`.
final ocSimpleBusquedaProveedorProvider = StateProvider<String>((ref) => '');
final ocSimpleBusquedaProductoProvider = StateProvider<String>((ref) => '');

final ocSimpleResultadosProveedorProvider =
    FutureProvider.autoDispose<List<ProveedorSimple>>((ref) {
  final q = ref.watch(ocSimpleBusquedaProveedorProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(ocSimpleRepositoryProvider).buscarProveedores(q);
});

final ocSimpleResultadosProductoProvider =
    FutureProvider.autoDispose<List<ProductoCompraSimple>>((ref) {
  final q = ref.watch(ocSimpleBusquedaProductoProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(ocSimpleRepositoryProvider).buscarProductos(q);
});
