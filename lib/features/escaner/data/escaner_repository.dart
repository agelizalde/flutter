import 'package:dio/dio.dart';

import '../../pedidos/data/pedidos_repository.dart';
import '../../picking_operario/data/picking_repository.dart';
import '../../produccion/data/produccion_repository.dart';
import '../../recepcion/data/recepcion_repository.dart';
import '../../recepcion/data/ubicaciones_api.dart';
import '../../stock/data/productos_api.dart';
import '../domain/escaneo_resultado.dart';

/// Resuelve un código escaneado desde el botón de escaneo genérico (Home /
/// bottom nav): puede ser el código de barra de un producto, el código de
/// una ubicación, el código de una OC, de un pedido, de una orden de
/// producción, o el identificador/código de barras de un contenedor.
/// Dispara las 6 búsquedas en paralelo (cada una ya sabe distinguir "no
/// encontrado" de un error real) y prioriza en ese orden si por algún motivo
/// matchea más de una — no debería pasar, son espacios de código separados.
///
/// Cada búsqueda puede vivir detrás de un permiso de módulo distinto
/// (`recepciones.ver`, `picking_operario.ver`, etc.) que no tiene nada que
/// ver con lo que el usuario está buscando en realidad — un operario sin
/// `picking_operario.ver` tiene que poder seguir escaneando una ubicación o
/// un producto sin que la rama de "cajón" le tape el resultado con un 403.
/// Por eso `_esResultadoVacio` trata el 403 igual que el 404: "esta rama no
/// encontró nada", no un error real.
class EscanerRepository {
  EscanerRepository(
    this._productosApi,
    this._ubicacionesApi,
    this._recepcionRepository,
    this._pedidosRepository,
    this._produccionRepository,
    this._pickingRepository,
  );

  final ProductosApi _productosApi;
  final UbicacionesApi _ubicacionesApi;
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
      if (_esResultadoVacio(e)) return null;
      rethrow;
    }
  }

  /// Usa el catálogo de ubicaciones (`GET /ubicaciones`, permiso
  /// `ubicacion.ver`) en vez de `/stock/por-ubicacion` — ese último solo
  /// devuelve ubicaciones con `stock_existencias.cantidad > 0` (es un
  /// reporte de stock, no un catálogo), así que una ubicación vacía nunca
  /// matcheaba y el escaneo terminaba en "Código no reconocido" aunque el
  /// código fuera válido. El catálogo no filtra por stock y ya lo usan
  /// Traslados/Ajuste de stock (`UbicacionesApi.buscar`).
  Future<EscaneoResultado?> _buscarUbicacion(String codigo) async {
    final resultados = await _ubicacionesApi.buscar(q: codigo);
    final exactas = resultados.where(
      (u) => u.codigo.trim().toLowerCase() == codigo.toLowerCase(),
    );
    if (exactas.isEmpty) return null;
    final u = exactas.first;
    return EscaneoUbicacion(idUbicacion: u.idUbicacion, nombre: u.nombre);
  }

  Future<EscaneoResultado?> _buscarOc(String codigo) async {
    try {
      final detalle = await _recepcionRepository.obtenerOcInfoPorCodigo(codigo);
      return EscaneoOc(idOc: detalle.header.idOc);
    } catch (e) {
      if (_esResultadoVacio(e)) return null;
      rethrow;
    }
  }

  Future<EscaneoResultado?> _buscarPedido(String codigo) async {
    try {
      final detalle = await _pedidosRepository.buscarPorCodigo(codigo);
      return EscaneoPedido(idPedido: detalle.idPedido);
    } catch (e) {
      if (_esResultadoVacio(e)) return null;
      rethrow;
    }
  }

  Future<EscaneoResultado?> _buscarOrdenProduccion(String codigo) async {
    try {
      final orden = await _produccionRepository.buscarOrdenPorCodigo(codigo);
      return EscaneoOrdenProduccion(idOrden: orden.idOrden);
    } catch (e) {
      if (_esResultadoVacio(e)) return null;
      rethrow;
    }
  }

  Future<EscaneoResultado?> _buscarContenedor(String codigo) async {
    try {
      final detalle = await _pickingRepository.buscarContenedorDetalle(codigo);
      return EscaneoContenedor(detalle: detalle);
    } catch (e) {
      if (_esResultadoVacio(e)) return null;
      rethrow;
    }
  }

  /// Los 404 llegan como `DioException` con el `AppException` mapeado
  /// adentro (ver `DioClient._mapError`) — pero 404 no tiene un
  /// `AppException` propio, cae en el mismo `BusinessException` genérico
  /// que otros 4xx, así que hay que mirar el status code crudo del
  /// `DioException`, no el tipo del error mapeado.
  ///
  /// El 403 se trata igual que el 404: cada rama de búsqueda vive detrás de
  /// un permiso de módulo distinto (`recepciones.ver`, `picking_operario.ver`,
  /// etc.) que es independiente del código que el usuario está escaneando —
  /// no tener acceso a OCs no debería impedir encontrar una ubicación. Si
  /// ninguna rama matchea (por no encontrado o por falta de permiso), el
  /// resultado final es igual: "Código no reconocido".
  bool _esResultadoVacio(Object e) =>
      e is DioException && (e.response?.statusCode == 404 || e.response?.statusCode == 403);
}
