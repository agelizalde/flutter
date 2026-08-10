import 'package:dio/dio.dart';

import '../domain/pedido_models.dart';

/// Llamadas a `/pedidos/*` (ver `pedidos_rout.py`). Por ahora solo lo que
/// necesita el escaneo contextual de la app de depósito (ver
/// CONTEXTO_WHEREHOUSE.md): resolver un pedido por código y listar sus
/// subpedidos, ambos de solo lectura.
class PedidosApi {
  PedidosApi(this._dio);

  final Dio _dio;

  Future<PedidoDetalle> buscarPorCodigo(String codigo) async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/buscar/$codigo');
    return PedidoDetalle.fromJson(res.data!);
  }

  Future<PedidoDetalle> obtener(int idPedido) async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/$idPedido');
    return PedidoDetalle.fromJson(res.data!);
  }

  Future<List<SubpedidoResumen>> subpedidosDe(int idPedido) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/subpedidos/list',
      queryParameters: {'id_pedido': idPedido},
    );
    return res.data!.cast<Map<String, dynamic>>().map(SubpedidoResumen.fromJson).toList();
  }

  /// Módulo "Pedidos" (seguimiento): el backend calcula solo el conjunto de
  /// estados visible según el permiso del usuario, acá solo se pasa el
  /// filtro opcional que eligió (`estado`) y la búsqueda libre.
  Future<List<SubpedidoSeguimiento>> seguimiento({String? q, String? estado}) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/subpedidos/ver',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (estado != null) 'estado': estado,
      },
    );
    return res.data!.cast<Map<String, dynamic>>().map(SubpedidoSeguimiento.fromJson).toList();
  }

  Future<List<SubpedidoItemResumen>> itemsDe(int idPedidoSubpedido) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/items/list',
      queryParameters: {'id_pedido_subpedido': idPedidoSubpedido},
    );
    return res.data!.cast<Map<String, dynamic>>().map(SubpedidoItemResumen.fromJson).toList();
  }
}
