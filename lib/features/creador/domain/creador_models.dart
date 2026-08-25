/// Modelos livianos del módulo "Creador" — acceso rápido para dar de alta
/// (y editar) los catálogos base del ERP desde el depósito: Proveedores,
/// Marcas, Productos, Zonas y Ubicaciones. Cada modelo trae solo los campos
/// que el formulario simple necesita + `rowVersion` para el patch optimista
/// (ver CONTEXTO.md raíz §7.7) — no son un espejo completo de las tablas.

bool _asBool(dynamic v) => v == true || v == 1 || v == '1';

int _asRowVersion(Map<String, dynamic> j) =>
    (j['row_version'] as num?)?.toInt() ?? 1;

/// `GET/POST/PATCH /proveedores` (ver `proveedores_service.py`).
class ProveedorCreador {
  ProveedorCreador({
    required this.idProveedor,
    required this.nombreComercial,
    required this.razonSocial,
    required this.ruc,
    required this.dv,
    required this.activo,
    required this.rowVersion,
  });

  factory ProveedorCreador.fromJson(Map<String, dynamic> j) => ProveedorCreador(
    idProveedor: j['id_proveedor'] as int,
    nombreComercial: j['nombre_comercial'] as String?,
    razonSocial: j['razon_social'] as String? ?? '',
    ruc: j['ruc'] as String?,
    dv: j['dv'] as String?,
    activo: j['activo'] == null ? true : _asBool(j['activo']),
    rowVersion: _asRowVersion(j),
  );

  final int idProveedor;
  final String? nombreComercial;
  final String razonSocial;
  final String? ruc;
  final String? dv;
  final bool activo;
  final int rowVersion;

  String get etiqueta =>
      nombreComercial?.isNotEmpty == true ? nombreComercial! : razonSocial;
}

/// `GET/POST/PATCH /productos/marcas` (ver `marcas_productos_service.py`).
class MarcaCreador {
  MarcaCreador({
    required this.idMarca,
    required this.nombre,
    required this.activo,
    required this.rowVersion,
  });

  factory MarcaCreador.fromJson(Map<String, dynamic> j) => MarcaCreador(
    idMarca: j['id_marca'] as int,
    nombre: j['nombre'] as String? ?? '',
    activo: j['activo'] == null ? true : _asBool(j['activo']),
    rowVersion: _asRowVersion(j),
  );

  final int idMarca;
  final String nombre;
  final bool activo;
  final int rowVersion;
}

/// `GET /productos/categorias/` (ver `categorias_producto_service.py`) —
/// solo lectura acá, el "Creador" no da de alta categorías nuevas (el spec
/// las trata como catálogo ya existente a elegir).
class CategoriaCreador {
  CategoriaCreador({
    required this.idCategoriaTipo,
    required this.nombre,
    this.idPadre,
  });

  factory CategoriaCreador.fromJson(Map<String, dynamic> j) => CategoriaCreador(
    idCategoriaTipo: j['id_categoria_tipo'] as int,
    nombre: j['nombre'] as String? ?? '',
    idPadre: j['id_categoria_tipo_padre'] as int?,
  );

  final int idCategoriaTipo;
  final String nombre;
  final int? idPadre;
}

/// `GET /productos/unidades` (ver `unidades_medida_service.py`).
class UnidadCreador {
  UnidadCreador({required this.idUnidad, required this.nombre, this.simbolo});

  factory UnidadCreador.fromJson(Map<String, dynamic> j) => UnidadCreador(
    idUnidad: j['id_unidad'] as int,
    nombre: j['nombre'] as String? ?? '',
    simbolo: j['simbolo'] as String?,
  );

  final int idUnidad;
  final String nombre;
  final String? simbolo;

  String get etiqueta =>
      simbolo?.isNotEmpty == true ? '$nombre ($simbolo)' : nombre;
}

/// `GET /impuestos` (ver `impuestos_service.py`).
class ImpuestoCreador {
  ImpuestoCreador({required this.idImpuesto, required this.nombre});

  factory ImpuestoCreador.fromJson(Map<String, dynamic> j) => ImpuestoCreador(
    idImpuesto: j['id_impuesto'] as int,
    nombre: j['nombre'] as String? ?? '',
  );

  final int idImpuesto;
  final String nombre;
}

