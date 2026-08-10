import '../../recepcion/data/ubicaciones_api.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/data/productos_api.dart';
import '../../stock/data/stock_repository.dart';
import '../../stock/domain/stock_models.dart' show ExistenciaStock, ProductoConStock, ProductoSimple;
import '../domain/traslado_models.dart';
import 'traslados_api.dart';

/// Repositorio de Traslados (incluye "Acomodos" — son el mismo módulo, ver
/// CONTEXTO_WHEREHOUSE.md: las alertas de reacomodo son existencias en
/// zonas RECEPCION/REACOMODO que se resuelven con el mismo `POST
/// /traslados/ejecutar` que un traslado manual). Reusa `UbicacionesApi` de
/// Recepción (cliente genérico de `/ubicaciones`), `StockRepository` de
/// Stock (búsqueda de producto + existencias) y `ProductosApi` de Stock
/// (resolver código de barras escaneado) en vez de duplicarlos.
class TrasladosRepository {
  TrasladosRepository(
    this._trasladosApi,
    this._ubicacionesApi,
    this._stockRepository,
    this._productosApi,
  );

  final TrasladosApi _trasladosApi;
  final UbicacionesApi _ubicacionesApi;
  final StockRepository _stockRepository;
  final ProductosApi _productosApi;

  Future<List<AlertaReacomodo>> alertasReacomodo({int? idAlmacen}) =>
      _trasladosApi.alertasReacomodo(idAlmacen: idAlmacen);

  Future<List<Traslado>> listarTraslados({
    String? q,
    String? estado,
    int? idAlmacen,
    int limit = 50,
  }) => _trasladosApi.listar(q: q, estado: estado, idAlmacen: idAlmacen, limit: limit);

  Future<TrasladoDetalle> obtenerDetalle(int idTraspaso) =>
      _trasladosApi.obtener(idTraspaso);

  /// `idAlmacen` se omite a propósito si no se conoce — el backend lo
  /// deriva solo de la primera existencia origen
  /// (`traslados_service.py::traslados_ejecutar`).
  Future<EjecutarTrasladoResultado> ejecutar({
    int? idAlmacen,
    String? observaciones,
    required int idExistenciaOrigen,
    required double cantidad,
    required int idUbicacionDestino,
  }) {
    return _trasladosApi.ejecutar(
      idAlmacen: idAlmacen,
      observaciones: observaciones,
      items: [
        EjecutarTrasladoItemIn(
          idExistenciaOrigen: idExistenciaOrigen,
          cantidad: cantidad,
          idUbicacionDestino: idUbicacionDestino,
        ),
      ],
    );
  }

  Future<List<UbicacionSimple>> buscarUbicacionesDestino({
    required int idAlmacen,
    String? q,
  }) => _ubicacionesApi.buscar(idAlmacen: idAlmacen, q: q);

  Future<List<ProductoConStock>> buscarProductos(String q) =>
      _stockRepository.buscarPorNombre(q);

  Future<List<ExistenciaStock>> existenciasDeProducto(int idProducto) =>
      _stockRepository.existenciasDeProducto(idProducto);

  Future<ProductoSimple> buscarProductoPorCodigoBarra(String codigoBarra) =>
      _productosApi.buscarPorCodigoBarra(codigoBarra);
}
