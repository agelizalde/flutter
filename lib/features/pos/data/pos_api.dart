import 'package:dio/dio.dart';

import '../domain/pos_models.dart';

/// Llamadas propias del Punto de Venta (ver `pos_venta_service.py`,
/// prefix `/pos`). La búsqueda/alta de cliente y sucursal reusa
/// `PedidosRepository` (`clientes*`), no se duplica acá.
class PosApi {
  PosApi(this._dio);

  final Dio _dio;

  Future<PuntoVentaActual> miPuntoVenta() async {
    final res = await _dio.get<Map<String, dynamic>>('/pos/mi-punto-venta');
    return PuntoVentaActual.fromJson(res.data!);
  }

  Future<List<ProductoPosSimple>> buscarProductos({
    String? q,
    int limit = 15,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'vendible': true,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProductoPosSimple.fromJson).toList();
  }

  /// Resuelve un código escaneado a producto — dos pasos porque
  /// `/productos/codigos-barra/buscar/{codigo}` (ver
  /// `producto_codigo_barra_service.py::productos_codigos_barra_get_by_codigo`)
  /// no trae `id_unidad_base`/`unidad_simbolo` (solo id/nombre/código), así
  /// que hay que pedir el producto completo después. El carrito de POS
  /// siempre suma en la unidad base del producto, aunque el código
  /// escaneado esté asociado a otra unidad de venta — misma simplificación
  /// que el buscador por nombre.
  Future<ProductoPosSimple> buscarPorCodigoBarra(String codigoBarra) async {
    final resBarra = await _dio.get<Map<String, dynamic>>(
      '/productos/codigos-barra/buscar/$codigoBarra',
    );
    final idProducto = resBarra.data!['id_producto'] as int;
    final resProducto = await _dio.get<Map<String, dynamic>>('/productos/$idProducto');
    return ProductoPosSimple.fromJson(resProducto.data!['producto'] as Map<String, dynamic>);
  }

  Future<VentaPosResultado> crearVenta({
    required int idCliente,
    int? idClienteSucursal,
    String? observacion,
    required List<PosCartItem> items,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pos/ventas',
      data: {
        'id_cliente': idCliente,
        'id_cliente_sucursal': idClienteSucursal,
        'observacion': observacion,
        'items': items
            .map(
              (it) => {
                'id_producto': it.producto.idProducto,
                'id_unidad': it.producto.idUnidadBase,
                'cantidad': it.cantidad,
              },
            )
            .toList(),
      },
    );
    return VentaPosResultado.fromJson(res.data!);
  }
}
