import 'package:dio/dio.dart';

import '../domain/stock_models.dart';

/// Llamadas a `/stock/*` (ver CONTEXTO.md raíz §3.8 y `stock_rout.py`).
class StockApi {
  StockApi(this._dio);

  final Dio _dio;

  Future<List<ProductoConStock>> porProducto({
    String? q,
    int limit = 30,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stock/por-producto',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'solo_con_stock': true,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProductoConStock.fromJson).toList();
  }

  Future<StockResumen> resumenProducto(int idProducto) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stock/por-producto/$idProducto/resumen',
    );
    final data = res.data!['data'] as Map<String, dynamic>;
    return StockResumen.fromJson(data);
  }

  Future<List<ExistenciaStock>> existencias({
    int? idProducto,
    int? idUbicacion,
    String? q,
    int limit = 100,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stock/existencias',
      queryParameters: {
        'id_producto': ?idProducto,
        'id_ubicacion': ?idUbicacion,
        if (q != null && q.isNotEmpty) 'q': q,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ExistenciaStock.fromJson).toList();
  }

  Future<List<UbicacionStock>> porUbicacion({String? q, int limit = 30}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/stock/por-ubicacion',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q, 'limit': limit},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(UbicacionStock.fromJson).toList();
  }
}
