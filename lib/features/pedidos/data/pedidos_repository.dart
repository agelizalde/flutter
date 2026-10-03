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
    bool requierePgn = false,
    bool requiereAduana = false,
  }) => _pedidosApi.crear(
    codigoPedido: codigoPedido,
    idCliente: idCliente,
    idClienteSucursal: idClienteSucursal,
    observaciones: observaciones,
    idLugarEntrega: idLugarEntrega,
    eta: eta,
    idVehiculoEntrega: idVehiculoEntrega,
    requierePgn: requierePgn,
    requiereAduana: requiereAduana,
  );

  Future<PedidosConfigCreacion> configCreacion() =>
      _pedidosApi.configCreacion();

  Future<List<ClienteSimple>> clientesListar({
    String? q,
    bool excluirOcasionales = false,
  }) => _pedidosApi.clientesListar(q: q, excluirOcasionales: excluirOcasionales);

  Future<List<SucursalSimple>> sucursalesDeCliente(int idCliente) =>
      _pedidosApi.sucursalesDeCliente(idCliente);

  Future<List<LugarEntregaSimple>> lugaresEntregaListar({String? q}) =>
      _pedidosApi.lugaresEntregaListar(q: q);

  Future<List<VehiculoEntregaSimple>> vehiculosListar({String? q}) =>
      _pedidosApi.vehiculosListar(q: q);

  Future<List<PedidoEstandarResumen>> estandaresDeCliente(
    int idCliente, {
    String? q,
  }) => _pedidosApi.estandaresDeCliente(idCliente, q: q);

  Future<EstandarAplicarResultado> aplicarEstandar({
    required int idPedidoEstandar,
    required int idPedido,
  }) => _pedidosApi.aplicarEstandar(
    idPedidoEstandar: idPedidoEstandar,
    idPedido: idPedido,
  );

  Future<PedidoDetalle> patch({
    required int idPedido,
    required int expectedVersion,
    required Map<String, dynamic> patch,
  }) => _pedidosApi.patch(
    idPedido: idPedido,
    expectedVersion: expectedVersion,
    patch: patch,
  );

  Future<PedidoAnularResultado> anular({
    required int idPedido,
    required int expectedVersion,
    String? observacion,
  }) => _pedidosApi.anular(
    idPedido: idPedido,
    expectedVersion: expectedVersion,
    observacion: observacion,
  );

  Future<SubpedidoConfirmarResultado> confirmarSubpedido({
    required int idPedidoSubpedido,
    required int expectedVersion,
  }) => _pedidosApi.confirmarSubpedido(
    idPedidoSubpedido: idPedidoSubpedido,
    expectedVersion: expectedVersion,
  );

  Future<void> aplicarDecisionEsperar({
    required int idPedidoSubpedido,
    required List<int> idsItems,
  }) => _pedidosApi.aplicarDecisionEsperar(
    idPedidoSubpedido: idPedidoSubpedido,
    idsItems: idsItems,
  );
}
