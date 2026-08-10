import '../../stock/data/proveedores_api.dart';
import '../../stock/domain/stock_models.dart' show ProveedorSimple;
import '../domain/oc_simple_models.dart';
import 'oc_simple_api.dart';

/// Orquesta `OcSimpleApi` (propia) + `ProveedoresApi` (de Stock, reusada) —
/// mismo rol que `TrasladosRepository`/`RecepcionRepository` para sus
/// features.
class OcSimpleRepository {
  OcSimpleRepository(this._ocSimpleApi, this._proveedoresApi);

  final OcSimpleApi _ocSimpleApi;
  final ProveedoresApi _proveedoresApi;

  Future<List<ProveedorSimple>> buscarProveedores(String q) =>
      _proveedoresApi.buscar(q: q);

  Future<List<ProductoCompraSimple>> buscarProductos(String q) =>
      _ocSimpleApi.buscarProductos(q: q);

  Future<OcSimpleResultado> crear({
    required int idProveedor,
    required List<OcSimpleCartItem> items,
  }) => _ocSimpleApi.crear(idProveedor: idProveedor, items: items);
}
