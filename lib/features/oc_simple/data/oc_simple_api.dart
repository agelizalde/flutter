import 'package:dio/dio.dart';

import '../domain/oc_simple_models.dart';

/// Llamadas propias de "OC simple": búsqueda de productos elegibles y alta
/// de la OC (ver `oc_crear_simple.py`, prefix `/compras/oc`). La búsqueda de
/// proveedor reusa `ProveedoresApi` de `stock/data/proveedores_api.dart`, no
/// se duplica acá.
class OcSimpleApi {
  OcSimpleApi(this._dio);

  final Dio _dio;

  Future<List<ProductoCompraSimple>> buscarProductos({
    String? q,
    int limit = 15,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'comprable': true,
        'compra_simple_habilitada': true,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProductoCompraSimple.fromJson).toList();
  }

  Future<OcSimpleResultado> crear({
    required int idProveedor,
    required List<OcSimpleCartItem> items,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/compras/oc/simple',
      data: {
        'id_proveedor': idProveedor,
        'items': items
            .map(
              (it) => {
                'id_producto': it.producto.idProducto,
                'cantidad': it.cantidad,
                'precio_unitario': it.precioUnitario,
              },
            )
            .toList(),
      },
    );
    return OcSimpleResultado.fromJson(res.data!['data'] as Map<String, dynamic>);
  }
}
