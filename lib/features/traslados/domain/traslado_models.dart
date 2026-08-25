import '../../../core/utils/parsing.dart';

/// Fila de `GET /traslados/alertas-reacomodo` — existencia parada en una
/// zona RECEPCION/REACOMODO que necesita acomodarse a su ubicación final
/// (ver `traslados_ver.py::get_alertas_reacomodo`). Si `idTraspasoBorrador`
/// no es null, ya existe un traslado BORRADOR para esta existencia (el
/// flujo de la app no genera BORRADOR — ver nota en `traslados_repository`
/// — pero puede existir uno creado desde la web; en ese caso no se ofrece
/// "Trasladar" de nuevo para no duplicar).
class AlertaReacomodo {
  AlertaReacomodo({
    required this.idExistencia,
    required this.idLote,
    required this.idProducto,
    required this.productoNombre,
    required this.productoCodigo,
    required this.loteInterno,
    this.fechaVencimiento,
    required this.idUnidadMedida,
    required this.unidadSimbolo,
    required this.idUbicacion,
    required this.ubicacionNombre,
    required this.ubicacionCodigo,
    required this.tipoUbicacion,
    required this.cantidad,
    required this.cantidadDisponible,
    this.idTraspasoBorrador,
    this.codigoTraspasoBorrador,
    this.idUbicacionPreferida,
    this.ubicacionPreferidaNombre,
    this.ubicacionPreferidaCodigo,
  });

  factory AlertaReacomodo.fromJson(Map<String, dynamic> j) => AlertaReacomodo(
    idExistencia: j['id_existencia'] as int,
    idLote: j['id_lote'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    productoCodigo: j['producto_codigo'] as String? ?? '',
    loteInterno: j['lote_interno'] as String? ?? '',
    fechaVencimiento: parseDateOrNull(j['fecha_vencimiento']),
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    idUbicacion: j['id_ubicacion'] as int,
    ubicacionNombre: j['ubicacion_nombre'] as String? ?? '',
    ubicacionCodigo: j['ubicacion_codigo'] as String? ?? '',
    tipoUbicacion: j['tipo_ubicacion'] as String? ?? '',
    cantidad: parseDouble(j['cantidad']),
    cantidadDisponible: parseDouble(j['cantidad_disponible']),
    idTraspasoBorrador: j['id_traspaso_borrador'] as int?,
    codigoTraspasoBorrador: j['codigo_traspaso_borrador'] as String?,
    idUbicacionPreferida: j['id_ubicacion_preferida'] as int?,
    ubicacionPreferidaNombre: j['ubicacion_preferida_nombre'] as String?,
    ubicacionPreferidaCodigo: j['ubicacion_preferida_codigo'] as String?,
  );

  final int idExistencia;
  final int idLote;
  final int idProducto;
  final String productoNombre;
  final String productoCodigo;
  final String loteInterno;
  final DateTime? fechaVencimiento;
  final int idUnidadMedida;
  final String unidadSimbolo;
  final int idUbicacion;
  final String ubicacionNombre;
  final String ubicacionCodigo;

  /// 'RECEPCION' | 'REACOMODO'
  final String tipoUbicacion;
  final double cantidad;
  final double cantidadDisponible;
  final int? idTraspasoBorrador;
  final String? codigoTraspasoBorrador;

  /// Ubicación recomendada del producto (`productos_almacenaje.id_ubicacion_preferida`),
  /// null si no tiene una configurada.
  final int? idUbicacionPreferida;
  final String? ubicacionPreferidaNombre;
  final String? ubicacionPreferidaCodigo;
}

/// Header de `traspasos` (ver `traslados_ver.py::traslados_list`/`traslados_get`).
class Traslado {
  Traslado({
    required this.idTraspaso,
    required this.codigo,
    required this.idAlmacen,
    required this.almacenNombre,
    required this.estado,
    this.fechaTraspaso,
    this.observaciones,
    this.motivoAnulacion,
    required this.cantidadItems,
    required this.cantidadProductos,
    required this.cantidadTotal,
    this.usuarioCreacionUsername,
    required this.rowVersion,
  });

  factory Traslado.fromJson(Map<String, dynamic> j) => Traslado(
    idTraspaso: j['id_traspaso'] as int,
    codigo: j['codigo'] as String? ?? '',
    idAlmacen: j['id_almacen'] as int,
    almacenNombre: j['almacen_nombre'] as String? ?? '',
    estado: j['estado'] as String? ?? 'BORRADOR',
    fechaTraspaso: parseDateOrNull(j['fecha_traspaso']),
    observaciones: j['observaciones'] as String?,
    motivoAnulacion: j['motivo_anulacion'] as String?,
    cantidadItems: j['cantidad_items'] as int? ?? 0,
    cantidadProductos: j['cantidad_productos'] as int? ?? 0,
    cantidadTotal: parseDouble(j['cantidad_total']),
    usuarioCreacionUsername: j['usuario_creacion_username'] as String?,
    rowVersion: j['row_version'] as int,
  );

