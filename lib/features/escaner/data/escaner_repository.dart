import 'package:dio/dio.dart';

import '../../pedidos/data/pedidos_repository.dart';
import '../../picking_operario/data/picking_repository.dart';
import '../../produccion/data/produccion_repository.dart';
import '../../recepcion/data/recepcion_repository.dart';
import '../../stock/data/productos_api.dart';
import '../../stock/data/stock_repository.dart';
import '../domain/escaneo_resultado.dart';

/// Resuelve un código escaneado desde el botón de escaneo genérico (Home /
/// bottom nav): puede ser el código de barra de un producto, el código de
/// una ubicación, el código de una OC, de un pedido, de una orden de
/// producción, o el identificador/código de barras de un contenedor.
/// Dispara las 6 búsquedas en paralelo (cada una ya sabe distinguir "no
/// encontrado" de un error real) y prioriza en ese orden si por algún motivo
/// matchea más de una — no debería pasar, son espacios de código separados.
class EscanerRepository {
  EscanerRepository(
    this._productosApi,
    this._stockRepository,
    this._recepcionRepository,
    this._pedidosRepository,
    this._produccionRepository,
    this._pickingRepository,
  );

  final ProductosApi _productosApi;
  final StockRepository _stockRepository;
  final RecepcionRepository _recepcionRepository;
  final PedidosRepository _pedidosRepository;
  final ProduccionRepository _produccionRepository;
  final PickingRepository _pickingRepository;

  Future<EscaneoResultado> resolver(String codigoCrudo) async {
    final codigo = codigoCrudo.trim();

    final resultados = await Future.wait([
      _buscarProducto(codigo),
      _buscarUbicacion(codigo),
      _buscarOc(codigo),
      _buscarPedido(codigo),
      _buscarOrdenProduccion(codigo),
      _buscarContenedor(codigo),
    ]);

    for (final r in resultados) {
      if (r != null) return r;
    }
    return const EscaneoNoEncontrado();
  }

  Future<EscaneoResultado?> _buscarProducto(String codigo) async {
    try {
      final producto = await _productosApi.buscarPorCodigoBarra(codigo);
      return EscaneoProducto(idProducto: producto.idProducto);
    } catch (e) {
      if (_esNoEncontrado(e)) return null;
      rethrow;
    }
  }

  /// Las ubicaciones no tienen un endpoint de búsqueda exacta por código
  /// (a diferencia de producto y OC) — se usa la búsqueda genérica
  /// `/stock/por-ubicacion?q=` y se filtra el match exacto, mismo patrón
  /// que `_escanearUbicacion` en `nuevo_ajuste_screen.dart`.
  Future<EscaneoResultado?> _buscarUbicacion(String codigo) async {
    final resultados = await _stockRepository.buscarUbicaciones(codigo);
    final exactas = resultados.where(
      (u) => u.ubicacionCodigo.trim().toLowerCase() == codigo.toLowerCase(),
    );
    if (exactas.isEmpty) return null;
    final u = exactas.first;
    return EscaneoUbicacion(idUbicacion: u.idUbicacion, nombre: u.ubicacionNombre);
  }

  Future<EscaneoResultado?> _buscarOc(String codigo) async {
    try {
      final detalle = await _recepcionRepository.obtenerOcInfoPorCodigo(codigo);
      return EscaneoOc(idOc: detalle.header.idOc);
    } catch (e) {
      if (_esNoEncontrado(e)) return null;
      rethrow;
    }
  }

  Future<EscaneoResultado?> _buscarPedido(String codigo) async {
    try {
      final detalle = await _pedidosRepository.buscarPorCodigo(codigo);
      return EscaneoPedido(idPedido: detalle.idPedido);
    } catch (e) {
      if (_esNoEncontrado(e)) return null;
      rethrow;
    }
  }

  Future<EscaneoResultado?> _buscarOrdenProduccion(String codigo) async {
    try {
      final orden = await _produccionRepository.buscarOrdenPorCodigo(codigo);
      return EscaneoOrdenProduccion(idOrden: orden.idOrden);
    } catch (e) {
      if (_esNoEncontrado(e)) return null;
      rethrow;
    }
  }

  Future<EscaneoResultado?> _buscarContenedor(String codigo) async {
    try {
      final detalle = await _pickingRepository.buscarContenedorDetalle(codigo);
      return EscaneoContenedor(detalle: detalle);
    } catch (e) {
      if (_esNoEncontrado(e)) return null;
      rethrow;
    }
  }

  /// Los 404 llegan como `DioException` con el `AppException` mapeado
  /// adentro (ver `DioClient._mapError`) — pero 404 no tiene un
  /// `AppException` propio, cae en el mismo `BusinessException` genérico
  /// que otros 4xx, así que hay que mirar el status code crudo del
  /// `DioException`, no el tipo del error mapeado.
  bool _esNoEncontrado(Object e) => e is DioException && e.response?.statusCode == 404;
}