/// `GET /monedas` (ver `monedas_service.py`) — usada solo para resolver el
/// id de PYG, que se precarga por defecto en Proveedores (ver spec).
class MonedaCreador {
  MonedaCreador({
    required this.idMoneda,
    required this.codigoIso,
    required this.nombre,
  });

  factory MonedaCreador.fromJson(Map<String, dynamic> j) => MonedaCreador(
    idMoneda: j['id_moneda'] as int,
    codigoIso: j['codigo_iso'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
  );

  final int idMoneda;
  final String codigoIso;
  final String nombre;
}

/// `GET/POST/PATCH /productos` — solo los campos que el alta rápida
/// necesita mostrar en la lista y precargar al editar (ver
/// `productos_crear_ver.py` / `productos_editar.py`). `requiereLote` /
/// `controlVencimiento` / `vidaUtilDias` vienen de `productos_almacenaje`
/// y se piden aparte con `CreadorApi.productoAlmacenaje` (la lista de
/// `/productos` no los trae).
class ProductoCreador {
  ProductoCreador({
    required this.idProducto,
    required this.codigoInterno,
    required this.nombre,
    this.idMarca,
    this.marcaNombre,
    this.idCategoriaTipo,
    this.categoriaNombre,
    required this.idUnidadBase,
    this.unidadNombre,
    this.idProveedorCabecera,
    this.proveedorNombre,
    this.idImpuesto,
    this.impuestoNombre,
    required this.activo,
    required this.rowVersion,
  });

  factory ProductoCreador.fromJson(Map<String, dynamic> j) => ProductoCreador(
    idProducto: j['id_producto'] as int,
    codigoInterno: j['codigo_interno'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    idMarca: j['id_marca'] as int?,
    marcaNombre: j['marca_nombre'] as String?,
    idCategoriaTipo: j['id_categoria_tipo'] as int?,
    categoriaNombre: j['categoria_nombre'] as String?,
    idUnidadBase: j['id_unidad_base'] as int,
    unidadNombre: j['unidad_nombre'] as String?,
    idProveedorCabecera: j['id_proveedor_cabecera'] as int?,
    proveedorNombre: j['proveedor_nombre'] as String?,
    idImpuesto: j['id_impuesto'] as int?,
    impuestoNombre: j['impuesto_nombre'] as String?,
    activo: j['activo'] == null ? true : _asBool(j['activo']),
    rowVersion: _asRowVersion(j),
  );

  final int idProducto;
  final String codigoInterno;
  final String nombre;
  final int? idMarca;
  final String? marcaNombre;
  final int? idCategoriaTipo;
  final String? categoriaNombre;
  final int idUnidadBase;
  final String? unidadNombre;
  final int? idProveedorCabecera;
  final String? proveedorNombre;
  final int? idImpuesto;
  final String? impuestoNombre;
  final bool activo;
  final int rowVersion;
}

/// Flags de `productos_almacenaje` que le importan al formulario simple
/// ("Requiere vencimiento / lote" es un único toggle en el spec, ver
/// `ProductosTab`).
class ProductoAlmacenajeSimple {
  ProductoAlmacenajeSimple({
    required this.requiereVencimientoLote,
    this.vidaUtilDias,
  });

  factory ProductoAlmacenajeSimple.fromJson(Map<String, dynamic>? j) {
    if (j == null)
      return ProductoAlmacenajeSimple(requiereVencimientoLote: false);
    final requiereLote = _asBool(j['requiere_lote']);
    final controlVencimiento = _asBool(j['control_vencimiento']);
    return ProductoAlmacenajeSimple(
      requiereVencimientoLote: requiereLote || controlVencimiento,
      vidaUtilDias: (j['vida_util_dias'] as num?)?.toInt(),
    );
  }

  final bool requiereVencimientoLote;
  final int? vidaUtilDias;
}

const tiposCodigoBarra = <String>[
  'EAN13',
  'EAN8',
  'UPC',
  'CODE128',
  'QR',
  'INTERNO',
  'OTRO',
];

/// `GET/POST/PATCH /productos/codigos-barra` (ver
/// `producto_codigo_barra_service.py`). Un producto puede tener varios
/// códigos de barra; `principal` marca cuál usar por defecto (el backend se
/// encarga de dejar uno solo marcado por producto).
class CodigoBarraCreador {
  CodigoBarraCreador({
    required this.idCodigoBarra,
    required this.idProducto,
    this.productoNombre,
    this.productoCodigoInterno,
    required this.codigoBarra,
    required this.tipoCodigo,
    required this.principal,
    required this.activo,
    this.observaciones,
    required this.rowVersion,
  });

