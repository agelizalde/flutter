import 'package:dio/dio.dart';

import '../domain/oc_detalle.dart';

/// Llamadas a `/compras/oc/*` (ver `oc_rout.py`) que consume la pantalla de
/// detalle de Firmas al resolver una solicitud de tipo `OC` — requieren el
/// permiso `oc.ver` (distinto de `firmas.ver`), ver [OcDetalle].
class OcDetalleApi {
  OcDetalleApi(this._dio);

  final Dio _dio;

  Future<OcDetalle> getOc(int idOc) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/compras/oc/$idOc',
      queryParameters: {
        'incluir_comentarios': false,
        'incluir_historial': false,
        'incluir_aprobaciones': false,
      },
    );
    return OcDetalle.fromJson(res.data!['data'] as Map<String, dynamic>);
  }

  Future<List<OcUltimaCompra>> ultimasCompras(int idProducto, {int limit = 4}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/compras/oc/ultimas-compras',
      queryParameters: {'id_producto': idProducto, 'limit': limit},
    );
    return (res.data!['items'] as List? ?? []).cast<Map<String, dynamic>>().map(OcUltimaCompra.fromJson).toList();
  }
}
