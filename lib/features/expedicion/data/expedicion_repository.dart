import '../domain/expedicion_models.dart';
import 'expedicion_api.dart';

/// Repositorio de Expedición/Carga — passthrough fino sobre [ExpedicionApi],
/// mismo patrón que `PickingControlRepository`: sin try/catch ni cache
/// local, los errores se propagan como `DioException` y se capturan en la
/// pantalla con `describeError`.
class ExpedicionRepository {
  ExpedicionRepository(this._api);

  final ExpedicionApi _api;

  Future<List<SubpedidoEnCarga>> subpedidosEnCarga() => _api.subpedidosEnCarga();

  Future<DetalleCarga> detalle(int idPedidoSubpedido) => _api.detalle(idPedidoSubpedido);

  Future<DetalleCarga> escanearLinea(int idPedidoSubpedido, int idLinea) =>
      _api.escanearLinea(idPedidoSubpedido, idLinea);

  Future<DetalleCarga> contarLinea(int idPedidoSubpedido, int idLinea, int delta) =>
      _api.contarLinea(idPedidoSubpedido, idLinea, delta);

  Future<void> completarCarga(int idPedidoSubpedido) => _api.completarCarga(idPedidoSubpedido);

  Future<List<DevolucionCarga>> devoluciones(int idPedidoSubpedido) => _api.devoluciones(idPedidoSubpedido);

  Future<void> confirmarDevolucion(int idPedidoSubpedido, int idDevolucion) =>
      _api.confirmarDevolucion(idPedidoSubpedido, idDevolucion);
}