  final int idTraspaso;
  final String codigo;
  final int idAlmacen;
  final String almacenNombre;

  /// 'BORRADOR' | 'CONFIRMADO' | 'ANULADO'
  final String estado;
  final DateTime? fechaTraspaso;
  final String? observaciones;
  final String? motivoAnulacion;
  final int cantidadItems;
  final int cantidadProductos;
  final double cantidadTotal;
  final String? usuarioCreacionUsername;
  final int rowVersion;
}

/// Ítem de un traslado (ver `traslados_ver.py::traslados_get`).
class TrasladoItem {
  TrasladoItem({
    required this.idTraspasoItem,
    required this.idProducto,
    required this.productoNombre,
    required this.idLote,
    required this.loteInterno,
    required this.unidadSimbolo,
    required this.ubicacionOrigenNombre,
    required this.ubicacionOrigenCodigo,
    required this.ubicacionDestinoNombre,
    required this.ubicacionDestinoCodigo,
    required this.cantidad,
    this.observaciones,
  });

  factory TrasladoItem.fromJson(Map<String, dynamic> j) => TrasladoItem(
    idTraspasoItem: j['id_traspaso_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    idLote: j['id_lote'] as int,
    loteInterno: j['lote_interno'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    ubicacionOrigenNombre: j['ubicacion_origen_nombre'] as String? ?? '',
    ubicacionOrigenCodigo: j['ubicacion_origen_codigo'] as String? ?? '',
    ubicacionDestinoNombre: j['ubicacion_destino_nombre'] as String? ?? '',
    ubicacionDestinoCodigo: j['ubicacion_destino_codigo'] as String? ?? '',
    cantidad: parseDouble(j['cantidad']),
    observaciones: j['observaciones'] as String?,
  );

  final int idTraspasoItem;
  final int idProducto;
  final String productoNombre;
  final int idLote;
  final String loteInterno;
  final String unidadSimbolo;
  final String ubicacionOrigenNombre;
  final String ubicacionOrigenCodigo;
  final String ubicacionDestinoNombre;
  final String ubicacionDestinoCodigo;
  final double cantidad;
  final String? observaciones;
}

/// Movimiento de stock real generado al confirmar (ver `stock_movimientos`,
/// `traslados_ver.py::traslados_get`) — solo existe para traslados ya
/// CONFIRMADOs.
class TrasladoMovimiento {
  TrasladoMovimiento({
    required this.idMovimiento,
    required this.productoNombre,
    this.ubicacionOrigenNombre,
    this.ubicacionDestinoNombre,
    required this.cantidad,
    this.creadoEn,
    this.creadoPorUsername,
  });

  factory TrasladoMovimiento.fromJson(Map<String, dynamic> j) => TrasladoMovimiento(
    idMovimiento: j['id_movimiento'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    ubicacionOrigenNombre: j['ubicacion_origen_nombre'] as String?,
    ubicacionDestinoNombre: j['ubicacion_destino_nombre'] as String?,
    cantidad: parseDouble(j['cantidad']),
    creadoEn: parseDateOrNull(j['creado_en']),
    creadoPorUsername: j['creado_por_username'] as String?,
  );

  final int idMovimiento;
  final String productoNombre;
  final String? ubicacionOrigenNombre;
  final String? ubicacionDestinoNombre;
  final double cantidad;
  final DateTime? creadoEn;
  final String? creadoPorUsername;
}

/// Traslado + sus ítems + movimientos reales, para la pantalla de detalle.
class TrasladoDetalle {
  TrasladoDetalle({
    required this.traslado,
    required this.items,
    required this.movimientos,
  });

  final Traslado traslado;
  final List<TrasladoItem> items;
  final List<TrasladoMovimiento> movimientos;
}

/// Resultado de `POST /traslados/ejecutar` (ver `traslados_service.py`).
class EjecutarTrasladoResultado {
  EjecutarTrasladoResultado({
    required this.idTraspaso,
    required this.codigo,
    required this.itemsProcesados,
  });

  factory EjecutarTrasladoResultado.fromJson(Map<String, dynamic> j) =>
      EjecutarTrasladoResultado(
        idTraspaso: j['id_traspaso'] as int,
        codigo: j['codigo'] as String? ?? '',
        itemsProcesados: j['items_procesados'] as int? ?? 0,
      );

  final int idTraspaso;
  final String codigo;
  final int itemsProcesados;
}
