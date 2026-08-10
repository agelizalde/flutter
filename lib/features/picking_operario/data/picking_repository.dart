import '../domain/picking_models.dart';
import 'picking_api.dart';

/// Repositorio de Picking (operario) — passthrough fino sobre [PickingApi],
/// mismo patrón que `TrasladosRepository`: sin try/catch ni cache local, los
/// errores se dejan propagar como `DioException` (`.error` trae el
/// `AppException` mapeado, ver `core/errors/app_exception.dart`) y se
/// capturan recién en la pantalla con `describeError`.
class PickingRepository {
  PickingRepository(this._api);

  final PickingApi _api;

  Future<MisTareasResponse> misTareas() => _api.misTareas();

  Future<int> iniciarZona({required int idPedidoSubpedido, required int idZona}) =>
      _api.iniciarZona(idPedidoSubpedido: idPedidoSubpedido, idZona: idZona);

  Future<SesionZona?> sesionActiva() => _api.sesionActiva();

  Future<SeleccionarCajonResultado> seleccionarCajon({
    required int idSesion,
    required int? idContenedor,
  }) => _api.seleccionarCajon(idSesion: idSesion, idContenedor: idContenedor);

  Future<void> terminarSesion(int idSesion) => _api.terminarSesion(idSesion);

  Future<ContenedorPicking> buscarContenedor(String codigo, {int? idPedidoSubpedido}) =>
      _api.buscarContenedor(codigo, idPedidoSubpedido: idPedidoSubpedido);

  Future<ContenedorDetalle> buscarContenedorDetalle(String codigo) => _api.buscarContenedorDetalle(codigo);

  Future<CompletarTareaResultado> completarTarea({
    required int idStockReservaDetalle,
    required int idSesion,
    required double cantidadPickeada,
  }) => _api.completarTarea(
    idStockReservaDetalle: idStockReservaDetalle,
    payload: CompletarTareaIn(idSesion: idSesion, cantidadPickeada: cantidadPickeada),
  );

  Future<List<TareaDespickeo>> misTareasDespickeo() => _api.misTareasDespickeo();

  Future<ConfirmarDespickeoResultado> confirmarDespickeo({
    required int idDespickeoTarea,
    String? observacion,
  }) => _api.confirmarDespickeo(idDespickeoTarea: idDespickeoTarea, observacion: observacion);
}
