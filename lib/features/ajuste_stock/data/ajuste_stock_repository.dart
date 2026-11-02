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

  Future<List<AjusteStock>> listar({
    String? q,
    String? estado,
    int? idAlmacen,
    DateTime? fechaDesde,
    int limit = 50,
  }) =>
      _ajusteStockApi.listar(q: q, estado: estado, idAlmacen: idAlmacen, fechaDesde: fechaDesde, limit: limit);

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
    int? idUbicacion,
    required double cantidad,
    required String motivoCategoria,
    String? observaciones,
  }) {
    return _ajusteStockApi.mermaRapida(
      idProducto: idProducto,
      idUnidadMedida: idUnidadMedida,
      idAlmacen: idAlmacen,
      idUbicacion: idUbicacion,
      cantidad: cantidad,
      motivoCategoria: motivoCategoria,
      observaciones: observaciones,
    );
  }

  Future<void> confirmar(int idAjusteStock) => _ajusteStockApi.confirmar(idAjusteStock);

  Future<void> aplicar(int idAjusteStock) => _ajusteStockApi.aplicar(idAjusteStock);

  /// Confirma y aplica en seguida un ajuste recién creado (los controles ya
  /// no quedan en BORRADOR si el usuario tiene permiso para confirmar y
  /// aplicar — ver `puedeAplicarDirecto`).
  Future<void> confirmarYAplicar(int idAjusteStock) async {
    await _ajusteStockApi.confirmar(idAjusteStock);
    await _ajusteStockApi.aplicar(idAjusteStock);
  }

  Future<void> revertir({required int idAjusteStock, required int expectedVersion, String? motivo}) {
    return _ajusteStockApi.revertir(
      idAjusteStock: idAjusteStock,
      expectedVersion: expectedVersion,
      motivo: motivo,
    );
  }

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

  /// Stock del producto agrupado por ubicación dentro del almacén, con
  /// `idZona` siempre resuelto. `GET /stock/existencias` devuelve `id_zona`
  /// recién desde 2026-10-28; contra un servidor sin ese cambio la zona se
  /// completa buscando cada ubicación en `GET /ubicaciones` por su código.
  Future<List<StockEnUbicacion>> stockPorUbicacionDeProducto(int idProducto, {required int idAlmacen}) async {
    final existencias = await _stockRepository.existenciasDeProducto(idProducto, idAlmacen: idAlmacen);
    final grupos = agruparPorUbicacion(existencias);

    final resueltos = <StockEnUbicacion>[];
    for (final g in grupos) {
      if (g.idZona != null && g.idAlmacen != null) {
        resueltos.add(g);
        continue;
      }
      final candidatas = await _ubicacionesApi.buscar(idAlmacen: idAlmacen, q: g.ubicacionCodigo);
      final match = candidatas.where((u) => u.idUbicacion == g.idUbicacion).firstOrNull;
      resueltos.add(StockEnUbicacion(
        idUbicacion: g.idUbicacion,
        ubicacionNombre: g.ubicacionNombre,
        ubicacionCodigo: g.ubicacionCodigo,
        idZona: g.idZona ?? match?.idZona,
        idAlmacen: g.idAlmacen ?? match?.idAlmacen ?? idAlmacen,
        idUnidadMedida: g.idUnidadMedida,
        unidadSimbolo: g.unidadSimbolo,
        cantidad: g.cantidad,
      ));
    }
    return resueltos;
  }

  Future<ProductoSimple> buscarProductoPorCodigoBarra(String codigoBarra) =>
      _productosApi.buscarPorCodigoBarra(codigoBarra);

  Future<List<ProductoSimple>> buscarProductos(String q) =>
      _productosApi.buscar(q: q);

  Future<(ProductoDetalle, ProductoAlmacenaje)> detalleProducto(int idProducto) =>
      _productosApi.detalleConAlmacenaje(idProducto);
}
