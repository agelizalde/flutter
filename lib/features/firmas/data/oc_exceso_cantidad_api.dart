import 'package:dio/dio.dart';

import '../domain/oc_exceso_cantidad_detalle.dart';

/// Llamada a `/recepciones/exceso-oc/{id}` (ver
/// `recepcion_oc_actualizacion_rout.py`) que consume la pantalla de detalle
/// de Firmas al resolver una solicitud `OC_EXCESO_CANTIDAD` — requiere el
/// mismo `firmas.ver` que el detalle genérico, a diferencia de
/// [OcDetalleApi] que pide `oc.ver`.
class OcExcesoCantidadApi {
  OcExcesoCantidadApi(this._dio);

  final Dio _dio;

  Future<OcExcesoCantidadDetalle> getExcesoCantidad(int idExceso) async {
    final res = await _dio.get<Map<String, dynamic>>('/recepciones/exceso-oc/$idExceso');
    return OcExcesoCantidadDetalle.fromJson(res.data!);
  }
}
