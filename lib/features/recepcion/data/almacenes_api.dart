import 'package:dio/dio.dart';

import '../domain/recepcion_models.dart';

/// Llamadas a `/almacenes` (ver `ubicacion_almacen_rout.py`). Pagina con
/// `page`/`page_size` (no `limit`/`offset`, igual que `/proveedores`).
class AlmacenesApi {
  AlmacenesApi(this._dio);

  final Dio _dio;

  Future<List<AlmacenSimple>> listar() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/almacenes',
      queryParameters: {'activo': true, 'page': 1, 'page_size': 200},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(AlmacenSimple.fromJson).toList();
  }
}
