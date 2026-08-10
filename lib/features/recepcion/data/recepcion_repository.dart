import '../../stock/data/productos_api.dart';
import '../../stock/data/proveedores_api.dart';
import '../../stock/domain/stock_models.dart';
import '../domain/orden_compra_models.dart';
import '../domain/recepcion_models.dart';
import 'almacenes_api.dart';
import 'recepciones_api.dart';
import 'ubicaciones_api.dart';

/// Repositorio del feature Recepción. Reusa `ProductosApi`/`ProveedoresApi`
/// del feature Stock (son clientes genéricos de `/productos` y
/// `/proveedores`, no lógica específica de stock — ver
/// CONTEXTO_WHEREHOUSE.md §12c) en vez de duplicarlos.
class RecepcionRepository {
  RecepcionRepository(
    this._recepcionesApi,
    this._almacenesApi,
    this._ubicacionesApi,
    this._productosApi,
    this._proveedoresApi,
  );

  final RecepcionesApi _recepcionesApi;
  final AlmacenesApi _almacenesApi;
  final UbicacionesApi _ubicacionesApi;
  final ProductosApi _productosApi;
  final ProveedoresApi _proveedoresApi;

  Future<List<Recepcion>> listarRecepciones({
    String? q,
    String? estado,
    int? idUsuarioReceptor,
    int? idAlmacen,
    int limit = 50,
  }) {
    return _recepcionesApi.listar(
      q: q,
      estado: estado,
      idUsuarioReceptor: idUsuarioReceptor,
      idAlmacen: idAlmacen,
      limit: limit,
    );
  }

  Future<List<AlmacenSimple>> listarAlmacenes() => _almacenesApi.listar();

  Future<List<Recepcion>> recepcionesPorOc(int idOc) => _recepcionesApi.porOc(idOc);

  Future<List<UbicacionSimple>> listarUbicacionesDeRecepcion(int idAlmacen) =>
      _ubicacionesApi.listarDeRecepcion(idAlmacen);

  Future<List<ProveedorSimple>> buscarProveedores(String q) =>
      _proveedoresApi.buscar(q: q);

  Future<List<ProductoSimple>> buscarProductos(String q) =>
      _productosApi.buscar(q: q);

  Future<ProductoSimple> buscarProductoPorCodigoBarra(String codigoBarra) =>
      _productosApi.buscarPorCodigoBarra(codigoBarra);

  Future<(ProductoDetalle, ProductoAlmacenaje)> detalleProducto(
    int idProducto,
  ) => _productosApi.detalleConAlmacenaje(idProducto);

  Future<Recepcion> crearManual({
    required int idProveedor,
    required int idAlmacen,
    int? idUbicacionRecepcion,
    String? observacion,
  }) {
    return _recepcionesApi.crearManual(
      idProveedor: idProveedor,
      idAlmacen: idAlmacen,
      idUbicacionRecepcion: idUbicacionRecepcion,
      observacion: observacion,
    );
  }

  Future<RecepcionDetalle> obtenerDetalle(int idRecepcion) async {
    final resultados = await Future.wait([
      _recepcionesApi.obtener(idRecepcion),
      _recepcionesApi.listarItems(idRecepcion),
      _recepcionesApi.obtenerControl(idRecepcion),
    ]);
    return RecepcionDetalle(
      recepcion: resultados[0] as Recepcion,
      items: resultados[1] as List<RecepcionItem>,
      control: resultados[2] as ControlRecepcion?,
    );
  }

  Future<RecepcionItem> agregarItem({
    required int idRecepcion,
    required int idProducto,
    required int idUnidadMedida,
    required double cantidad,
    String? loteProveedor,
    DateTime? fechaVencimiento,
    DateTime? fechaFaenado,
  }) {
    return _recepcionesApi.agregarItem(
      idRecepcion: idRecepcion,
      idProducto: idProducto,
      idUnidadMedida: idUnidadMedida,
      cantidad: cantidad,
      loteProveedor: loteProveedor,
      fechaVencimiento: fechaVencimiento,
      fechaFaenado: fechaFaenado,
    );
  }

