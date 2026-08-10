import '../../recepcion/data/ubicaciones_api.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/data/productos_api.dart';
import '../../stock/data/stock_repository.dart';
import '../../stock/domain/stock_models.dart'
    show ExistenciaStock, ProductoAlmacenaje, ProductoDetalle, ProductoSimple;
import '../domain/ajuste_stock_models.dart';
import 'ajuste_stock_api.dart';

/// Repositorio de Ajuste de Stock. Reusa `UbicacionesApi` de Recepción
/// (búsqueda genérica de ubicaciones), `StockRepository` de Stock
/// (existencias por ubicación, para armar el conteo) y `ProductosApi` de
/// Stock (resolver código de barras escaneado) en vez de duplicarlos.
class AjusteStockRepository {
  AjusteStockRepository(
    this._ajusteStockApi,
    this._ubicacionesApi,
    this._stockRepository,
    this._productosApi,
  );

  final AjusteStockApi _ajusteStockApi;
  final UbicacionesApi _ubicacionesApi;
  final StockRepository _stockRepository;
  final ProductosApi _productosApi;

  Future<List<AjusteStock>> listar({String? q, String? estado, int? idAlmacen, int limit = 50}) =>
      _ajusteStockApi.listar(q: q, estado: estado, idAlmacen: idAlmacen, limit: limit);

  Future<AjusteStockDetalle> obtenerDetalle(int idAjusteStock) =>
      _ajusteStockApi.obtener(idAjusteStock);

  Future<int> crear({
    required String modoAjuste,
    required String motivoCategoria,
    required int idAlmacen,
    required int idZona,
    required int idUbicacion,
    String? observaciones,
    required List<AjusteStockItemCreateIn> items,
  }) {
    return _ajusteStockApi.crear(
      modoAjuste: modoAjuste,
      motivoCategoria: motivoCategoria,
      idAlmacen: idAlmacen,
      idZona: idZona,
      idUbicacion: idUbicacion,
      observaciones: observaciones,
      items: items,
    );
  }

  Future<void> mermaRapida({
    required int idProducto,
    required int idUnidadMedida,
    required int idAlmacen,
    required double cantidad,
    required String motivoCategoria,
    String? observaciones,
  }) {
    return _ajusteStockApi.mermaRapida(
      idProducto: idProducto,
      idUnidadMedida: idUnidadMedida,
      idAlmacen: idAlmacen,
      cantidad: cantidad,
      motivoCategoria: motivoCategoria,
      observaciones: observaciones,
    );
  }

  Future<void> confirmar(int idAjusteStock) => _ajusteStockApi.confirmar(idAjusteStock);

  Future<void> aplicar(int idAjusteStock) => _ajusteStockApi.aplicar(idAjusteStock);

  Future<void> anular({required int idAjusteStock, required int expectedVersion, String? motivo}) {
    return _ajusteStockApi.anular(
      idAjusteStock: idAjusteStock,
      expectedVersion: expectedVersion,
      motivo: motivo,
    );
  }

  Future<List<UbicacionSimple>> buscarUbicaciones({required int idAlmacen, String? q}) =>
      _ubicacionesApi.buscar(idAlmacen: idAlmacen, q: q);

  Future<List<ExistenciaStock>> existenciasDeUbicacion(int idUbicacion) =>
      _stockRepository.existenciasDeUbicacion(idUbicacion);

  Future<ProductoSimple> buscarProductoPorCodigoBarra(String codigoBarra) =>
      _productosApi.buscarPorCodigoBarra(codigoBarra);

  Future<List<ProductoSimple>> buscarProductos(String q) =>
      _productosApi.buscar(q: q);

  Future<(ProductoDetalle, ProductoAlmacenaje)> detalleProducto(int idProducto) =>
      _productosApi.detalleConAlmacenaje(idProducto);
}
