import '../domain/op_detalle.dart';
import 'op_detalle_api.dart';

class OpDetalleRepository {
  OpDetalleRepository(this._api);

  final OpDetalleApi _api;

  Future<OpDetalle> getOp(int idOrdenPago) => _api.getOp(idOrdenPago);
}
