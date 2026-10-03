import '../../../core/utils/parsing.dart';

/// Detalle de una orden de pago para la pantalla de Firmas — combina el
/// header de `GET /compras/op/{id}` (ver `op_get_full`/`_get_op_full` en
/// `op_ver.py`/`op_crear_editar.py`) con los ítems de
/// `GET /compras/op/{id}/resumen-cantidades` (ver
/// `calcular_resumen_cantidades_oc_items` en `op_estado.py`), armados en
/// [OpDetalleApi.getOp]. Solo trae los campos que se muestran acá (no
/// facturas/NC/gastos/historial, que esta pantalla no usa).
class OpDetalle {
  OpDetalle({required this.header, required this.items});

  final OpDetalleHeader header;
  final List<OpDetalleItem> items;
}

class OpDetalleHeader {
  OpDetalleHeader({
    required this.idOrdenPago,
    this.codigo,
    required this.tipoOp,
    required this.proveedorNombre,
    this.proveedorTipoPagoCompra,
    required this.fechaEmision,
    required this.montoTotal,
    required this.monedaSimbolo,
    required this.estado,
  });

  factory OpDetalleHeader.fromJson(Map<String, dynamic> j) => OpDetalleHeader(
    idOrdenPago: j['id_orden_pago'] as int,
    codigo: j['codigo'] as String?,
    tipoOp: j['tipo_op'] as String? ?? '',
    proveedorNombre: j['proveedor_nombre'] as String? ?? '—',
    proveedorTipoPagoCompra: j['proveedor_tipo_pago_compra'] as String?,
    fechaEmision: parseDateOrNull(j['fecha_emision']) ?? DateTime.now(),
    montoTotal: parseDouble(j['monto_total']),
    monedaSimbolo: j['moneda_simbolo'] as String? ?? 'Gs.',
    estado: j['estado'] as String? ?? '',
  );

  final int idOrdenPago;
  final String? codigo;
  final String tipoOp;
  final String proveedorNombre;
  final String? proveedorTipoPagoCompra;
  final DateTime fechaEmision;
  final double montoTotal;
  final String monedaSimbolo;
  final String estado;

  bool get esAnticipo => tipoOp == 'ANTICIPO';

  /// "Anticipo" si la OP es por anticipo; si no, el tipo de pago del
  /// proveedor (CONTADO/CREDITO) — pedido explícito del usuario para el
  /// header del detalle de Firmas, resaltado en rojo.
  String get formaPagoDisplay {
    if (esAnticipo) return 'Anticipo';
    switch (proveedorTipoPagoCompra) {
      case 'CREDITO':
        return 'Crédito';
      case 'CONTADO':
        return 'Contado';
      default:
        return proveedorTipoPagoCompra ?? '—';
    }
  }
}

class OpDetalleItem {
  OpDetalleItem({
    required this.idOcItem,
    required this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.cantidadRecibida,
    required this.precioUnitario,
  });

  factory OpDetalleItem.fromJson(Map<String, dynamic> j) => OpDetalleItem(
    idOcItem: j['id_oc_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '—',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    cantidadRecibida: parseDouble(j['cantidad_recibida']),
    precioUnitario: parseDouble(j['oc_precio_unitario']),
  );

  final int idOcItem;
  final int idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final double cantidadRecibida;
  final double precioUnitario;

  double get totalLinea => cantidadRecibida * precioUnitario;
}
