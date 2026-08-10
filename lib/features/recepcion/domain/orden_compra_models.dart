import '../../../core/utils/parsing.dart';
import 'recepcion_models.dart';

/// Fila de `GET /recepciones/oc/aprobadas` (ver
/// `recepcion_oc.py:oc_list_aprobadas_para_recepcion`) — OC aprobadas de un
/// proveedor, para el paso "elegí qué OC vas a recibir".
class OrdenCompraSimple {
  OrdenCompraSimple({
    required this.idOc,
    required this.codigo,
    required this.idProveedor,
    required this.proveedorNombre,
    this.almacenNombre,
    required this.estado,
    this.fechaEntrega,
    this.observaciones,
    required this.itemsPendientes,
  });

  factory OrdenCompraSimple.fromJson(Map<String, dynamic> j) => OrdenCompraSimple(
    idOc: j['id_oc'] as int,
    codigo: j['codigo'] as String? ?? 'OC-${j['id_oc']}',
    idProveedor: j['id_proveedor'] as int,
    proveedorNombre: (j['proveedor_nombre_comercial'] as String?)?.trim().isNotEmpty == true
        ? j['proveedor_nombre_comercial'] as String
        : (j['proveedor_razon_social'] as String? ?? ''),
    almacenNombre: j['almacen_nombre'] as String?,
    estado: j['estado'] as String? ?? 'APROBADO',
    fechaEntrega: parseDateOrNull(j['fecha_entrega']),
    observaciones: j['observaciones'] as String?,
    itemsPendientes: j['items_pendientes'] as int? ?? 0,
  );

  final int idOc;
  final String codigo;
  final int idProveedor;
  final String proveedorNombre;
  final String? almacenNombre;
  final String estado;
  final DateTime? fechaEntrega;
  final String? observaciones;
  final int itemsPendientes;
}

/// Header de una OC resuelta para recepción — viene de
/// `GET /recepciones/oc/buscar/{codigo}` (escaneo del QR del documento) o
/// del bloque `header` de `GET /recepciones/oc/{id}` (ver
/// `recepcion_oc.py:_get_oc_header`).
class OrdenCompraHeader {
  OrdenCompraHeader({
    required this.idOc,
    required this.codigo,
    required this.idProveedor,
    required this.proveedorNombre,
    this.almacenDestinoNombre,
    required this.estado,
    required this.activo,
    required this.rowVersion,
    this.fechaEntrega,
    this.observaciones,
  });

  factory OrdenCompraHeader.fromJson(Map<String, dynamic> j) => OrdenCompraHeader(
    idOc: j['id_oc'] as int,
    codigo: j['codigo'] as String? ?? 'OC-${j['id_oc']}',
    idProveedor: j['id_proveedor'] as int,
    proveedorNombre: (j['proveedor_nombre_comercial'] as String?)?.trim().isNotEmpty == true
        ? j['proveedor_nombre_comercial'] as String
        : (j['proveedor_razon_social'] as String? ?? ''),
    almacenDestinoNombre: j['almacen_destino_nombre'] as String?,
    estado: j['estado'] as String? ?? 'APROBADO',
    activo: j['activo'] as bool? ?? true,
    rowVersion: j['row_version'] as int,
    fechaEntrega: parseDateOrNull(j['fecha_entrega']),
    observaciones: j['observaciones'] as String?,
  );

  final int idOc;
  final String codigo;
  final int idProveedor;
  final String proveedorNombre;
  final String? almacenDestinoNombre;
  final String estado;
  final bool activo;
  final int rowVersion;
  final DateTime? fechaEntrega;
  final String? observaciones;
}

/// Ítem de OC pendiente de recibir — fila de la lista `items` de
/// `GET /recepciones/oc/{id}` (ver `recepcion_oc.py:_get_oc_items_detalle`).
/// Trae los mismos flags requiereLote/Vencimiento/Faena + vidaUtilDias que
/// ya usa el formulario de ítem manual (`ProductoAlmacenaje`), más las
/// cantidades solicitada/recibida/pendiente de la OC.
class OrdenCompraItemDetalle {
  OrdenCompraItemDetalle({
    required this.idOcItem,
    required this.idProducto,
    required this.productoNombre,
    required this.manejaStock,
    required this.requiereLote,
    required this.requiereVencimiento,
    required this.requiereFaena,
    this.vidaUtilDias,
    required this.idUnidadMedida,
    required this.unidadNombre,
    required this.unidadSimbolo,
    required this.cantidadSolicitada,
    required this.cantidadRecibida,
    required this.cantidadPendiente,
    required this.requierePesaje,
  });

