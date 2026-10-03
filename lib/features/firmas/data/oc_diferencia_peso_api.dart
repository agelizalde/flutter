import 'package:dio/dio.dart';

import '../domain/oc_diferencia_peso_detalle.dart';

/// Llamada a `/recepciones/diferencia-peso/{id}` (ver
/// `recepcion_oc_actualizacion_rout.py`) que consume la pantalla de detalle
/// de Firmas al resolver una solicitud `OC_DIFERENCIA_PESO` — requiere el
/// mismo `firmas.ver` que el detalle genérico, a diferencia de
/// [OcDetalleApi] que pide `oc.ver`.
class OcDiferenciaPesoApi {
  OcDiferenciaPesoApi(this._dio);

  final Dio _dio;

  Future<OcDiferenciaPesoDetalle> getDiferenciaPeso(int idDiferencia) async {
    final res = await _dio.get<Map<String, dynamic>>('/recepciones/diferencia-peso/$idDiferencia');
    return OcDiferenciaPesoDetalle.fromJson(res.data!);
  }
}
