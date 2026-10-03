import '../../../core/utils/parsing.dart';

/// Fila de `GET /stock/por-producto` — resultado de búsqueda por nombre.
/// Ya viene con los agregados de stock calculados en el backend
/// (`stock_service.py:stock_por_producto`).
class ProductoConStock {
  ProductoConStock({
    required this.idProducto,
    required this.codigoInterno,
    this.sku,
    required this.nombre,
    required this.unidadSimbolo,
    required this.stockTotal,
    required this.stockReservado,
    required this.stockDisponible,
    required this.cantidadLotes,
    required this.cantidadUbicaciones,
  });

  factory ProductoConStock.fromJson(Map<String, dynamic> j) => ProductoConStock(
    idProducto: j['id_producto'] as int,
    codigoInterno: j['codigo_interno'] as String? ?? '',
    sku: j['sku'] as String?,
    nombre: j['producto_nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    stockTotal: parseDouble(j['stock_total']),
    stockReservado: parseDouble(j['stock_reservado']),
    stockDisponible: parseDouble(j['stock_disponible']),
    cantidadLotes: j['cantidad_lotes'] as int? ?? 0,
    cantidadUbicaciones: j['cantidad_ubicaciones'] as int? ?? 0,
  );

  final int idProducto;
  final String codigoInterno;
  final String? sku;
  final String nombre;
  final String unidadSimbolo;
  final double stockTotal;
  final double stockReservado;
  final double stockDisponible;
  final int cantidadLotes;
  final int cantidadUbicaciones;
}

/// `data` de `GET /stock/por-producto/{id}/resumen` — totales de UN
/// producto puntual (siempre existe aunque no tenga stock físico).
class StockResumen {
  StockResumen({
    required this.idProducto,
    required this.unidadSimbolo,
    this.cantidadSolicitud,
    this.cantidadQuiebre,
    this.capacidadMaxima,
    this.obsRecepcion,
    this.ubicacionPreferidaNombre,
    this.ubicacionPreferidaCodigo,
    this.ubicacionAutomaticaNombre,
    this.ubicacionAutomaticaCodigo,
    required this.stockTotal,
    required this.stockReservado,
    required this.stockDisponible,
  });

  factory StockResumen.fromJson(Map<String, dynamic> j) => StockResumen(
    idProducto: j['id_producto'] as int,
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    cantidadSolicitud: parseDoubleOrNull(j['cantidad_solicitud']),
    cantidadQuiebre: parseDoubleOrNull(j['cantidad_quiebre']),
    capacidadMaxima: parseDoubleOrNull(j['capacidad_maxima']),
    obsRecepcion: j['obs_recepcion'] as String?,
    ubicacionPreferidaNombre: j['ubicacion_preferida_nombre'] as String?,
    ubicacionPreferidaCodigo: j['ubicacion_preferida_codigo'] as String?,
    ubicacionAutomaticaNombre: j['ubicacion_automatica_nombre'] as String?,
    ubicacionAutomaticaCodigo: j['ubicacion_automatica_codigo'] as String?,
    stockTotal: parseDouble(j['stock_total']),
    stockReservado: parseDouble(j['stock_reservado']),
    stockDisponible: parseDouble(j['stock_disponible']),
  );

  final int idProducto;
  final String unidadSimbolo;
  final double? cantidadSolicitud;
  final double? cantidadQuiebre;

  /// `productos_almacenaje.capacidad_maxima` — tope físico del producto en
  /// depósito (misma unidad que el stock).
  final double? capacidadMaxima;

  /// `productos_almacenaje.obs_recepcion` — texto libre para quien recibe
  /// este producto.
  final String? obsRecepcion;

  /// Ubicación recomendada (`id_ubicacion_preferida`) — solo sugerencia,
  /// no cambia el comportamiento de recepción.
  final String? ubicacionPreferidaNombre;
  final String? ubicacionPreferidaCodigo;

  /// Ubicación automática (`id_ubicacion_automatica`) — si está definida,
  /// la recepción va directo ahí en vez de la ubicación elegida/por defecto.
  final String? ubicacionAutomaticaNombre;
  final String? ubicacionAutomaticaCodigo;

  final double stockTotal;
  final double stockReservado;
  final double stockDisponible;
}

/// Fila de `GET /stock/existencias` — detalle granular lote+ubicación.
class ExistenciaStock {
  ExistenciaStock({
    required this.idExistencia,
    required this.idLote,
    required this.loteInterno,
    this.loteProveedor,
    this.fechaVencimiento,
    required this.idProducto,
    required this.productoNombre,
    required this.idUnidadMedida,
    required this.unidadSimbolo,
    required this.unidadPesable,
    required this.idUbicacion,
    required this.ubicacionNombre,
    required this.ubicacionCodigo,
    required this.almacenNombre,
    required this.cantidad,
    required this.cantidadReservadaPicking,
    required this.cantidadDisponible,
    this.esUbicacionRecomendada = false,
    this.idUbicacionPreferida,
    this.ubicacionPreferidaNombre,
    this.ubicacionPreferidaCodigo,
  });

