import 'package:dio/dio.dart';

import '../domain/stock_models.dart';

/// Llamadas a `/productos` (ver `productos_rout.py` /
/// `productos_crear_ver.py`, módulo `ajustes/deposito/productos/producto`).
class ProductosApi {
  ProductosApi(this._dio);

  final Dio _dio;

  /// `manejaStock`: `true` por defecto (comportamiento histórico — la
  /// mayoría de los callers arman flujos de stock físico: recepción,
  /// ajuste, proveedor). Pasar `null` para no filtrar (lo necesita el
  /// buscador genérico, que también tiene que traer servicios, que nunca
  /// manejan stock).
  Future<List<ProductoSimple>> buscar({
    String? q,
    int? idProveedorCabecera,
    bool? manejaStock = true,
    bool? esComercial,
    int limit = 30,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'id_proveedor_cabecera': ?idProveedorCabecera,
        'maneja_stock': ?manejaStock,
        'es_comercial': ?esComercial,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProductoSimple.fromJson).toList();
  }

  Future<ProductoDetalle> detalle(int idProducto) async {
    final res = await _dio.get<Map<String, dynamic>>('/productos/$idProducto');
    final producto = res.data!['producto'] as Map<String, dynamic>;
    return ProductoDetalle.fromJson(producto);
  }

  /// Incluye `almacenaje` (flags requiere_lote/control_vencimiento/
  /// requiere_fecha_faena) — lo necesita el módulo de Recepción para saber
  /// qué campos pedir al recibir el producto.
  Future<(ProductoDetalle, ProductoAlmacenaje)> detalleConAlmacenaje(
    int idProducto,
  ) async {
    final res = await _dio.get<Map<String, dynamic>>('/productos/$idProducto');
    final producto = res.data!['producto'] as Map<String, dynamic>;
    final almacenaje = res.data!['almacenaje'] as Map<String, dynamic>;
    return (
      ProductoDetalle.fromJson(producto),
      ProductoAlmacenaje.fromJson(almacenaje),
    );
  }

  /// `GET /productos/codigos-barra/buscar/{codigo}` (ver
  /// `producto_codigo_barra_rout.py`) — resuelve un código escaneado a su
  /// producto. Lanza un 404 con `detail: "Código de barras no encontrado"`
  /// si no hay ninguno registrado con ese código (el caller lo muestra
  /// directo con `describeError`, no hace falta traducirlo).
  Future<ProductoSimple> buscarPorCodigoBarra(String codigoBarra) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos/codigos-barra/buscar/$codigoBarra',
    );
    final j = res.data!;
    return ProductoSimple(
      idProducto: j['id_producto'] as int,
      codigoInterno: j['producto_codigo_interno'] as String? ?? '',
      nombre: j['producto_nombre'] as String? ?? '',
      unidadSimbolo: '',
    );
  }
}
