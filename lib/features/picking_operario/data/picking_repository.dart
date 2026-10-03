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

  Future<PickingConfig> config({required int idPedidoSubpedido}) =>
      _api.config(idPedidoSubpedido: idPedidoSubpedido);

  Future<bool> appHabilitado() => _api.appHabilitado();

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
    String? codigoBarra,
  }) => _api.completarTarea(
    idStockReservaDetalle: idStockReservaDetalle,
    payload: CompletarTareaIn(idSesion: idSesion, cantidadPickeada: cantidadPickeada, codigoBarra: codigoBarra),
  );

  Future<CancelarTareaResultado> cancelarTarea({
    required int idStockReservaDetalle,
    String? supervisorEmail,
    String? supervisorPassword,
    String? motivo,
  }) => _api.cancelarTarea(
    idStockReservaDetalle: idStockReservaDetalle,
    supervisorEmail: supervisorEmail,
    supervisorPassword: supervisorPassword,
    motivo: motivo,
  );

  Future<ModificarCantidadResultado> modificarCantidad({
    required int idStockReservaDetalle,
    required double nuevaCantidad,
    String? supervisorEmail,
    String? supervisorPassword,
  }) => _api.modificarCantidad(
    idStockReservaDetalle: idStockReservaDetalle,
    nuevaCantidad: nuevaCantidad,
    supervisorEmail: supervisorEmail,
    supervisorPassword: supervisorPassword,
  );

  Future<CajonItemsResponse> cajonItems(int idContenedor) => _api.cajonItems(idContenedor);

  Future<DevolverItemResultado> devolverItem({
    required int idPickingItem,
    required double cantidadDevolver,
    String? motivo,
  }) => _api.devolverItem(idPickingItem: idPickingItem, cantidadDevolver: cantidadDevolver, motivo: motivo);

  Future<List<TareaDespickeo>> misTareasDespickeo() => _api.misTareasDespickeo();

  Future<ConfirmarDespickeoResultado> confirmarDespickeo({
    required int idDespickeoTarea,
    String? observacion,
  }) => _api.confirmarDespickeo(idDespickeoTarea: idDespickeoTarea, observacion: observacion);
}
