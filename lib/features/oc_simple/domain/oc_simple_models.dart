import '../../../core/utils/parsing.dart';

/// Fila de `GET /productos` filtrada por `comprable=true&compra_simple_habilitada=true`
/// (ver `productos_crear_ver.py::productos_list`). Modelo propio, separado de
/// `ProductoSimple` (`stock/domain/stock_models.dart`), porque ese no trae
/// `precio_maximo_compra_simple` — el tope que valida el carrito de OC simple.
class ProductoCompraSimple {
  ProductoCompraSimple({
    required this.idProducto,
    required this.codigoInterno,
    required this.nombre,
    required this.unidadSimbolo,
    this.precioMaximoCompraSimple,
  });

  factory ProductoCompraSimple.fromJson(Map<String, dynamic> j) => ProductoCompraSimple(
    idProducto: j['id_producto'] as int,
    codigoInterno: j['codigo_interno'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    precioMaximoCompraSimple: j['precio_maximo_compra_simple'] == null
        ? null
        : double.tryParse(j['precio_maximo_compra_simple'].toString()),
  );

  final int idProducto;
  final String codigoInterno;
  final String nombre;
  final String unidadSimbolo;
  final double? precioMaximoCompraSimple;
}

/// Línea del carrito, 100% local hasta que se toca "Generar OC" (recién ahí
/// se manda todo junto a `POST /compras/oc/simple`, ver `OcSimpleApi.crear`).
class OcSimpleCartItem {
  const OcSimpleCartItem({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
  });

  final ProductoCompraSimple producto;
  final double cantidad;
  final double precioUnitario;

  double get subtotal => cantidad * precioUnitario;

  /// `null` = sin error. Valida cantidad > 0, precio >= 0 y el tope de
  /// `precioMaximoCompraSimple` (misma regla que aplica el backend en
  /// `oc_crear_simple.py::_insert_oc_item_simple`, acá solo para feedback
  /// inmediato antes de mandar el request).
  String? get error {
    if (cantidad <= 0) return 'Cantidad debe ser mayor a 0';
    if (precioUnitario < 0) return 'Precio inválido';
    final max = producto.precioMaximoCompraSimple;
    if (max != null && precioUnitario > max) {
      return 'No puede superar el máximo (${formatGs(max)})';
    }
    return null;
  }

  OcSimpleCartItem copyWith({double? cantidad, double? precioUnitario}) {
    return OcSimpleCartItem(
      producto: producto,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
    );
  }
}

/// `data` de la respuesta de `POST /compras/oc/simple` (ver
/// `oc_crear_simple.py::oc_simple_crear` / `_get_oc_full`) — solo lo que
/// necesita mostrar la pantalla de confirmación (no hay pantalla de detalle
/// de OC en esta app, a diferencia de la web).
class OcSimpleResultado {
  OcSimpleResultado({
    required this.idOc,
    required this.codigo,
    required this.estado,
  });

  factory OcSimpleResultado.fromJson(Map<String, dynamic> j) => OcSimpleResultado(
    idOc: j['id_oc'] as int,
    codigo: j['codigo'] as String? ?? '',
    estado: j['estado'] as String? ?? '',
  );

  final int idOc;
  final String codigo;
  final String estado;
}
