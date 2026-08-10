import '../../../core/utils/parsing.dart' show parseDateOrNull, parseDouble;

/// Detalle de `GET /pedidos/{id}` / `GET /pedidos/buscar/{codigo}` (ver
/// `pedidos_service.py::pedidos_get`). Solo lo necesario para la vista de
/// solo lectura del escaneo contextual (`PedidoInfoScreen`) — mismo alcance
/// que `OcInfoScreen` para una OC.
class PedidoDetalle {
  PedidoDetalle({
    required this.idPedido,
    required this.codigoPedido,
    required this.estado,
    required this.clienteNombre,
    this.clienteSucursalNombre,
    this.eta,
    this.observaciones,
    this.lugarEntregaNombre,
    this.vehiculoNombre,
  });

  factory PedidoDetalle.fromJson(Map<String, dynamic> j) => PedidoDetalle(
    idPedido: j['id_pedido'] as int,
    codigoPedido: j['codigo_pedido'] as String? ?? '',
    estado: j['estado'] as String? ?? 'BORRADOR',
    clienteNombre: (j['cliente_razon_social'] as String?)?.isNotEmpty == true
        ? j['cliente_razon_social'] as String
        : (j['cliente_nombre'] as String? ?? ''),
    clienteSucursalNombre: j['cliente_sucursal_nombre'] as String?,
    eta: parseDateOrNull(j['eta']),
    observaciones: j['observaciones'] as String?,
    lugarEntregaNombre: j['lugar_entrega_nombre'] as String?,
    vehiculoNombre: j['vehiculo_nombre'] as String?,
  );

  final int idPedido;
  final String codigoPedido;

  /// 'BORRADOR' | 'ACTIVO' | 'FINALIZADO' | 'ANULADO'
  final String estado;
  final String clienteNombre;
  final String? clienteSucursalNombre;
  final DateTime? eta;
  final String? observaciones;
  final String? lugarEntregaNombre;
  final String? vehiculoNombre;
}

/// Fila de `GET /pedidos/subpedidos/list?id_pedido=` (ver
/// `subpedidos_service.py::subpedidos_list`) — solo lo necesario para
/// listar los subpedidos de un pedido en `PedidoInfoScreen`.
class SubpedidoResumen {
  SubpedidoResumen({
    required this.idPedidoSubpedido,
    required this.estado,
    required this.tipoNombre,
    required this.totalItemsActivos,
  });

  factory SubpedidoResumen.fromJson(Map<String, dynamic> j) => SubpedidoResumen(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    estado: j['estado'] as String? ?? 'BORRADOR',
    tipoNombre: j['tipo_nombre'] as String? ?? '',
    totalItemsActivos: j['total_items_activos'] as int? ?? 0,
  );

  final int idPedidoSubpedido;

  /// 'BORRADOR' | 'CONFIRMADO' | 'PICKING' | 'CONTROL' | 'EXPEDIDO' |
  /// 'ENTREGADO' | 'PEND_CONTROL_GER' | 'PEND_FACTURAR' | 'FACTURADO' |
  /// 'ANULADO'
  final String estado;
  final String tipoNombre;
  final int totalItemsActivos;
}

/// Fila de `GET /pedidos/subpedidos/ver` (ver
/// `pedidos_rout.py::ver_subpedidos_seguimiento_deposito`) — módulo
/// "Pedidos" de la app de depósito. El backend ya filtra por el conjunto
/// de estados que el usuario puede ver según su permiso (ver
/// `ESTADOS_SEGUIMIENTO_DEPOSITO` / `pedidos_subpedidos.aprobar_entrega`),
/// acá solo se muestra lo que llega.
class SubpedidoSeguimiento {
  SubpedidoSeguimiento({
    required this.idPedidoSubpedido,
    required this.idPedido,
    required this.codigoPedido,
    required this.estado,
    required this.tipoNombre,
    required this.clienteNombre,
    this.sucursalNombre,
    this.eta,
    this.observacion,
    required this.totalItemsActivos,
  });

  factory SubpedidoSeguimiento.fromJson(Map<String, dynamic> j) => SubpedidoSeguimiento(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int,
    codigoPedido: j['codigo_pedido'] as String? ?? '',
    estado: j['estado'] as String? ?? 'BORRADOR',
    tipoNombre: j['tipo_nombre'] as String? ?? '',
    clienteNombre: (j['cliente_razon_social'] as String?)?.isNotEmpty == true
        ? j['cliente_razon_social'] as String
        : (j['cliente_nombre'] as String? ?? ''),
    sucursalNombre: j['sucursal_nombre'] as String?,
    eta: parseDateOrNull(j['eta']),
    observacion: j['observacion'] as String?,
    totalItemsActivos: j['total_items_activos'] as int? ?? 0,
  );

  final int idPedidoSubpedido;
  final int idPedido;
  final String codigoPedido;
  final String estado;
  final String tipoNombre;
  final String clienteNombre;
  final String? sucursalNombre;
  final DateTime? eta;
  final String? observacion;
  final int totalItemsActivos;
}

/// Fila de `GET /pedidos/items/list?id_pedido_subpedido=` (ver
/// `subpedidos_items_service.py::subpedidos_items_list`) — ítems de un
/// subpedido para `SubpedidoItemsScreen`, mismo alcance que la tabla de
/// ítems de la web (`ItemsTable.jsx`): producto, cantidad y estado.
class SubpedidoItemResumen {
  SubpedidoItemResumen({
    required this.idPedidoSubpedidoItem,
    required this.productoNombre,
    this.codigoInterno,
    required this.cantidad,
    this.unidadSimbolo,
    this.unidadNombre,
    required this.estado,
    this.observacion,
  });

  factory SubpedidoItemResumen.fromJson(Map<String, dynamic> j) => SubpedidoItemResumen(
    idPedidoSubpedidoItem: j['id_pedido_subpedido_item'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    codigoInterno: j['codigo_interno'] as String?,
    cantidad: parseDouble(j['cantidad']),
    unidadSimbolo: j['unidad_simbolo'] as String?,
    unidadNombre: j['unidad_nombre'] as String?,
    estado: j['estado'] as String? ?? 'PENDIENTE',
    observacion: j['observacion'] as String?,
  );

  final int idPedidoSubpedidoItem;
  final String productoNombre;
  final String? codigoInterno;
  final double cantidad;
  final String? unidadSimbolo;
  final String? unidadNombre;

  /// 'PENDIENTE' | 'RESERVA_PARCIAL' | 'RESERVADO' | 'PICKING_PARCIAL' |
  /// 'PICKEADO' | 'CONTROL_PARCIAL' | 'CONTROLADO' | 'EXPEDIDO' | 'ENTREGADO'
  final String estado;
  final String? observacion;
}
