import 'package:dio/dio.dart';

import '../domain/oc_borrador_models.dart';

/// Llamadas propias de "Nueva OC": búsqueda de productos comprables (libre
/// o solo los del proveedor) y alta de la OC en BORRADOR (ver
/// `oc_crear_borrador_app.py`, prefix `/compras/oc`). La búsqueda de
/// proveedor reusa `ProveedoresApi` de `stock/data/proveedores_api.dart`.
class OcBorradorApi {
  OcBorradorApi(this._dio);

  final Dio _dio;

  /// Con `idProveedor` filtra por proveedor base del producto
  /// (`productos.id_proveedor_cabecera`) y `q` puede venir vacío (lista
  /// todos los del proveedor); sin `idProveedor` busca en todo el catálogo.
  Future<List<ProductoOcBorrador>> buscarProductos({
    String? q,
    int? idProveedor,
    int limit = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'id_proveedor_cabecera': ?idProveedor,
        'comprable': true,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items
        // Los productos clase RRHH van por la OC de RRHH: el backend los
        // rechaza en una OC de Compras (`_assert_producto_ambito`).
        .where((j) => j['clase_producto'] != 'RRHH')
        .map(ProductoOcBorrador.fromJson)
        .toList();
  }

  Future<OcBorradorResultado> crear({
    required int idProveedor,
    required DateTime fechaEntrega,
    required List<OcBorradorItem> items,
    String? observacion,
  }) async {
    final f = fechaEntrega;
    final fecha =
        '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
    final res = await _dio.post<Map<String, dynamic>>(
      '/compras/oc/borrador-app',
      data: {
        'id_proveedor': idProveedor,
        'fecha_entrega_estimada': fecha,
        if (observacion != null && observacion.trim().isNotEmpty) 'observacion': observacion.trim(),
        'items': items
            .map((it) => {'id_producto': it.producto.idProducto, 'cantidad': it.cantidad})
            .toList(),
      },
    );
    return OcBorradorResultado.fromJson(res.data!['data'] as Map<String, dynamic>);
  }
}
