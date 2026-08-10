import '../../../core/utils/parsing.dart';

/// Categorías de motivo de un ajuste — enum fijo en el backend (no es una
/// tabla maestra, ver `ajuste_stock_service.py::MOTIVOS_CATEGORIA`).
const motivosAjusteStock = <(String value, String label)>[
  ('CONTEO_FISICO', 'Conteo físico'),
  ('CONTEO_RUTINARIO', 'Conteo rutinario'),
  ('CONSUMO_INTERNO', 'Consumo interno'),
  ('ROTURA', 'Rotura'),
  ('VENCIMIENTO', 'Vencimiento'),
  ('AJUSTE_INICIAL', 'Ajuste inicial'),
  ('ERROR_SISTEMA', 'Corrección de error'),
  ('OTRO', 'Otro'),
];

/// Motivos que ofrece "Nuevo ajuste" (`NuevoAjusteScreen`) — acotado a estos
/// 2 (2026-07-31): Conteo físico reajusta el stock (suma o resta) contra lo
/// contado a ciegas; Vencimiento solo descuenta, del lote que realmente
/// venció (ver CRITERIO_RESTAR_VENCIMIENTO_MAS_CERCANO en el backend). El
/// resto de `motivosAjusteStock` sigue existiendo para labels de ajustes ya
/// creados con otro motivo (ej. desde una solicitud) y para el historial.
const motivosNuevoAjuste = <(String value, String label)>[
  ('CONTEO_FISICO', 'Conteo físico'),
  ('VENCIMIENTO', 'Vencimiento'),
];

/// Causas del atajo "Merma" del inicio (`MermaRapidaScreen`) — a diferencia
/// de "Nuevo ajuste", este flujo no pasa por conteo de ubicación: solo
/// producto + cantidad + causa (ver `POST /ajuste-stock/merma-rapida`).
const motivosMermaRapida = <(String value, String label)>[
  ('ROTURA', 'Merma'),
  ('CONSUMO_INTERNO', 'Uso interno'),
];

String labelMotivoAjuste(String value) =>
    motivosAjusteStock.firstWhere((m) => m.$1 == value, orElse: () => (value, value)).$2;

/// Header de `ajustes_stock` (ver `ajuste_stock_service.py::_get_ajuste_header`).
class AjusteStock {
  AjusteStock({
    required this.idAjusteStock,
    required this.codigo,
    required this.modoAjuste,
    required this.motivoCategoria,
    required this.estado,
    required this.idAlmacen,
    required this.almacenNombre,
    required this.idZona,
    required this.idUbicacion,
    required this.ubicacionNombre,
    required this.ubicacionCodigo,
    this.fechaConteo,
    this.fechaAplicacion,
    this.observaciones,
    this.motivoAnulacion,
    required this.totalItems,
    required this.totalDiferencias,
    required this.totalSobrante,
    required this.totalFaltante,
    required this.impactoValorizadoTotal,
    this.usuarioConteoUsername,
    this.usuarioAplicacionUsername,
    required this.rowVersion,
  });

  factory AjusteStock.fromJson(Map<String, dynamic> j) => AjusteStock(
    idAjusteStock: j['id_ajuste_stock'] as int,
    codigo: j['codigo'] as String? ?? '',
    modoAjuste: j['modo_ajuste'] as String? ?? 'POR_LOTE',
    motivoCategoria: j['motivo_categoria'] as String? ?? 'OTRO',
    estado: j['estado'] as String? ?? 'BORRADOR',
    idAlmacen: j['id_almacen'] as int,
    almacenNombre: j['almacen_nombre'] as String? ?? '',
    idZona: j['id_zona'] as int,
    idUbicacion: j['id_ubicacion'] as int,
    ubicacionNombre: j['ubicacion_nombre'] as String? ?? '',
    ubicacionCodigo: j['ubicacion_codigo'] as String? ?? '',
    fechaConteo: parseDateOrNull(j['fecha_conteo']),
    fechaAplicacion: parseDateOrNull(j['fecha_aplicacion']),
    observaciones: j['observaciones'] as String?,
    motivoAnulacion: j['motivo_anulacion'] as String?,
    totalItems: j['total_items'] as int? ?? 0,
    totalDiferencias: j['total_diferencias'] as int? ?? 0,
    totalSobrante: parseDouble(j['total_sobrante']),
    totalFaltante: parseDouble(j['total_faltante']),
    impactoValorizadoTotal: parseDouble(j['impacto_valorizado_total']),
    usuarioConteoUsername: j['usuario_conteo_username'] as String?,
    usuarioAplicacionUsername: j['usuario_aplicacion_username'] as String?,
    rowVersion: j['row_version'] as int,
  );

