import '../domain/firma_solicitud.dart';
import 'firmas_api.dart';

class FirmasRepository {
  FirmasRepository(this._api);

  final FirmasApi _api;

  Future<List<FirmaSolicitud>> listarSolicitudes({String? estado, bool soloParaMi = false}) =>
      _api.listarSolicitudes(estado: estado, soloParaMi: soloParaMi);

  Future<FirmaSolicitud> getSolicitud(int idFirmaSolicitud) => _api.getSolicitud(idFirmaSolicitud);

  Future<FirmaSolicitud> aprobar({required int idFirmaSolicitud, required int expectedVersion, String? motivo}) =>
      _api.aprobar(idFirmaSolicitud: idFirmaSolicitud, expectedVersion: expectedVersion, motivo: motivo);

  Future<FirmaSolicitud> rechazar({
    required int idFirmaSolicitud,
    required int expectedVersion,
    required String motivo,
  }) => _api.rechazar(idFirmaSolicitud: idFirmaSolicitud, expectedVersion: expectedVersion, motivo: motivo);
}
