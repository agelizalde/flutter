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

  Future<List<OrdenListItem>> ordenesEnCurso({required int idAlmacen}) async {
    final resultados = await Future.wait([
      _api.listarOrdenes(estado: 'EN_PROCESO', idAlmacen: idAlmacen),
      _api.listarOrdenes(estado: 'PAUSADA', idAlmacen: idAlmacen),
    ]);
    return [...resultados[0], ...resultados[1]];
  }

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
