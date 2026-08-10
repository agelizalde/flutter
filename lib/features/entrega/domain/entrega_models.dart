import '../../../core/utils/parsing.dart';

/// Fila de `GET /pedidos/subpedidos/en-entrega` (ver
/// `subpedido_entrega_service.py::listar_subpedidos_en_entrega`) — a
/// diferencia de la carga del camión (que puede hacer cualquiera con
/// permiso), acá el backend ya filtra para que solo vea esto quien figura
/// como responsable/chofer asignado a esta entrega (o cualquiera, si es
/// TERCERIZADO y no tiene responsable propio) — es el único que puede
/// confirmarla (`confirmar_entrega` lo vuelve a validar server-side).
class SubpedidoEnEntrega {
  SubpedidoEnEntrega({
    required this.idPedidoSubpedido,
    required this.idPedido,
    required this.idCliente,
    required this.estado,
    required this.rowVersion,
    this.eta,
    this.codigoPedido,
    this.clienteNombre,
    this.idClienteSucursal,
    this.sucursalNombre,
    this.tipoSubpedido,
    this.metodoEntrega,
    this.responsablesNombres,
    this.asignadoAMi = false,
  });

  factory SubpedidoEnEntrega.fromJson(Map<String, dynamic> j) => SubpedidoEnEntrega(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int,
    idCliente: j['id_cliente'] as int,
    estado: j['estado'] as String? ?? '',
    rowVersion: j['row_version'] as int? ?? 0,
    eta: j['eta'] as String?,
    codigoPedido: j['codigo_pedido'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    idClienteSucursal: j['id_cliente_sucursal'] as int?,
    sucursalNombre: j['sucursal_nombre'] as String?,
    tipoSubpedido: j['tipo_subpedido'] as String?,
    metodoEntrega: j['metodo_entrega'] as String?,
    responsablesNombres: j['responsables_nombres'] as String?,
    asignadoAMi: j['asignado_a_mi'] as bool? ?? false,
  );

  final int idPedidoSubpedido;
  final int idPedido;
  final int idCliente;
  final String estado;

  /// Para el guard optimista de `POST .../entrega/confirmar`
  /// (`expected_version`).
  final int rowVersion;
  final String? eta;
  final String? codigoPedido;
  final String? clienteNombre;
  final int? idClienteSucursal;
  final String? sucursalNombre;
  final String? tipoSubpedido;

  /// 'PROPIO' | 'TERCERIZADO'
  final String? metodoEntrega;
  final String? responsablesNombres;
  final bool asignadoAMi;

  String get tituloDisplay {
    final partes = [clienteNombre, sucursalNombre, tipoSubpedido]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }
}

/// Ítem del subpedido para el picker de "Rechazo" — `GET
/// /pedidos/subpedidos/{id}/entrega/items`. Nombre y cantidad ya vienen
/// resueltos por el backend tal como figuran en la remisión (diccionario
/// del cliente + lo realmente entregado/pickeado, no el pedido original).
/// "Faltante" no usa esto: es texto libre.
class EntregaItem {
  EntregaItem({
    required this.idPedidoSubpedidoItem,
    required this.idProducto,
    this.productoNombre,
    this.productoCodigo,
    required this.cantidad,
    this.unidadSimbolo,
  });

  factory EntregaItem.fromJson(Map<String, dynamic> j) => EntregaItem(
    idPedidoSubpedidoItem: j['id_pedido_subpedido_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String?,
    productoCodigo: j['producto_codigo'] as String?,
    cantidad: parseDouble(j['cantidad']),
    unidadSimbolo: j['unidad_simbolo'] as String?,
  );

  final int idPedidoSubpedidoItem;
  final int idProducto;
  final String? productoNombre;
  final String? productoCodigo;
  final double cantidad;
  final String? unidadSimbolo;
}
