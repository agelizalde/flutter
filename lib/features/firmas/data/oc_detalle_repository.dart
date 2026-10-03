import '../domain/oc_detalle.dart';
import 'oc_detalle_api.dart';

class OcDetalleRepository {
  OcDetalleRepository(this._api);

  final OcDetalleApi _api;

  Future<OcDetalle> getOc(int idOc) => _api.getOc(idOc);

  Future<List<OcUltimaCompra>> ultimasCompras(int idProducto, {int limit = 4}) =>
      _api.ultimasCompras(idProducto, limit: limit);
}