  Future<RecepcionItem> editarItem({
    required int idRecepcionItem,
    required int expectedVersion,
    double? cantidad,
    double? cantidadRechazada,
    String? loteProveedor,
    DateTime? fechaVencimiento,
    DateTime? fechaFaenado,
    String? observacion,
    String? observacionRechazo,
  }) {
    return _recepcionesApi.editarItem(
      idRecepcionItem: idRecepcionItem,
      expectedVersion: expectedVersion,
      cantidad: cantidad,
      cantidadRechazada: cantidadRechazada,
      loteProveedor: loteProveedor,
      fechaVencimiento: fechaVencimiento,
      fechaFaenado: fechaFaenado,
      observacion: observacion,
      observacionRechazo: observacionRechazo,
    );
  }

  Future<void> quitarItem({
    required int idRecepcionItem,
    required int expectedVersion,
  }) {
    return _recepcionesApi.desactivarItem(
      idRecepcionItem: idRecepcionItem,
      expectedVersion: expectedVersion,
    );
  }

  Future<ConfirmarRecepcionResultado> confirmar({
    required int idRecepcion,
    required int expectedVersion,
  }) {
    return _recepcionesApi.confirmar(
      idRecepcion: idRecepcion,
      expectedVersion: expectedVersion,
    );
  }

  Future<RecepcionControlPendiente?> buscarControlPendiente(int idRecepcion) async {
    final pendientes = await _recepcionesApi.listarControlesPendientes();
    for (final control in pendientes) {
      if (control.idRecepcion == idRecepcion) return control;
    }
    return null;
  }

  Future<int> obtenerVersionControl(int idRecepcionControl) =>
      _recepcionesApi.obtenerVersionControl(idRecepcionControl);

  Future<void> resolverControl({
    required int idRecepcionControl,
    required int expectedVersion,
    required String resultado,
    String? observacion,
    required List<Map<String, dynamic>> items,
  }) {
    return _recepcionesApi.resolverControl(
      idRecepcionControl: idRecepcionControl,
      expectedVersion: expectedVersion,
      resultado: resultado,
      observacion: observacion,
      items: items,
    );
  }

  // =========================================================
  // ORDEN DE COMPRA -> RECEPCION
  // =========================================================

  Future<OrdenCompraHeader> buscarOcPorCodigo(String codigo) =>
      _recepcionesApi.buscarOcPorCodigo(codigo);

  Future<OrdenCompraDetalle> obtenerOcInfoPorCodigo(String codigo) =>
      _recepcionesApi.obtenerOcInfoPorCodigo(codigo);

  Future<OrdenCompraDetalle> obtenerOcInfoPorId(int idOc) =>
      _recepcionesApi.obtenerOcInfoPorId(idOc);

  Future<List<OrdenCompraSimple>> listarOcAprobadas({
    int? idProveedor,
    int? idAlmacen,
    String? q,
  }) {
    return _recepcionesApi.listarOcAprobadas(
      idProveedor: idProveedor,
      idAlmacen: idAlmacen,
      q: q,
    );
  }

  Future<OrdenCompraDetalle> obtenerOcParaRecepcion(
    int idOc, {
    bool soloPendientes = true,
  }) {
    return _recepcionesApi.obtenerOcParaRecepcion(idOc, soloPendientes: soloPendientes);
  }

  Future<RecepcionDesdeOcResultado> crearDesdeOc({
    required int idOc,
    int? idUbicacionRecepcion,
    String? observacion,
    bool requiereControl = false,
  }) {
    return _recepcionesApi.crearDesdeOc(
      idOc: idOc,
      idUbicacionRecepcion: idUbicacionRecepcion,
      observacion: observacion,
      requiereControl: requiereControl,
    );
  }
}
