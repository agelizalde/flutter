import '../domain/oc_exceso_cantidad_detalle.dart';
import 'oc_exceso_cantidad_api.dart';

class OcExcesoCantidadRepository {
  OcExcesoCantidadRepository(this._api);

  final OcExcesoCantidadApi _api;

  Future<OcExcesoCantidadDetalle> getExcesoCantidad(int idExceso) => _api.getExcesoCantidad(idExceso);
}