  final int idAjusteStock;
  final String codigo;

  /// 'POR_LOTE' | 'POR_PRODUCTO'
  final String modoAjuste;
  final String motivoCategoria;

  /// 'BORRADOR' | 'CONFIRMADO' | 'APLICADO' | 'ANULADO'
  final String estado;
  final int idAlmacen;
  final String almacenNombre;
  final int idZona;
  final int idUbicacion;
  final String ubicacionNombre;
  final String ubicacionCodigo;
  final DateTime? fechaConteo;
  final DateTime? fechaAplicacion;
  final String? observaciones;
  final String? motivoAnulacion;
  final int totalItems;
  final int totalDiferencias;
  final double totalSobrante;
  final double totalFaltante;
  final double impactoValorizadoTotal;
  final String? usuarioConteoUsername;
  final String? usuarioAplicacionUsername;
  final int rowVersion;

  /// Mismas reglas que `ajuste_stock_ver.py::_build_estado_flags` —
  /// se recalculan acá en vez de depender de que el backend las mande
  /// (las respuestas de crear/confirmar/aplicar/anular no las incluyen,
  /// solo el GET por id).
  bool get puedeEditar => estado == 'BORRADOR';
  bool get puedeConfirmar => estado == 'BORRADOR';
  bool get puedeAplicar => estado == 'CONFIRMADO';
  bool get puedeAnular => estado == 'BORRADOR' || estado == 'CONFIRMADO';
}

/// Ítem de un ajuste (ver `ajuste_stock_service.py::_get_ajuste_items`).
class AjusteStockItem {
  AjusteStockItem({
    required this.idAjusteStockItem,
    required this.idProducto,
    required this.productoNombre,
    this.idLote,
    this.loteInterno,
    this.loteProveedor,
    this.fechaVencimiento,
    required this.idUnidadMedida,
    required this.unidadSimbolo,
    required this.cantidadSistema,
    required this.cantidadContada,
    required this.cantidadDiferencia,
    this.observaciones,
    this.esLoteNuevo = false,
    this.loteNuevoProveedor,
    this.loteNuevoVencimiento,
    this.loteNuevoFaenado,
  });

