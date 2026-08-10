import 'package:dio/dio.dart';

import '../domain/picking_control_models.dart';

/// Payload de `POST /picking-control/sesion/{id}/item/{id}/revisar` (ver
/// `picking_control_service.py::RevisarItemIn`).
class RevisarItemIn {
  RevisarItemIn({
    required this.cantidadControlada,
    required this.resultado,
    this.motivosRechazo,
    this.observacion,
  });

  final double cantidadControlada;

  /// 'APROBADO' | 'RECHAZADO'
  final String resultado;

  /// CSV de `motivosControlValidos` — requerido si `resultado == 'RECHAZADO'`.
  final String? motivosRechazo;
  final String? observacion;

  Map<String, dynamic> toJson() => {
    'cantidad_controlada': cantidadControlada,
    'resultado': resultado,
    'motivos_rechazo': motivosRechazo,
    'observacion': observacion,
  };
}

/// Llamadas a `/picking-control/*` (ver `picking_control_rout.py`). Cubre
/// solo el flujo core: listar → detalle → iniciar → revisar ítem →
/// confirmar. Fuera de alcance de esta pasada: cancelar sesión,
/// desconfirmar, informe/historial e "iniciar completo desde cero"
/// (ver CONTEXTO_WHEREHOUSE.md).
class PickingControlApi {
  PickingControlApi(this._dio);

  final Dio _dio;

  Future<List<SubpedidoControl>> subpedidos() async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-control/subpedidos');
    return (res.data!['subpedidos'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SubpedidoControl.fromJson)
        .toList();
  }

  Future<DetalleControl> detalle(int idPedidoSubpedido) async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-control/subpedido/$idPedidoSubpedido');
    return DetalleControl.fromJson(res.data!);
  }

  Future<IniciarControlResultado> iniciarControl(int idPedidoSubpedido) async {
    final res = await _dio.post<Map<String, dynamic>>('/picking-control/subpedido/$idPedidoSubpedido/iniciar');
    return IniciarControlResultado.fromJson(res.data!);
  }

  Future<RevisarItemResultado> revisarItem({
    required int idPickingControl,
    required int idPickingControlItem,
    required RevisarItemIn payload,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-control/sesion/$idPickingControl/item/$idPickingControlItem/revisar',
      data: payload.toJson(),
    );
    return RevisarItemResultado.fromJson(res.data!);
  }

  Future<void> confirmarControl(int idPickingControl, {String? observacion}) async {
    await _dio.post<Map<String, dynamic>>(
      '/picking-control/sesion/$idPickingControl/confirmar',
      data: {'observacion': observacion},
    );
  }
}
