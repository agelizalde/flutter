import '../domain/produccion_models.dart';
import 'produccion_api.dart';

/// Repositorio de Producción — por ahora es una fachada delgada sobre
/// [ProduccionApi] (no necesita combinar con otras features, a diferencia
/// de Traslados/Recepción que reusan Stock/Ubicaciones).
class ProduccionRepository {
  ProduccionRepository(this._api);

  final ProduccionApi _api;

  Future<List<RecetaResumen>> listarRecetas({String? q}) => _api.listarRecetas(q: q);

  Future<RecetaDetalle> obtenerReceta(int idReceta) => _api.obtenerReceta(idReceta);

  Future<EtiquetaTemplate> obtenerEtiqueta(int idEtiqueta) => _api.obtenerEtiqueta(idEtiqueta);

  Future<OrdenPreview> preview({required int idReceta, required double cantidadReferenciaReal}) =>
      _api.preview(idReceta: idReceta, cantidadReferenciaReal: cantidadReferenciaReal);

  /// Crea la orden e inicia el cronómetro en un solo paso (mismo patrón que
  /// `TallerInicioPage.jsx::empezarAProducir` en la web) — el operario no
  /// necesita ver el estado intermedio BORRADOR.
  Future<int> empezarAProducir({
    required int idReceta,
    required double cantidadReferenciaReal,
    required int idAlmacen,
  }) async {
    final creada = await _api.crear(
      idReceta: idReceta,
      cantidadReferenciaReal: cantidadReferenciaReal,
      idAlmacen: idAlmacen,
    );
    await _api.iniciar(creada.idOrden);
    return creada.idOrden;
  }

  Future<OrdenProduccion> obtenerOrden(int idOrden) => _api.obtenerOrden(idOrden);

  Future<OrdenProduccion> buscarOrdenPorCodigo(String codigo) => _api.buscarPorCodigo(codigo);

  Future<List<EtiquetaProduccion>> etiquetas(int idOrden) => _api.etiquetas(idOrden);

  /// Solo las órdenes donde el usuario es creador u operario (ver
  /// `orden_service.py::ordenes_list`) — cada operario "retoma" lo suyo, no
  /// lo que otro compañero dejó en curso en el mismo almacén.
  Future<List<OrdenListItem>> ordenesEnCurso({required int idAlmacen, required int idUsuario}) async {
    final resultados = await Future.wait([
      _api.listarOrdenes(estado: 'EN_PROCESO', idAlmacen: idAlmacen, idUsuario: idUsuario),
      _api.listarOrdenes(estado: 'PAUSADA', idAlmacen: idAlmacen, idUsuario: idUsuario),
    ]);
    return [...resultados[0], ...resultados[1]];
  }

  /// Historial de órdenes FINALIZADAS donde el usuario aparece como creador
  /// u operario (ver `orden_service.py::ordenes_list`), sin filtrar por
  /// almacén — es un historial personal de lo ya producido, no un panel de
  /// trabajo pendiente (para eso está "Retomar" en el Home).
  Future<List<OrdenListItem>> misProducciones({required int idUsuario, int limit = 100}) =>
      _api.listarOrdenes(idUsuario: idUsuario, estado: 'FINALIZADA', limit: limit);

  Future<void> pausar({required int idOrden, required int expectedVersion}) =>
      _api.pausar(idOrden: idOrden, expectedVersion: expectedVersion);

  Future<void> reanudar({required int idOrden, required int expectedVersion}) =>
      _api.reanudar(idOrden: idOrden, expectedVersion: expectedVersion);

  Future<void> finalizar({
    required int idOrden,
    required int expectedVersion,
    required List<FinalizarLineaIn> consumo,
    required List<FinalizarLineaIn> resultado,
    required List<FinalizarLineaIn> mermas,
  }) => _api.finalizar(
    idOrden: idOrden,
    expectedVersion: expectedVersion,
    consumo: consumo,
    resultado: resultado,
    mermas: mermas,
  );

  Future<void> anular({required int idOrden, required int expectedVersion, String? motivo}) =>
      _api.anular(idOrden: idOrden, expectedVersion: expectedVersion, motivo: motivo);
}
