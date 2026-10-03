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

/// `GET /pedidos/subpedidos/entrega/config` (ver
/// `entrega_config_service.py::entrega_config_get_effective` — mismo shape que
/// Ajustes → Operaciones → Entrega, pero sin exigir permiso de Ajustes) — qué de
/// la pantalla de confirmar entrega está habilitado/exigido. Se pide siempre que
/// se abre la pantalla, así que si cambian la config desde la web esto se entera
/// al toque, sin necesitar actualizar la app.
class EntregaConfig {
  EntregaConfig({
    required this.entregaHabilitada,
    required this.fotosHabilitado,
    required this.fotoObligatoria,
    required this.fotoTamanoMaximoHabilitado,
    this.fotoTamanoMaximoMb,
    required this.requiereAprobacion,
    required this.permiteDevoluciones,
    required this.permiteRechazos,
    required this.permiteObservacion,
  });

  factory EntregaConfig.fromJson(Map<String, dynamic> j) => EntregaConfig(
    entregaHabilitada: j['entrega_habilitada'] as bool? ?? true,
    fotosHabilitado: j['fotos_habilitado'] as bool? ?? true,
    fotoObligatoria: j['foto_obligatoria'] as bool? ?? true,
    fotoTamanoMaximoHabilitado: j['foto_tamano_maximo_habilitado'] as bool? ?? false,
    fotoTamanoMaximoMb: j['foto_tamano_maximo_mb'] as int?,
    requiereAprobacion: j['requiere_aprobacion'] as bool? ?? true,
    permiteDevoluciones: j['permite_devoluciones'] as bool? ?? false,
    permiteRechazos: j['permite_rechazos'] as bool? ?? true,
    permiteObservacion: j['permite_observacion'] as bool? ?? true,
  );

  final bool entregaHabilitada;
  final bool fotosHabilitado;
  final bool fotoObligatoria;
  final bool fotoTamanoMaximoHabilitado;
  final int? fotoTamanoMaximoMb;
  final bool requiereAprobacion;
  final bool permiteDevoluciones;
  final bool permiteRechazos;
  final bool permiteObservacion;

  /// Mismo default que FOTO_MAX_BYTES en subpedido_entrega_service.py cuando no
  /// hay un tamaño propio configurado.
  int get fotoMaxMb => (fotoTamanoMaximoHabilitado ? fotoTamanoMaximoMb : null) ?? 10;
}

/// `GET /pedidos/subpedidos/{id}/entrega/documento` (ver
/// `subpedido_entrega_service.py::get_entrega_documento`) — documento
/// completo del PEDIDO (todos sus subpedidos) para que gerencia revise la
/// entrega al resolver una solicitud de Firmas (`PEDIDO_ENTREGA`, ver
/// `FirmaSolicitudDetalleScreen`). Solo se conserva acá el cliente/sucursal
/// del pedido y el subpedido puntual al que corresponde la solicitud
/// (`idDocumento` de `FirmaSolicitud`) — el resto de los subpedidos del
/// pedido no hace falta en esta pantalla.
class PedidoEntregaResumen {
  PedidoEntregaResumen({required this.clienteNombre, this.sucursalNombre, required this.subpedido});

  factory PedidoEntregaResumen.fromJson(Map<String, dynamic> j, {required int idPedidoSubpedido}) {
    final pedido = j['pedido'] as Map<String, dynamic>? ?? const {};
    final subpedidos = (j['subpedidos'] as List? ?? []).cast<Map<String, dynamic>>();
    final match = subpedidos.firstWhere(
      (s) => s['id_pedido_subpedido'] == idPedidoSubpedido,
      orElse: () => subpedidos.isNotEmpty ? subpedidos.first : const {},
    );
    return PedidoEntregaResumen(
      clienteNombre: pedido['cliente_nombre'] as String? ?? '—',
      sucursalNombre: pedido['sucursal_nombre'] as String?,
      subpedido: SubpedidoEntregaResumen.fromJson(match),
    );
  }

  final String clienteNombre;
  final String? sucursalNombre;
  final SubpedidoEntregaResumen subpedido;

  String get clienteSucursalDisplay {
    final sucursal = sucursalNombre?.trim() ?? '';
    return sucursal.isEmpty ? clienteNombre : '$clienteNombre - $sucursal';
  }
}

/// Subpedido puntual dentro de [PedidoEntregaResumen] (ver
/// `_construir_item_documento` en el backend).
class SubpedidoEntregaResumen {
  SubpedidoEntregaResumen({
    this.tipoNombre,
    this.entregoNombre,
    this.entregoFecha,
    this.observacion,
    this.tieneRechazosDevoluciones = false,
    this.resultado,
  });

  factory SubpedidoEntregaResumen.fromJson(Map<String, dynamic> j) {
    final usuarios = j['usuarios'] as Map<String, dynamic>?;
    final entrego = usuarios?['entrego'] as Map<String, dynamic>?;
    return SubpedidoEntregaResumen(
      tipoNombre: j['tipo_nombre'] as String?,
      entregoNombre: entrego?['nombre'] as String?,
      // Momento real en que se marcó ENTREGADO (`pedidos_subpedido_historial`
      // vía `_usuario_evento` en el backend) — no una ETA estimada de
      // antemano, a pesar del nombre "ETA de la entrega" en la pantalla.
      entregoFecha: parseDateOrNull(entrego?['fecha']),
      observacion: j['observacion'] as String?,
      tieneRechazosDevoluciones: j['tiene_rechazos_devoluciones'] as bool? ?? false,
      resultado: j['resultado'] as String?,
    );
  }

  final String? tipoNombre;
  final String? entregoNombre;
  final DateTime? entregoFecha;
  final String? observacion;
  final bool tieneRechazosDevoluciones;

  /// 'SIN_PROBLEMAS' | 'CON_PROBLEMAS' | null (todavía no se entregó) — ver
  /// `_construir_item_documento` en el backend. Cuenta CUALQUIER novedad
  /// (rechazo, devolución o faltante), a diferencia de
  /// [tieneRechazosDevoluciones].
  final String? resultado;

  /// null mientras no se conoce (subpedido todavía no entregado).
  bool? get sinProblemas => resultado == null ? null : resultado == 'SIN_PROBLEMAS';
}
