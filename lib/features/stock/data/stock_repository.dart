import '../domain/stock_models.dart';
import 'productos_api.dart';
import 'proveedores_api.dart';
import 'stock_api.dart';

/// Combina los 3 datasources del feature en las operaciones que necesita
/// la UI. La pantalla nunca llama a `StockApi`/`ProductosApi`/`ProveedoresApi`
/// directamente (CONTEXTO_WHEREHOUSE.md §3 — patrón repositorio).
class StockRepository {
  StockRepository(this._stockApi, this._productosApi, this._proveedoresApi);

  final StockApi _stockApi;
  final ProductosApi _productosApi;
  final ProveedoresApi _proveedoresApi;

  Future<List<ProductoConStock>> buscarPorNombre(String q) =>
      _stockApi.porProducto(q: q);

  Future<List<UbicacionStock>> buscarUbicaciones(String q) =>
      _stockApi.porUbicacion(q: q);

  Future<List<ProveedorSimple>> buscarProveedores(String q) =>
      _proveedoresApi.buscar(q: q);

  Future<List<ExistenciaStock>> existenciasDeUbicacion(int idUbicacion) =>
      _stockApi.existencias(idUbicacion: idUbicacion, limit: 200);

  Future<List<ExistenciaStock>> existenciasDeProducto(int idProducto) =>
      _stockApi.existencias(idProducto: idProducto, limit: 200);

  Future<List<ProductoSimple>> productosDeProveedor(int idProveedor) =>
      _productosApi.buscar(idProveedorCabecera: idProveedor, limit: 200);

  Future<ProductoStockDetalle> detalleCompleto(int idProducto) async {
    final resultados = await Future.wait([
      _productosApi.detalle(idProducto),
      _stockApi.resumenProducto(idProducto),
      _stockApi.existencias(idProducto: idProducto, limit: 200),
    ]);
    return ProductoStockDetalle(
      producto: resultados[0] as ProductoDetalle,
      resumen: resultados[1] as StockResumen,
      existencias: resultados[2] as List<ExistenciaStock>,
    );
  }
}