  factory ExistenciaStock.fromJson(Map<String, dynamic> j) => ExistenciaStock(
    idExistencia: j['id_existencia'] as int,
    idLote: j['id_lote'] as int,
    loteInterno: j['lote_interno'] as String? ?? '',
    loteProveedor: j['lote_proveedor'] as String?,
    fechaVencimiento: parseDateOrNull(j['fecha_vencimiento']),
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    unidadPesable: j['unidad_pesable'] == 1 || j['unidad_pesable'] == true,
    idUbicacion: j['id_ubicacion'] as int,
    ubicacionNombre: j['ubicacion_nombre'] as String? ?? '',
    ubicacionCodigo: j['ubicacion_codigo'] as String? ?? '',
    almacenNombre: j['almacen_nombre'] as String? ?? '',
    cantidad: parseDouble(j['cantidad']),
    cantidadReservadaPicking: parseDouble(j['cantidad_reservada_picking']),
    cantidadDisponible: parseDouble(j['cantidad_disponible']),
    esUbicacionRecomendada: j['es_ubicacion_recomendada'] == 1 || j['es_ubicacion_recomendada'] == true,
    idUbicacionPreferida: j['id_ubicacion_preferida'] as int?,
    ubicacionPreferidaNombre: j['ubicacion_preferida_nombre'] as String?,
    ubicacionPreferidaCodigo: j['ubicacion_preferida_codigo'] as String?,
  );

  final int idExistencia;
  final int idLote;
  final String loteInterno;
  final String? loteProveedor;
  final DateTime? fechaVencimiento;
  final int idProducto;
  final String productoNombre;
  final int idUnidadMedida;
  final String unidadSimbolo;

  /// `unidades.pesable` — ver `formatCantidad` en `core/utils/parsing.dart`.
  final bool unidadPesable;
  final int idUbicacion;
  final String ubicacionNombre;
  final String ubicacionCodigo;
  final String almacenNombre;
  final double cantidad;
  final double cantidadReservadaPicking;
  final double cantidadDisponible;

  /// `true` si esta ubicación coincide con la "ubicación recomendada" del
  /// producto (`productos_almacenaje.id_ubicacion_preferida`).
  final bool esUbicacionRecomendada;

  /// Ubicación recomendada del producto, resuelta (null si no tiene una
  /// configurada) — vale para cualquier fila del mismo producto, sea o no
  /// la ubicación de esta existencia puntual.
  final int? idUbicacionPreferida;
  final String? ubicacionPreferidaNombre;
  final String? ubicacionPreferidaCodigo;
}

/// Fila de `GET /stock/por-ubicacion` — resultado de búsqueda por ubicación.
class UbicacionStock {
  UbicacionStock({
    required this.idUbicacion,
    required this.ubicacionNombre,
    required this.ubicacionCodigo,
    required this.tipoUbicacion,
    required this.almacenNombre,
    required this.cantidadProductos,
    required this.cantidadLotes,
    required this.cantidadTotal,
    required this.cantidadReservada,
    required this.cantidadDisponible,
  });

  factory UbicacionStock.fromJson(Map<String, dynamic> j) => UbicacionStock(
    idUbicacion: j['id_ubicacion'] as int,
    ubicacionNombre: j['ubicacion_nombre'] as String? ?? '',
    ubicacionCodigo: j['ubicacion_codigo'] as String? ?? '',
    tipoUbicacion: j['tipo_ubicacion'] as String? ?? '',
    almacenNombre: j['almacen_nombre'] as String? ?? '',
    cantidadProductos: j['cantidad_productos'] as int? ?? 0,
    cantidadLotes: j['cantidad_lotes'] as int? ?? 0,
    cantidadTotal: parseDouble(j['cantidad_total']),
    cantidadReservada: parseDouble(j['cantidad_reservada']),
    cantidadDisponible: parseDouble(j['cantidad_disponible']),
  );

  final int idUbicacion;
  final String ubicacionNombre;
  final String ubicacionCodigo;
  final String tipoUbicacion;
  final String almacenNombre;
  final int cantidadProductos;
  final int cantidadLotes;
  final double cantidadTotal;
  final double cantidadReservada;
  final double cantidadDisponible;
}

/// Fila de `GET /proveedores` — resultado de búsqueda por proveedor.
class ProveedorSimple {
  ProveedorSimple({
    required this.idProveedor,
    required this.codigoProveedor,
    required this.razonSocial,
    this.nombreComercial,
  });

  factory ProveedorSimple.fromJson(Map<String, dynamic> j) => ProveedorSimple(
    idProveedor: j['id_proveedor'] as int,
    codigoProveedor: j['codigo_proveedor'] as String? ?? '',
    razonSocial: j['razon_social'] as String? ?? '',
    nombreComercial: j['nombre_comercial'] as String?,
  );

