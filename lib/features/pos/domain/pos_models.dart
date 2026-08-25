/// `GET /pos/mi-punto-venta` (ver `pos_venta_service.py::mi_punto_venta_get`)
/// — el punto de venta asignado al usuario logueado. 403 si no tiene
/// ninguno activo (ver `PosRepository.miPuntoVenta` / `PosScreen`).
class PuntoVentaActual {
  PuntoVentaActual({
    required this.idPuntoVenta,
    required this.codigo,
    required this.nombre,
    required this.almacenNombre,
    required this.empresaNombre,
  });

  factory PuntoVentaActual.fromJson(Map<String, dynamic> j) => PuntoVentaActual(
    idPuntoVenta: j['id_punto_venta'] as int,
    codigo: j['codigo'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    almacenNombre: j['almacen_nombre'] as String? ?? '',
    empresaNombre: j['empresa_nombre'] as String? ?? '',
  );

  final int idPuntoVenta;
  final String codigo;
  final String nombre;
  final String almacenNombre;
  final String empresaNombre;
}

/// Fila de `GET /productos?vendible=true` — modelo propio (no
/// `ProductoSimple` de `stock/domain/stock_models.dart`) porque el carrito
/// de POS necesita `idUnidadBase` para armar el ítem de la venta
/// (`POST /pos/ventas` pide `id_unidad`), y `ProductoSimple` no lo trae.
/// Mismo criterio que `ProductoCompraSimple` en `oc_simple/domain` (ese
/// necesitaba el precio máximo, este necesita la unidad).
class ProductoPosSimple {
  ProductoPosSimple({
    required this.idProducto,
    required this.codigoInterno,
    required this.nombre,
    required this.idUnidadBase,
    required this.unidadSimbolo,
    required this.unidadPesable,
  });

  factory ProductoPosSimple.fromJson(Map<String, dynamic> j) => ProductoPosSimple(
    idProducto: j['id_producto'] as int,
    codigoInterno: j['codigo_interno'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    idUnidadBase: j['id_unidad_base'] as int,
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    unidadPesable: j['unidad_pesable'] == 1 || j['unidad_pesable'] == true,
  );

  final int idProducto;
  final String codigoInterno;
  final String nombre;
  final int idUnidadBase;
  final String unidadSimbolo;

  /// `unidades.pesable` — mismo campo que ya usa picking/recepción/stock
  /// (ver `formatCantidad` en `core/utils/parsing.dart`): solo estos
  /// productos (ej. carne por kg) aceptan cantidad con parte decimal
  /// ingresada a mano, a diferencia de un paquete de arroz que se suma de a
  /// unidades enteras con el stepper.
  final bool unidadPesable;
}

/// Línea del carrito — 100% local hasta "Confirmar venta". Sin precio a
/// propósito (mismo criterio que la web: es un punto de venta interno, el
/// precio lo completa Administración después).
class PosCartItem {
  const PosCartItem({required this.producto, required this.cantidad});

  final ProductoPosSimple producto;
  final double cantidad;

  PosCartItem copyWith({double? cantidad}) =>
      PosCartItem(producto: producto, cantidad: cantidad ?? this.cantidad);
}

/// Ítem de la respuesta de `POST /pos/ventas` — cómo se resolvió cada
/// producto (ver `pos_venta_service.py::crear_venta_pos`).
class VentaPosItemResultado {
  VentaPosItemResultado({
    required this.idPedidoSubpedidoItem,
    required this.productoNombre,
    required this.cantidad,
    required this.resultado,
  });

  factory VentaPosItemResultado.fromJson(Map<String, dynamic> j) => VentaPosItemResultado(
    idPedidoSubpedidoItem: j['id_pedido_subpedido_item'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    cantidad: j['cantidad'] as String? ?? '0',
    resultado: j['resultado'] as String? ?? 'servicio',
  );

  final int idPedidoSubpedidoItem;
  final String productoNombre;
  final String cantidad;

  /// 'stock_descontado' | 'compra_externa' | 'servicio'
  final String resultado;
}

/// `data` de `POST /pos/ventas` completa.
class VentaPosResultado {
  VentaPosResultado({
    required this.idPedido,
    required this.codigoPedido,
    required this.idPedidoSubpedido,
    required this.estado,
    required this.items,
  });

  factory VentaPosResultado.fromJson(Map<String, dynamic> j) => VentaPosResultado(
    idPedido: j['id_pedido'] as int,
    codigoPedido: j['codigo_pedido'] as String? ?? '',
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    estado: j['estado'] as String? ?? '',
    items: (j['items'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(VentaPosItemResultado.fromJson)
        .toList(),
  );

  final int idPedido;
  final String codigoPedido;
  final int idPedidoSubpedido;
  final String estado;
  final List<VentaPosItemResultado> items;
}
