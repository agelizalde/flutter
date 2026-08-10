import '../domain/pedido_models.dart';
import 'pedidos_api.dart';

class PedidosRepository {
  PedidosRepository(this._pedidosApi);

  final PedidosApi _pedidosApi;

  Future<PedidoDetalle> buscarPorCodigo(String codigo) => _pedidosApi.buscarPorCodigo(codigo);

  Future<PedidoDetalle> obtener(int idPedido) => _pedidosApi.obtener(idPedido);

  Future<List<SubpedidoResumen>> subpedidosDe(int idPedido) => _pedidosApi.subpedidosDe(idPedido);

  Future<List<SubpedidoSeguimiento>> seguimiento({String? q, String? estado}) =>
      _pedidosApi.seguimiento(q: q, estado: estado);

  Future<List<SubpedidoItemResumen>> itemsDe(int idPedidoSubpedido) =>
      _pedidosApi.itemsDe(idPedidoSubpedido);
}