  final int idProveedor;
  final String codigoProveedor;
  final String razonSocial;
  final String? nombreComercial;
}

/// Fila de `GET /productos` — usado para listar productos de un proveedor y
/// para el buscador genérico (`escaner/`), que necesita el catálogo
/// completo (incluso sin stock) en vez de la vista atada a
/// `stock_existencias` (`ProductoConStock`).
class ProductoSimple {
  ProductoSimple({
    required this.idProducto,
    required this.codigoInterno,
    this.sku,
    required this.nombre,
    required this.unidadSimbolo,
    this.claseProducto,
    this.fotoUrl,
  });

  factory ProductoSimple.fromJson(Map<String, dynamic> j) => ProductoSimple(
    idProducto: j['id_producto'] as int,
    codigoInterno: j['codigo_interno'] as String? ?? '',
    sku: j['sku'] as String?,
    nombre: j['nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    claseProducto: j['clase_producto'] as String?,
    fotoUrl: j['foto_url'] as String?,
  );

  final int idProducto;
  final String codigoInterno;
  final String? sku;
  final String nombre;
  final String unidadSimbolo;

  /// 'FISICO' | 'SERVICIO' | 'KIT' — `null` en los endpoints que no lo
  /// devuelven (ej. búsqueda por código de barra).
  final String? claseProducto;

  /// Foto principal del producto (`productos_fotos`, `es_principal=1`), ya
  /// sea `null` (sin foto) o una URL relativa (`/static/...`, hay que
  /// resolverla con `Env.resolveStorageUrl`) o absoluta (backend OCI).
  final String? fotoUrl;
}

/// `producto` de `GET /productos/{id}` — ficha completa para la pantalla
/// de detalle ("Datos del producto").
class ProductoDetalle {
  ProductoDetalle({
    required this.idProducto,
    required this.codigoInterno,
    this.sku,
    required this.nombre,
    this.descripcion,
    this.categoriaNombre,
    this.marcaNombre,
    this.proveedorNombre,
    required this.idUnidadBase,
    required this.unidadNombre,
    required this.unidadSimbolo,
    required this.unidadPesable,
    this.claseProducto,
    this.fotoUrl,
  });

  factory ProductoDetalle.fromJson(Map<String, dynamic> j) => ProductoDetalle(
    idProducto: j['id_producto'] as int,
    codigoInterno: j['codigo_interno'] as String? ?? '',
    sku: j['sku'] as String?,
    nombre: j['nombre'] as String? ?? '',
    descripcion: j['descripcion'] as String?,
    categoriaNombre: j['categoria_nombre'] as String?,
    marcaNombre: j['marca_nombre'] as String?,
    proveedorNombre: j['proveedor_nombre'] as String?,
    idUnidadBase: j['id_unidad_base'] as int,
    unidadNombre: j['unidad_nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    unidadPesable: j['unidad_pesable'] == 1 || j['unidad_pesable'] == true,
    claseProducto: j['clase_producto'] as String?,
    fotoUrl: j['foto_url'] as String?,
  );

  final int idProducto;
  final String codigoInterno;
  final String? sku;
  final String nombre;
  final String? descripcion;
  final String? categoriaNombre;
  final String? marcaNombre;
  final String? proveedorNombre;
  final int idUnidadBase;
  final String unidadNombre;
  final String unidadSimbolo;

  /// `unidades.pesable` — solo estas unidades (ej. Kilogramo) pueden tener
  /// cantidades con parte decimal; el resto siempre se redondea a entero
  /// (ver `formatCantidad`). Mismo campo que ya usa el backend para picking
  /// por peso y recepción (`picking_operario_service.py`, `recepcion_oc.py`).
  final bool unidadPesable;

  /// 'FISICO' | 'SERVICIO' | 'KIT'.
  final String? claseProducto;

  /// Foto principal (`productos_fotos`, `es_principal=1`) — mismo criterio
  /// que `ProductoSimple.fotoUrl`, resolver con `Env.resolveStorageUrl`.
  final String? fotoUrl;
}

/// `almacenaje` de `GET /productos/{id}` — flags que determinan qué
/// campos son obligatorios al recibir el producto (lote/vencimiento/faena).
/// Usado por el módulo de Recepción para armar el formulario de ítem
/// dinámicamente según el producto elegido.
class ProductoAlmacenaje {
  ProductoAlmacenaje({
    required this.requiereLote,
    required this.requiereVencimiento,
    required this.requiereFechaFaena,
  });

  factory ProductoAlmacenaje.fromJson(Map<String, dynamic> j) =>
      ProductoAlmacenaje(
        requiereLote: (j['requiere_lote'] as int? ?? 0) == 1,
        requiereVencimiento: (j['control_vencimiento'] as int? ?? 0) == 1,
        requiereFechaFaena: (j['requiere_fecha_faena'] as int? ?? 0) == 1,
      );

  final bool requiereLote;
  final bool requiereVencimiento;
  final bool requiereFechaFaena;
}

/// Composición de las 3 llamadas que arman la pantalla de detalle:
/// ficha del producto + totales de stock + desglose por lote/ubicación.
class ProductoStockDetalle {
  ProductoStockDetalle({
    required this.producto,
    required this.resumen,
    required this.existencias,
  });

  final ProductoDetalle producto;
  final StockResumen resumen;
  final List<ExistenciaStock> existencias;
}