  factory OrdenCompraItemDetalle.fromJson(Map<String, dynamic> j) => OrdenCompraItemDetalle(
    idOcItem: j['id_oc_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    manejaStock: j['maneja_stock'] as bool? ?? true,
    requiereLote: j['requiere_lote'] as bool? ?? false,
    requiereVencimiento: j['requiere_vencimiento'] as bool? ?? false,
    requiereFaena: j['requiere_faena'] as bool? ?? false,
    vidaUtilDias: j['vida_util_dias'] as int?,
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadNombre: j['unidad_nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    // Estos vienen como string (`str(Decimal)`, ver
    // `recepcion_oc.py:oc_get_para_recepcion`), no como número JSON.
    cantidadSolicitada: parseDouble(j['cantidad_solicitada']),
    cantidadRecibida: parseDouble(j['cantidad_recibida']),
    cantidadPendiente: parseDouble(j['cantidad_pendiente']),
    // La OC ya está en la unidad base del producto desde que se confirmó (ver
    // oc_aprobaciones.py:oc_confirmar) — acá no hace falta convertir nada,
    // solo saber si esa unidad requiere pesaje (`unidades.pesable`).
    requierePesaje: j['requiere_pesaje'] as bool? ?? false,
  );

  final int idOcItem;
  final int idProducto;
  final String productoNombre;
  final bool manejaStock;
  final bool requiereLote;
  final bool requiereVencimiento;
  final bool requiereFaena;

  /// Vida útil mínima en días — si está seteada, el vencimiento cargado no
  /// puede ser anterior a hoy + esta cantidad de días (mismo criterio que
  /// ya valida el backend en `recepcion_confirmacion.py`).
  final int? vidaUtilDias;
  final int idUnidadMedida;
  final String unidadNombre;
  final String unidadSimbolo;
  final double cantidadSolicitada;
  final double cantidadRecibida;
  final double cantidadPendiente;

  /// Si es `true`, hay que pesar al recibir (puede diferir del teórico =
  /// `cantidadPendiente`); si es `false`, se acepta la cantidad cargada tal cual.
  final bool requierePesaje;
}

/// Header + ítems pendientes de una OC, lo que necesita la pantalla de
/// carga de ítems (`GET /recepciones/oc/{id}?solo_pendientes=true`).
class OrdenCompraDetalle {
  OrdenCompraDetalle({required this.header, required this.items});

  factory OrdenCompraDetalle.fromJson(Map<String, dynamic> j) => OrdenCompraDetalle(
    header: OrdenCompraHeader.fromJson(j['header'] as Map<String, dynamic>),
    items: (j['items'] as List<dynamic>? ?? [])
        .map((e) => OrdenCompraItemDetalle.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final OrdenCompraHeader header;
  final List<OrdenCompraItemDetalle> items;
}

/// Ítem recién importado al crear la recepción desde la OC (ver
/// `recepcion_oc.py:recepcion_create_from_oc`, bloque `importacion.items`).
/// Trae el `idRecepcionItem` recién creado — el puente entre "el ítem de OC
/// que el usuario cargó en pantalla" y "el ítem de recepción que hay que
/// editar (PATCH) con lo cargado".
class RecepcionDesdeOcItemImportado {
  RecepcionDesdeOcItemImportado({
    required this.idRecepcionItem,
    required this.idOcItem,
  });

  factory RecepcionDesdeOcItemImportado.fromJson(Map<String, dynamic> j) =>
      RecepcionDesdeOcItemImportado(
        idRecepcionItem: j['id_recepcion_item'] as int,
        idOcItem: j['id_oc_item'] as int,
      );

  final int idRecepcionItem;
  final int idOcItem;
}

/// Resultado de `POST /recepciones/desde-oc`: la recepción recién creada
/// (BORRADOR, con todos los ítems pendientes copiados a cantidad completa) +
/// el mapeo idOcItem→idRecepcionItem para poder editar cada ítem con lo que
/// el usuario cargó en la pantalla de tarjetas.
class RecepcionDesdeOcResultado {
  RecepcionDesdeOcResultado({required this.recepcion, required this.itemsImportados});

  factory RecepcionDesdeOcResultado.fromJson(Map<String, dynamic> j) => RecepcionDesdeOcResultado(
    recepcion: Recepcion.fromJson(j['recepcion'] as Map<String, dynamic>),
    itemsImportados: ((j['importacion'] as Map<String, dynamic>?)?['items'] as List<dynamic>? ?? [])
        .map((e) => RecepcionDesdeOcItemImportado.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  final Recepcion recepcion;
  final List<RecepcionDesdeOcItemImportado> itemsImportados;
}
