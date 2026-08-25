import '../domain/pedido_models.dart';
import 'pedidos_api.dart';

class PedidosRepository {
  PedidosRepository(this._pedidosApi);

  final PedidosApi _pedidosApi;

  Future<PedidoDetalle> buscarPorCodigo(String codigo) =>
      _pedidosApi.buscarPorCodigo(codigo);

  Future<PedidoDetalle> obtener(int idPedido) => _pedidosApi.obtener(idPedido);

  Future<List<SubpedidoResumen>> subpedidosDe(int idPedido) =>
      _pedidosApi.subpedidosDe(idPedido);

  Future<List<SubpedidoSeguimiento>> seguimiento({String? q, String? estado}) =>
      _pedidosApi.seguimiento(q: q, estado: estado);

  Future<List<PedidoSinSubpedidos>> sinSubpedidos({String? q}) =>
      _pedidosApi.sinSubpedidos(q: q);

  Future<List<SubpedidoItemResumen>> itemsDe(int idPedidoSubpedido) =>
      _pedidosApi.itemsDe(idPedidoSubpedido);

  Future<PedidoDetalle> crear({
    required String codigoPedido,
    required int idCliente,
    int? idClienteSucursal,
    String? observaciones,
    int? idLugarEntrega,
    DateTime? eta,
    int? idVehiculoEntrega,
  }) => _pedidosApi.crear(
    codigoPedido: codigoPedido,
    idCliente: idCliente,
    idClienteSucursal: idClienteSucursal,
    observaciones: observaciones,
    idLugarEntrega: idLugarEntrega,
    eta: eta,
    idVehiculoEntrega: idVehiculoEntrega,
  );

  Future<List<ClienteSimple>> clientesListar({String? q}) =>
      _pedidosApi.clientesListar(q: q);

  Future<List<SucursalSimple>> sucursalesDeCliente(int idCliente) =>
      _pedidosApi.sucursalesDeCliente(idCliente);

  Future<List<LugarEntregaSimple>> lugaresEntregaListar({String? q}) =>
      _pedidosApi.lugaresEntregaListar(q: q);

  Future<List<VehiculoEntregaSimple>> vehiculosListar({String? q}) =>
      _pedidosApi.vehiculosListar(q: q);
}
