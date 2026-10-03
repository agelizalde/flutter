import 'package:dio/dio.dart';

import '../domain/expedicion_models.dart';

/// Llamadas a `/pedidos/subpedidos/{en-carga,{id}/carga}*` (ver
/// `subpedido_expedicion_rout.py`). Cubre el checklist de carga del camión
/// que sigue a la asignación de vehículo/chofer (esa asignación se hace en
/// la web, `PreparaEntregaPanel.jsx` — acá solo se escanea/cuenta).
class ExpedicionApi {
  ExpedicionApi(this._dio);

  final Dio _dio;

  Future<List<SubpedidoEnCarga>> subpedidosEnCarga() async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/subpedidos/en-carga');
    return (res.data!['subpedidos'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SubpedidoEnCarga.fromJson)
        .toList();
  }

  Future<DetalleCarga> detalle(int idPedidoSubpedido) async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/subpedidos/$idPedidoSubpedido/carga');
    return DetalleCarga.fromJson(res.data!);
  }

  Future<DetalleCarga> escanearLinea(int idPedidoSubpedido, int idLinea) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/carga/lineas/$idLinea/escanear',
    );
    return DetalleCarga.fromJson(res.data!);
  }

  Future<DetalleCarga> contarLinea(int idPedidoSubpedido, int idLinea, int delta) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/carga/lineas/$idLinea/contar',
      data: {'delta': delta},
    );
    return DetalleCarga.fromJson(res.data!);
  }

  Future<void> completarCarga(int idPedidoSubpedido) async {
    await _dio.post<Map<String, dynamic>>('/pedidos/subpedidos/$idPedidoSubpedido/carga/completar');
  }

  /// Devoluciones PENDIENTE de esta carga — ver BD_CARGA_DEVOLUCION.txt.
  Future<List<DevolucionCarga>> devoluciones(int idPedidoSubpedido) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/carga/devoluciones',
    );
    return (res.data!['devoluciones'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(DevolucionCarga.fromJson)
        .toList();
  }

  Future<void> confirmarDevolucion(int idPedidoSubpedido, int idDevolucion) async {
    await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/carga/devoluciones/$idDevolucion/confirmar',
      data: {},
    );
  }
}
