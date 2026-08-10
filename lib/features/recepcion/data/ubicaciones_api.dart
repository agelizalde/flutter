import 'package:dio/dio.dart';

import '../domain/recepcion_models.dart';

/// Llamadas a `/ubicaciones` (ver `ubicacion_rout.py`). Pagina con
/// `page`/`page_size`.
class UbicacionesApi {
  UbicacionesApi(this._dio);

  final Dio _dio;

  Future<List<UbicacionSimple>> listarDeRecepcion(int idAlmacen) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ubicaciones',
      queryParameters: {
        'id_almacen': idAlmacen,
        'tipo_ubicacion': 'RECEPCION',
        'activo': true,
        'page': 1,
        'page_size': 200,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(UbicacionSimple.fromJson).toList();
  }

  /// Búsqueda genérica por nombre/código, sin filtrar por tipo — usada por
  /// Traslados para elegir cualquier ubicación destino (no solo RECEPCION).
  Future<List<UbicacionSimple>> buscar({required int idAlmacen, String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ubicaciones',
      queryParameters: {
        'id_almacen': idAlmacen,
        if (q != null && q.isNotEmpty) 'q': q,
        'activo': true,
        'page': 1,
        'page_size': 50,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(UbicacionSimple.fromJson).toList();
  }
}
