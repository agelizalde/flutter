import 'package:dio/dio.dart';

import '../domain/solicitud_models.dart';

/// Llamadas a `/ajuste-stock/solicitudes/*` y `/usuarios/asignables` (ver
/// `ajuste_stock_solicitudes_rout.py`).
class AjusteStockSolicitudesApi {
  AjusteStockSolicitudesApi(this._dio);

  final Dio _dio;

  Future<SolicitudAjusteStock> crear({
    required int idAlmacen,
    required int idZona,
    required int idUbicacion,
    required int idUsuarioAsignado,
    required String motivoCategoria,
    String? observaciones,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/ajuste-stock/solicitudes',
      data: {
        'id_almacen': idAlmacen,
        'id_zona': idZona,
        'id_ubicacion': idUbicacion,
        'id_usuario_asignado': idUsuarioAsignado,
        'motivo_categoria': motivoCategoria,
        'observaciones': ?observaciones,
      },
    );
    return SolicitudAjusteStock.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  Future<List<SolicitudAjusteStock>> misTareas() async {
    final res = await _dio.get<Map<String, dynamic>>('/ajuste-stock/solicitudes/mis-tareas');
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(SolicitudAjusteStock.fromJson).toList();
  }

  Future<void> cancelar({
    required int idSolicitud,
    required int expectedVersion,
    String? motivo,
  }) {
    return _dio.post<void>(
      '/ajuste-stock/solicitudes/$idSolicitud/cancelar',
      data: {'expected_version': expectedVersion, 'motivo': ?motivo},
    );
  }

  Future<void> completar({required int idSolicitud, required int idAjusteStock}) {
    return _dio.post<void>(
      '/ajuste-stock/solicitudes/$idSolicitud/completar',
      data: {'id_ajuste_stock': idAjusteStock},
    );
  }

  Future<List<UsuarioAsignable>> usuariosAsignables({required int idAlmacen, String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/usuarios/asignables',
      queryParameters: {'id_almacen': idAlmacen, 'q': ?q},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(UsuarioAsignable.fromJson).toList();
  }
}
