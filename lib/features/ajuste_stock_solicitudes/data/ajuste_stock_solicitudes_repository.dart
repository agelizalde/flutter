import '../../recepcion/data/ubicaciones_api.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../domain/solicitud_models.dart';
import 'ajuste_stock_solicitudes_api.dart';

/// Repositorio de solicitudes de control de stock. Reusa `UbicacionesApi` de
/// Recepción para el mismo picker de ubicación que usa `ajuste_stock`, en
/// vez de duplicarlo.
class AjusteStockSolicitudesRepository {
  AjusteStockSolicitudesRepository(this._api, this._ubicacionesApi);

  final AjusteStockSolicitudesApi _api;
  final UbicacionesApi _ubicacionesApi;

  Future<SolicitudAjusteStock> crear({
    required int idAlmacen,
    required int idZona,
    required int idUbicacion,
    required int idUsuarioAsignado,
    required String motivoCategoria,
    String? observaciones,
  }) {
    return _api.crear(
      idAlmacen: idAlmacen,
      idZona: idZona,
      idUbicacion: idUbicacion,
      idUsuarioAsignado: idUsuarioAsignado,
      motivoCategoria: motivoCategoria,
      observaciones: observaciones,
    );
  }

  Future<List<SolicitudAjusteStock>> misTareas() => _api.misTareas();

  Future<void> cancelar({required int idSolicitud, required int expectedVersion, String? motivo}) =>
      _api.cancelar(idSolicitud: idSolicitud, expectedVersion: expectedVersion, motivo: motivo);

  Future<void> completar({required int idSolicitud, required int idAjusteStock}) =>
      _api.completar(idSolicitud: idSolicitud, idAjusteStock: idAjusteStock);

  Future<List<UsuarioAsignable>> usuariosAsignables({required int idAlmacen, String? q}) =>
      _api.usuariosAsignables(idAlmacen: idAlmacen, q: q);

  Future<List<UbicacionSimple>> buscarUbicaciones({required int idAlmacen, String? q}) =>
      _ubicacionesApi.buscar(idAlmacen: idAlmacen, q: q);
}
