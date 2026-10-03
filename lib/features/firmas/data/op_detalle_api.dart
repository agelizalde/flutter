import 'package:dio/dio.dart';

import '../domain/op_detalle.dart';

/// Llamadas a `/compras/op/*` (ver `op_rout.py`) que consume la pantalla de
/// detalle de Firmas al resolver una solicitud de tipo `OP` — requieren el
/// permiso `op.ver` (distinto de `firmas.ver`), mismo criterio que
/// `OcDetalleApi` para `oc.ver`.
class OpDetalleApi {
  OpDetalleApi(this._dio);

  final Dio _dio;

  Future<OpDetalle> getOp(int idOrdenPago) async {
    final resultados = await Future.wait([
      _dio.get<Map<String, dynamic>>('/compras/op/$idOrdenPago'),
      _dio.get<Map<String, dynamic>>('/compras/op/$idOrdenPago/resumen-cantidades'),
    ]);

    final header = resultados[0].data!['data']['header'] as Map<String, dynamic>;
    final items = (resultados[1].data!['items'] as List? ?? []).cast<Map<String, dynamic>>();

    return OpDetalle(
      header: OpDetalleHeader.fromJson(header),
      items: items.map(OpDetalleItem.fromJson).toList(),
    );
  }
}
