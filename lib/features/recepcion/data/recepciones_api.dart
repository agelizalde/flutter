import 'package:dio/dio.dart';

import '../domain/orden_compra_models.dart';
import '../domain/recepcion_models.dart';

/// Llamadas a `/recepciones/*` (ver `recepcion_rout.py`). Cubre el flujo
/// MANUAL y el flujo desde OC (`/recepciones/oc/*`, `/recepciones/desde-oc`)
/// más la resolución de control de calidad (`/recepciones/control/*`).
class RecepcionesApi {
  RecepcionesApi(this._dio);

  final Dio _dio;

  Future<List<Recepcion>> listar({
    String? q,
    String? estado,
    int? idUsuarioReceptor,
    int? idAlmacen,
    int limit = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones',
      queryParameters: {
        'origen_recepcion': 'MANUAL',
        if (q != null && q.isNotEmpty) 'q': q,
        'estado': ?estado,
        'id_usuario_receptor': ?idUsuarioReceptor,
        'id_almacen': ?idAlmacen,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Recepcion.fromJson).toList();
  }

  Future<Recepcion> obtener(int idRecepcion) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/$idRecepcion',
    );
    return Recepcion.fromJson(res.data!);
  }

  /// `GET /recepciones/ver/oc/{id_oc}` — recepciones ya generadas a partir
  /// de una OC (puede haber más de una, aunque en la práctica suele ser
  /// una sola activa). Usado por la hoja de acciones contextual al
  /// escanear una OC: si hay una recepción en curso, se ofrece
  /// continuarla/controlarla en vez de arrancar una nueva.
  Future<List<Recepcion>> porOc(int idOc) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/ver/oc/$idOc',
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Recepcion.fromJson).toList();
  }

  /// Trae solo el control de calidad de la recepción (quién recepcionó,
  /// quién controló, resultado, cantidades por ítem) — reusa el endpoint
  /// "full" que también consume la web, pidiendo apagado todo lo demás
  /// (historial/notas/stock) para no traer de más.
  Future<ControlRecepcion?> obtenerControl(int idRecepcion) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/ver/full/$idRecepcion',
      queryParameters: {
        'incluir_historial': false,
        'incluir_notas': false,
        'incluir_control': true,
        'incluir_stock': false,
      },
    );
    final control = res.data!['control'] as Map<String, dynamic>?;
    return control != null ? ControlRecepcion.fromJson(control) : null;
  }

  Future<Recepcion> crearManual({
    required int idProveedor,
    required int idAlmacen,
    int? idUbicacionRecepcion,
    String? observacion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/recepciones/manual',
      data: {
        'id_proveedor': idProveedor,
        'origen_recepcion': 'MANUAL',
        'id_almacen': idAlmacen,
        'id_ubicacion_recepcion': ?idUbicacionRecepcion,
        'observacion': ?observacion,
      },
    );
    return Recepcion.fromJson(res.data!);
  }

  Future<List<RecepcionItem>> listarItems(int idRecepcion) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/$idRecepcion/items',
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(RecepcionItem.fromJson).toList();
  }

  Future<RecepcionItem> agregarItem({
    required int idRecepcion,
    required int idProducto,
    required int idUnidadMedida,
    required double cantidad,
    String? loteProveedor,
    DateTime? fechaVencimiento,
    DateTime? fechaFaenado,
    String? observacion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/recepciones/$idRecepcion/items',
      data: {
        'id_producto': idProducto,
        'id_unidad_medida': idUnidadMedida,
        'cantidad': cantidad,
        'lote_proveedor': ?loteProveedor,
        'fecha_vencimiento': ?fechaVencimiento?.toIso8601String(),
        'fecha_faenado': ?fechaFaenado?.toIso8601String(),
        'observacion': ?observacion,
      },
    );
    return RecepcionItem.fromJson(res.data!);
  }

  /// `PATCH /recepciones/items/{id}` — solo se manda lo que cambió (todos
  /// los campos son opcionales del lado del backend, `null` = "no tocar").
  /// Usado por el flujo de recepción desde OC para completar, ítem por
  /// ítem, lo que el usuario cargó en la pantalla de tarjetas (cantidad
  /// aceptada/rechazada, lote, vencimiento, faena, observaciones) sobre los
  /// ítems que `crearDesdeOC` ya insertó con la cantidad pendiente completa.
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
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/recepciones/items/$idRecepcionItem',
      data: {
        'expected_version': expectedVersion,
        'cantidad': ?cantidad,
        'cantidad_rechazada': ?cantidadRechazada,
        'lote_proveedor': ?loteProveedor,
        'fecha_vencimiento': ?fechaVencimiento?.toIso8601String(),
        'fecha_faenado': ?fechaFaenado?.toIso8601String(),
        'observacion': ?observacion,
        'observacion_rechazo': ?observacionRechazo,
      },
    );
    return RecepcionItem.fromJson(res.data!);
  }

  Future<void> desactivarItem({
    required int idRecepcionItem,
    required int expectedVersion,
  }) {
    return _dio.post<void>(
      '/recepciones/items/$idRecepcionItem/desactivar',
      data: {'expected_version': expectedVersion},
    );
  }

  Future<ConfirmarRecepcionResultado> confirmar({
    required int idRecepcion,
    required int expectedVersion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/recepciones/$idRecepcion/confirmar',
      data: {'expected_version': expectedVersion, 'forzar_control': false},
    );
    return ConfirmarRecepcionResultado.fromJson(res.data!);
  }

  Future<List<RecepcionControlPendiente>> listarControlesPendientes() async {
    final res = await _dio.get<Map<String, dynamic>>('/recepciones/control/pendientes');
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(RecepcionControlPendiente.fromJson).toList();
  }

  Future<int> obtenerVersionControl(int idRecepcionControl) async {
    final res = await _dio.get<Map<String, dynamic>>('/recepciones/control/$idRecepcionControl');
    return res.data!['row_version'] as int;
  }

  Future<void> resolverControl({
    required int idRecepcionControl,
    required int expectedVersion,
    required String resultado,
    String? observacion,
    required List<Map<String, dynamic>> items,
  }) {
    return _dio.post<void>(
      '/recepciones/control/$idRecepcionControl/resolver',
      data: {
        'expected_version': expectedVersion,
        'resultado': resultado,
        'observacion': ?observacion,
        'items': items,
      },
    );
  }

  // =========================================================
  // ORDEN DE COMPRA -> RECEPCION (ver recepcion_oc.py)
  // =========================================================

  /// Resuelve el código escaneado (QR/barcode del documento de la OC) a su
  /// header. 404 si no existe ninguna OC con ese código; 409 si existe pero
  /// no está en un estado recepcionable (ver `_assert_oc_recepcionable` en
  /// el backend) — ambos casos llegan acá como `AppException` normal, no
  /// hace falta manejarlos distinto.
  Future<OrdenCompraHeader> buscarOcPorCodigo(String codigo) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/oc/buscar/$codigo',
    );
    return OrdenCompraHeader.fromJson(res.data!);
  }

  /// `GET /recepciones/oc/info/{codigo}` — igual que `buscarOcPorCodigo`
  /// pero de solo lectura: no exige que la OC esté en estado recepcionable
  /// y trae todos los ítems, no solo los pendientes. Usado por el escáner
  /// genérico de la app (Home), no por el flujo de recepción.
  Future<OrdenCompraDetalle> obtenerOcInfoPorCodigo(String codigo) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/oc/info/$codigo',
    );
    return OrdenCompraDetalle.fromJson(res.data!);
  }

  /// `GET /recepciones/oc/{id}/info` — igual que [obtenerOcInfoPorCodigo]
  /// pero por id. La usa `OcInfoScreen` para volver a pedir los datos en
  /// vez de depender del `extra` de go_router (no sobrevive de forma
  /// confiable un rebuild de la ruta en Flutter Web).
  Future<OrdenCompraDetalle> obtenerOcInfoPorId(int idOc) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/oc/$idOc/info',
    );
    return OrdenCompraDetalle.fromJson(res.data!);
  }

  Future<List<OrdenCompraSimple>> listarOcAprobadas({
    int? idProveedor,
    int? idAlmacen,
    String? q,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/oc/aprobadas',
      queryParameters: {
        'id_proveedor': ?idProveedor,
        'id_almacen': ?idAlmacen,
        'q': ?q,
        'limit': 100,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(OrdenCompraSimple.fromJson).toList();
  }

  Future<OrdenCompraDetalle> obtenerOcParaRecepcion(
    int idOc, {
    bool soloPendientes = true,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/recepciones/oc/$idOc',
      queryParameters: {'solo_pendientes': soloPendientes},
    );
    return OrdenCompraDetalle.fromJson(res.data!);
  }

  /// Crea el header de la recepción + copia todos los ítems pendientes de
  /// la OC a cantidad completa (ver `recepcion_oc.py:recepcion_create_from_oc`)
  /// — todavía sin lote/vencimiento/faena/rechazo, eso se completa después
  /// con `editarItem` por cada ítem según lo que el usuario cargó.
  Future<RecepcionDesdeOcResultado> crearDesdeOc({
    required int idOc,
    int? idUbicacionRecepcion,
    String? observacion,
    bool requiereControl = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/recepciones/desde-oc',
      data: {
        'id_oc': idOc,
        'id_ubicacion_recepcion': ?idUbicacionRecepcion,
        'observacion': ?observacion,
        'requiere_control': requiereControl,
        'copiar_solo_pendientes': true,
      },
    );
    return RecepcionDesdeOcResultado.fromJson(res.data!);
  }
}
