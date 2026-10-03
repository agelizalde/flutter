import '../../../core/utils/parsing.dart';

/// Detalle de una orden de compra para la pantalla de Firmas — espejo
/// parcial de `header`+`items` de `GET /compras/oc/{id}` (ver
/// `oc_get_full`/`_get_oc_full` en `oc_ver.py`/`oc_crear_manual.py`). Solo
/// trae los campos que se muestran acá, no el documento completo (que
/// también incluye comentarios/historial/aprobaciones, pedidos con
/// `incluir_*=false` porque esta pantalla no los usa).
class OcDetalle {
  OcDetalle({required this.header, required this.items});

  factory OcDetalle.fromJson(Map<String, dynamic> j) => OcDetalle(
    header: OcDetalleHeader.fromJson(j['header'] as Map<String, dynamic>),
    items: (j['items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(OcDetalleItem.fromJson)
        .toList(),
  );

  final OcDetalleHeader header;
  final List<OcDetalleItem> items;
}

class OcDetalleHeader {
  OcDetalleHeader({
    required this.idOc,
    this.codigo,
    required this.proveedorNombre,
    required this.monedaSimbolo,
    required this.fechaEmision,
    this.solicitanteUsername,
    this.solicitanteNombre,
    required this.totalNetoImporte,
  });

  factory OcDetalleHeader.fromJson(Map<String, dynamic> j) => OcDetalleHeader(
    idOc: j['id_oc'] as int,
    codigo: j['codigo'] as String?,
    proveedorNombre: j['proveedor_nombre'] as String? ?? '—',
    monedaSimbolo: j['moneda_simbolo'] as String? ?? 'Gs.',
    fechaEmision: parseDateOrNull(j['fecha_emision']) ?? DateTime.now(),
    solicitanteUsername: j['solicitante_username'] as String?,
    solicitanteNombre: j['solicitante_nombre'] as String?,
    totalNetoImporte: parseDouble(j['total_neto_importe']),
  );

  final int idOc;
  final String? codigo;
  final String proveedorNombre;
  final String monedaSimbolo;
  final DateTime fechaEmision;
  final String? solicitanteUsername;
  final String? solicitanteNombre;
  final double totalNetoImporte;

  String get solicitanteDisplay {
    final nombre = solicitanteNombre?.trim();
    if (nombre != null && nombre.isNotEmpty) return nombre;
    return solicitanteUsername ?? '—';
  }
}

class OcDetalleItem {
  OcDetalleItem({
    required this.idOcItem,
    required this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.cantidadSolicitada,
    required this.precioUnitario,
    required this.totalLinea,
  });

  factory OcDetalleItem.fromJson(Map<String, dynamic> j) => OcDetalleItem(
    idOcItem: j['id_oc_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '—',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    cantidadSolicitada: parseDouble(j['cantidad_solicitada']),
    precioUnitario: parseDouble(j['precio_unitario']),
    totalLinea: parseDouble(j['total_linea']),
  );

  final int idOcItem;
  final int idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final double cantidadSolicitada;
  final double precioUnitario;
  final double totalLinea;
}

/// Una fila de `GET /compras/oc/ultimas-compras` — usada en el popup de
/// "últimos precios de compra" al tocar un ítem (ver
/// `oc_ultimas_compras_producto` en `oc_ver.py`; no filtra por proveedor a
/// propósito, es historial de precios del producto en cualquier proveedor).
class OcUltimaCompra {
  OcUltimaCompra({
    required this.idOc,
    this.codigo,
    required this.fechaEmision,
    required this.precioUnitario,
    required this.proveedorNombre,
    required this.monedaSimbolo,
  });

  factory OcUltimaCompra.fromJson(Map<String, dynamic> j) => OcUltimaCompra(
    idOc: j['id_oc'] as int,
    codigo: j['codigo'] as String?,
    fechaEmision: parseDateOrNull(j['fecha_emision']) ?? DateTime.now(),
    precioUnitario: parseDouble(j['precio_unitario']),
    proveedorNombre: j['proveedor_nombre'] as String? ?? '—',
    monedaSimbolo: j['moneda_simbolo'] as String? ?? 'Gs.',
  );

  final int idOc;
  final String? codigo;
  final DateTime fechaEmision;
  final double precioUnitario;
  final String proveedorNombre;
  final String monedaSimbolo;
}
