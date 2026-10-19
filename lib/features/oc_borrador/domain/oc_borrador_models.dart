import '../../../core/utils/parsing.dart';

/// Fila de `GET /productos` filtrada por `comprable=true` (y opcionalmente
/// `id_proveedor_cabecera`, ver `productos_crear_ver.py::productos_list`).
/// Modelo propio porque acá no hace falta el tope de OC simple
/// (`ProductoCompraSimple`) pero sí la unidad pesable y el proveedor base,
/// para mostrar si el producto es "de" el proveedor elegido.
class ProductoOcBorrador {
  ProductoOcBorrador({
    required this.idProducto,
    required this.codigoInterno,
    required this.nombre,
    required this.unidadSimbolo,
    required this.unidadPesable,
    this.marcaNombre,
    this.idProveedorCabecera,
    this.proveedorNombre,
  });

  factory ProductoOcBorrador.fromJson(Map<String, dynamic> j) => ProductoOcBorrador(
    idProducto: j['id_producto'] as int,
    codigoInterno: j['codigo_interno'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    unidadPesable: j['unidad_pesable'] == true || j['unidad_pesable'] == 1,
    marcaNombre: j['marca_nombre'] as String?,
    idProveedorCabecera: j['id_proveedor_cabecera'] as int?,
    proveedorNombre: j['proveedor_nombre'] as String?,
  );

  final int idProducto;
  final String codigoInterno;
  final String nombre;
  final String unidadSimbolo;
  final bool unidadPesable;
  final String? marcaNombre;
  final int? idProveedorCabecera;
  final String? proveedorNombre;
}

/// Línea de la OC, 100% local hasta que se toca "Crear OC" (recién ahí se
/// manda todo junto a `POST /compras/oc/borrador-app`). Sin precio: lo
/// completa el backend con el sugerido y Compras lo revisa desde la PC.
class OcBorradorItem {
  const OcBorradorItem({required this.producto, required this.cantidad});

  final ProductoOcBorrador producto;
  final double cantidad;

  String get cantidadTexto =>
      '${formatCantidad(cantidad, pesable: producto.unidadPesable)} ${producto.unidadSimbolo}'.trim();

  OcBorradorItem copyWith({double? cantidad}) =>
      OcBorradorItem(producto: producto, cantidad: cantidad ?? this.cantidad);
}

/// `data` de la respuesta de `POST /compras/oc/borrador-app` (ver
/// `oc_crear_borrador_app.py`) — solo lo que muestra el diálogo final.
class OcBorradorResultado {
  OcBorradorResultado({required this.idOc, required this.codigo, required this.estado});

  factory OcBorradorResultado.fromJson(Map<String, dynamic> j) => OcBorradorResultado(
    idOc: j['id_oc'] as int,
    codigo: j['codigo'] as String? ?? '',
    estado: j['estado'] as String? ?? '',
  );

  final int idOc;
  final String codigo;
  final String estado;
}
