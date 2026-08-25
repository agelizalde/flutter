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
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SubpedidoResumen.fromJson)
        .toList();
  }

  /// Módulo "Pedidos" (seguimiento): el backend calcula solo el conjunto de
  /// estados visible según el permiso del usuario, acá solo se pasa el
  /// filtro opcional que eligió (`estado`) y la búsqueda libre.
  Future<List<SubpedidoSeguimiento>> seguimiento({
    String? q,
    String? estado,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/subpedidos/ver',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (estado != null) 'estado': estado,
      },
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SubpedidoSeguimiento.fromJson)
        .toList();
  }

  /// Complemento de `seguimiento()`: pedidos `ACTIVO` sin ningún subpedido
  /// todavía, que de otra forma quedan invisibles en `PedidosHomeScreen`
  /// (ver `pedidos_service.py::pedidos_sin_subpedidos`).
  Future<List<PedidoSinSubpedidos>> sinSubpedidos({String? q}) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/sin-subpedidos',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(PedidoSinSubpedidos.fromJson)
        .toList();
  }

  Future<List<SubpedidoItemResumen>> itemsDe(int idPedidoSubpedido) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/items/list',
      queryParameters: {'id_pedido_subpedido': idPedidoSubpedido},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SubpedidoItemResumen.fromJson)
        .toList();
  }

  /// Crea solo la cabecera del pedido (`pedidos.crear`) — sin subpedidos,
  /// esos se agregan después desde la web (ver `NuevoPedidoSheet`, mismo
  /// alcance que `NuevoPedidoModal.jsx` cuando se usa sin ítems). Se manda
  /// `confirmar: true` para que nazca en `ACTIVO` en vez de `BORRADOR` —
  /// la app de depósito no tiene (todavía) una pantalla de "borradores", así
  /// que dejarlo en borrador lo dejaría invisible/sin seguimiento.
  Future<PedidoDetalle> crear({
    required String codigoPedido,
    required int idCliente,
    int? idClienteSucursal,
    String? observaciones,
    int? idLugarEntrega,
    DateTime? eta,
    int? idVehiculoEntrega,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pedidos',
      data: {
        'codigo_pedido': codigoPedido,
        'id_cliente': idCliente,
        'id_cliente_sucursal': idClienteSucursal,
        'observaciones': observaciones,
        'id_lugar_entrega': idLugarEntrega,
        'eta': eta?.toIso8601String(),
        'id_vehiculo_entrega': idVehiculoEntrega,
        'confirmar': true,
      },
    );
    return PedidoDetalle.fromJson(res.data!);
  }

  // =========================================================
  // PICKERS DE "NUEVO PEDIDO" (ver `pedido_models.dart`)
  // =========================================================

  Future<List<ClienteSimple>> clientesListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/clientes',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q, 'limit': 30},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ClienteSimple.fromJson).toList();
  }

  Future<List<SucursalSimple>> sucursalesDeCliente(int idCliente) async {
    final res = await _dio.get<List<dynamic>>(
      '/clientes/$idCliente/sucursales',
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SucursalSimple.fromJson)
        .toList();
  }

  Future<List<LugarEntregaSimple>> lugaresEntregaListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/lugares-entrega',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(LugarEntregaSimple.fromJson).toList();
  }

  Future<List<VehiculoEntregaSimple>> vehiculosListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/vehiculos',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q, 'limit': 50},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(VehiculoEntregaSimple.fromJson).toList();
  }
}
