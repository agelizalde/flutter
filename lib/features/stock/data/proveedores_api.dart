import 'package:dio/dio.dart';

import '../domain/stock_models.dart';

/// Llamadas a `/proveedores` (ver `proveedores_rout.py`). A diferencia de
/// `/stock/*` y `/productos`, este módulo pagina con `page`/`page_size` en
/// vez de `limit`/`offset`.
class ProveedoresApi {
  ProveedoresApi(this._dio);

  final Dio _dio;

  Future<List<ProveedorSimple>> buscar({String? q, int pageSize = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/proveedores',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'page': 1,
        'page_size': pageSize,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProveedorSimple.fromJson).toList();
  }
}
