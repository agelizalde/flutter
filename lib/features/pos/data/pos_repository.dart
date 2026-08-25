import '../../pedidos/data/pedidos_repository.dart';
import '../../pedidos/domain/pedido_models.dart' show ClienteSimple, SucursalSimple;
import '../domain/pos_models.dart';
import 'pos_api.dart';

class PosRepository {
  PosRepository(this._posApi, this._pedidosRepository);

  final PosApi _posApi;
  final PedidosRepository _pedidosRepository;

  Future<PuntoVentaActual> miPuntoVenta() => _posApi.miPuntoVenta();

  Future<List<ProductoPosSimple>> buscarProductos({String? q}) =>
      _posApi.buscarProductos(q: q);

  Future<ProductoPosSimple> buscarPorCodigoBarra(String codigoBarra) =>
      _posApi.buscarPorCodigoBarra(codigoBarra);

  Future<VentaPosResultado> crearVenta({
    required int idCliente,
    int? idClienteSucursal,
    String? observacion,
    required List<PosCartItem> items,
  }) => _posApi.crearVenta(
    idCliente: idCliente,
    idClienteSucursal: idClienteSucursal,
    observacion: observacion,
    items: items,
  );

  Future<List<ClienteSimple>> clientesListar({String? q}) =>
      _pedidosRepository.clientesListar(q: q);

  Future<List<SucursalSimple>> sucursalesDeCliente(int idCliente) =>
      _pedidosRepository.sucursalesDeCliente(idCliente);
}
