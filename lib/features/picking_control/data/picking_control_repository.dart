import '../domain/picking_control_models.dart';
import 'picking_control_api.dart';

/// Repositorio de Control de picking — passthrough fino sobre
/// [PickingControlApi], mismo patrón que `PickingRepository`: sin try/catch
/// ni cache local, los errores se propagan como `DioException` y se
/// capturan en la pantalla con `describeError`.
class PickingControlRepository {
  PickingControlRepository(this._api);

  final PickingControlApi _api;

  Future<List<SubpedidoControl>> subpedidos() => _api.subpedidos();

  Future<DetalleControl> detalle(int idPedidoSubpedido) => _api.detalle(idPedidoSubpedido);

  Future<IniciarControlResultado> iniciarControl(int idPedidoSubpedido) =>
      _api.iniciarControl(idPedidoSubpedido);

  Future<RevisarItemResultado> revisarItem({
    required int idPickingControl,
    required int idPickingControlItem,
    required double cantidadControlada,
    required String resultado,
    String? motivosRechazo,
    String? observacion,
  }) => _api.revisarItem(
    idPickingControl: idPickingControl,
    idPickingControlItem: idPickingControlItem,
    payload: RevisarItemIn(
      cantidadControlada: cantidadControlada,
      resultado: resultado,
      motivosRechazo: motivosRechazo,
      observacion: observacion,
    ),
  );

  Future<void> confirmarControl(int idPickingControl, {String? observacion}) =>
      _api.confirmarControl(idPickingControl, observacion: observacion);
}
