import '../domain/oc_diferencia_peso_detalle.dart';
import 'oc_diferencia_peso_api.dart';

class OcDiferenciaPesoRepository {
  OcDiferenciaPesoRepository(this._api);

  final OcDiferenciaPesoApi _api;

  Future<OcDiferenciaPesoDetalle> getDiferenciaPeso(int idDiferencia) => _api.getDiferenciaPeso(idDiferencia);
}