  factory CodigoBarraCreador.fromJson(Map<String, dynamic> j) =>
      CodigoBarraCreador(
        idCodigoBarra: j['id_codigo_barra'] as int,
        idProducto: j['id_producto'] as int,
        productoNombre: j['producto_nombre'] as String?,
        productoCodigoInterno: j['producto_codigo_interno'] as String?,
        codigoBarra: j['codigo_barra'] as String? ?? '',
        tipoCodigo: j['tipo_codigo'] as String? ?? 'EAN13',
        principal: _asBool(j['principal']),
        activo: j['activo'] == null ? true : _asBool(j['activo']),
        observaciones: j['observaciones'] as String?,
        rowVersion: _asRowVersion(j),
      );

  final int idCodigoBarra;
  final int idProducto;
  final String? productoNombre;
  final String? productoCodigoInterno;
  final String codigoBarra;
  final String tipoCodigo;
  final bool principal;
  final bool activo;
  final String? observaciones;
  final int rowVersion;
}

const tiposZona = <String>[
  'RECEPCION',
  'PICKING',
  'ARMADO',
  'DEVOLUCION',
  'MERMA',
  'GENERAL',
  'PRODUCCION',
];

/// `GET/POST/PATCH /ubicaciones/zonas` (ver `ubicacion_zona.py`).
class ZonaCreador {
  ZonaCreador({
    required this.idZona,
    required this.idAlmacen,
    required this.nombre,
    this.codigo,
    required this.tipo,
    required this.activo,
    required this.rowVersion,
  });

  factory ZonaCreador.fromJson(Map<String, dynamic> j) => ZonaCreador(
    idZona: j['id_zona'] as int,
    idAlmacen: j['id_almacen'] as int,
    nombre: j['nombre'] as String? ?? '',
    codigo: j['codigo'] as String?,
    tipo: j['tipo'] as String? ?? 'GENERAL',
    activo: j['activo'] == null ? true : _asBool(j['activo']),
    rowVersion: _asRowVersion(j),
  );

  final int idZona;
  final int idAlmacen;
  final String nombre;
  final String? codigo;
  final String tipo;
  final bool activo;
  final int rowVersion;
}

const tiposUbicacion = <String>[
  'ALMACENAJE',
  'ARMADO',
  'MERMA',
  'RECEPCION',
  'DEVOLUCION',
  'VIRTUAL',
  'REACOMODO',
];

/// `GET/POST/PATCH /ubicaciones` (ver `ubicacion_ubicacion.py`). El nivel
/// (`RACK`/`POSICION`) no lo pide el formulario simple — se infiere de si
/// tiene ubicación padre o no (ver `UbicacionesTab`).
class UbicacionCreador {
  UbicacionCreador({
    required this.idUbicacion,
    required this.idZona,
    this.zonaNombre,
    required this.nombre,
    required this.codigo,
    required this.tipoUbicacion,
    required this.nivel,
    this.idUbicacionPadre,
    this.ubicacionPadreNombre,
    required this.activo,
    required this.rowVersion,
  });

  factory UbicacionCreador.fromJson(Map<String, dynamic> j) => UbicacionCreador(
    idUbicacion: j['id_ubicacion'] as int,
    idZona: j['id_zona'] as int,
    zonaNombre: j['zona_nombre'] as String?,
    nombre: j['nombre'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    tipoUbicacion: j['tipo_ubicacion'] as String? ?? 'ALMACENAJE',
    nivel: j['nivel'] as String? ?? 'POSICION',
    idUbicacionPadre: j['id_ubicacion_padre'] as int?,
    ubicacionPadreNombre: j['ubicacion_padre_nombre'] as String?,
    activo: j['activo'] == null ? true : _asBool(j['activo']),
    rowVersion: _asRowVersion(j),
  );

  final int idUbicacion;
  final int idZona;
  final String? zonaNombre;
  final String nombre;
  final String codigo;
  final String tipoUbicacion;
  final String nivel;
  final int? idUbicacionPadre;
  final String? ubicacionPadreNombre;
  final bool activo;
  final int rowVersion;
}