  factory AjusteStockItem.fromJson(Map<String, dynamic> j) => AjusteStockItem(
    idAjusteStockItem: j['id_ajuste_stock_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    idLote: j['id_lote'] as int?,
    loteInterno: j['lote_interno'] as String?,
    loteProveedor: j['lote_proveedor'] as String?,
    fechaVencimiento: parseDateOrNull(j['fecha_vencimiento']),
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    cantidadSistema: parseDouble(j['cantidad_sistema']),
    cantidadContada: parseDouble(j['cantidad_contada']),
    cantidadDiferencia: parseDouble(j['cantidad_diferencia']),
    observaciones: j['observaciones'] as String?,
    esLoteNuevo: j['es_lote_nuevo'] as bool? ?? false,
    loteNuevoProveedor: j['lote_nuevo_proveedor'] as String?,
    loteNuevoVencimiento: parseDateOrNull(j['lote_nuevo_vencimiento']),
    loteNuevoFaenado: parseDateOrNull(j['lote_nuevo_faenado']),
  );

  final int idAjusteStockItem;
  final int idProducto;
  final String productoNombre;
  final int? idLote;
  final String? loteInterno;
  final String? loteProveedor;
  final DateTime? fechaVencimiento;
  final int idUnidadMedida;
  final String unidadSimbolo;
  final double cantidadSistema;
  final double cantidadContada;
  final double cantidadDiferencia;
  final String? observaciones;

  /// Producto sin stock previo en la ubicación: no había lote todavía
  /// cuando se creó el ajuste (`idLote == null`) — los campos `loteNuevo*`
  /// son lo que el usuario cargó y quedan vigentes hasta que se aplica el
  /// ajuste, momento en el que el backend crea el lote real y `idLote`
  /// pasa a apuntar a él.
  final bool esLoteNuevo;
  final String? loteNuevoProveedor;
  final DateTime? loteNuevoVencimiento;
  final DateTime? loteNuevoFaenado;

  bool get tieneDiferencia => cantidadDiferencia != 0;
  bool get esSobrante => cantidadDiferencia > 0;
  bool get esFaltante => cantidadDiferencia < 0;
}

class AjusteStockDetalle {
  AjusteStockDetalle({required this.ajuste, required this.items});

  final AjusteStock ajuste;
  final List<AjusteStockItem> items;
}

/// Ítem a enviar en `POST /ajuste-stock` (ver
/// `ajuste_stock_service.py::AjusteStockItemCreateIn`). `cantidadSistema` no
/// se manda — el backend la resuelve solo contra `stock_existencias`.
class AjusteStockItemCreateIn {
  AjusteStockItemCreateIn({
    required this.idProducto,
    this.idLote,
    required this.idUnidadMedida,
    required this.idUbicacion,
    required this.cantidadContada,
    this.observaciones,
    this.esLoteNuevo = false,
    this.loteProveedor,
    this.fechaVencimiento,
    this.fechaFaenado,
  });

  final int idProducto;
  final int? idLote;
  final int idUnidadMedida;
  final int idUbicacion;
  final double cantidadContada;
  final String? observaciones;

  /// Campos de lote nuevo — solo cuando `esLoteNuevo=true` (producto sin stock
  /// previo en la ubicación). El backend crea el lote al aplicar el ajuste.
  final bool esLoteNuevo;
  final String? loteProveedor;
  final DateTime? fechaVencimiento;
  final DateTime? fechaFaenado;

  Map<String, dynamic> toJson() => {
    'id_producto': idProducto,
    'id_lote': ?idLote,
    'id_unidad_medida': idUnidadMedida,
    'id_ubicacion': idUbicacion,
    'cantidad_contada': cantidadContada,
    'observaciones': ?observaciones,
    if (esLoteNuevo) 'es_lote_nuevo': true,
    if (loteProveedor != null) 'lote_proveedor': loteProveedor,
    if (fechaVencimiento != null)
      'fecha_vencimiento': fechaVencimiento!.toIso8601String().substring(0, 10),
    if (fechaFaenado != null)
      'fecha_faenado': fechaFaenado!.toIso8601String().substring(0, 10),
  };
}

/// Datos temporales de un producto nuevo a agregar al conteo de ajuste.
/// Se construye en `AgregarItemAjusteScreen` y se convierte a
/// `AjusteStockItemCreateIn` con `esLoteNuevo=true` al crear el ajuste.
class AjusteItemNuevo {
  AjusteItemNuevo({
    required this.idProducto,
    required this.productoNombre,
    required this.idUnidadMedida,
    required this.unidadSimbolo,
    required this.cantidadInicial,
    this.loteProveedor,
    this.fechaVencimiento,
    this.fechaFaenado,
  });

  final int idProducto;
  final String productoNombre;
  final int idUnidadMedida;
  final String unidadSimbolo;
  final double cantidadInicial;
  final String? loteProveedor;
  final DateTime? fechaVencimiento;
  final DateTime? fechaFaenado;
}
