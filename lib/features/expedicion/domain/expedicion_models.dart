import '../../../core/utils/parsing.dart';

/// Fila de `GET /pedidos/subpedidos/en-carga` (ver
/// `subpedido_expedicion_service.py::listar_subpedidos_en_carga`).
class SubpedidoEnCarga {
  SubpedidoEnCarga({
    required this.idPedidoSubpedido,
    required this.idPedido,
    required this.idCliente,
    required this.estado,
    this.eta,
    this.codigoPedido,
    this.clienteNombre,
    this.idClienteSucursal,
    this.sucursalNombre,
    this.tipoSubpedido,
    this.modoCarga,
    this.metodoEntrega,
    this.responsablesNombres,
    this.asignadoAMi = false,
    required this.totalLineas,
    required this.lineasCompletas,
    required this.pendientes,
  });

  factory SubpedidoEnCarga.fromJson(Map<String, dynamic> j) => SubpedidoEnCarga(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int,
    idCliente: j['id_cliente'] as int,
    estado: j['estado'] as String? ?? '',
    eta: j['eta'] as String?,
    codigoPedido: j['codigo_pedido'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    idClienteSucursal: j['id_cliente_sucursal'] as int?,
    sucursalNombre: j['sucursal_nombre'] as String?,
    tipoSubpedido: j['tipo_subpedido'] as String?,
    modoCarga: j['modo_carga'] as String?,
    metodoEntrega: j['metodo_entrega'] as String?,
    responsablesNombres: j['responsables_nombres'] as String?,
    asignadoAMi: j['asignado_a_mi'] as bool? ?? false,
    totalLineas: j['total_lineas'] as int? ?? 0,
    lineasCompletas: j['lineas_completas'] as int? ?? 0,
    pendientes: j['pendientes'] as int? ?? 0,
  );

  final int idPedidoSubpedido;
  final int idPedido;
  final int idCliente;
  final String estado;
  final String? eta;
  final String? codigoPedido;
  final String? clienteNombre;
  final int? idClienteSucursal;
  final String? sucursalNombre;
  final String? tipoSubpedido;

  /// 'ESCANEO' | 'CONTEO'
  final String? modoCarga;

  /// 'PROPIO' | 'TERCERIZADO'
  final String? metodoEntrega;

  /// Chofer(es)/responsable(s) asignados a la entrega (solo en PROPIO) —
  /// null/vacío en TERCERIZADO, donde no hay un usuario propio asignado.
  final String? responsablesNombres;

  /// true si el usuario logueado figura entre los responsables asignados a
  /// la ENTREGA de este subpedido — no filtra esta lista (cargar el camión
  /// lo puede hacer cualquiera con permiso), es solo un dato informativo de
  /// quién va a repartirlo después.
  final bool asignadoAMi;
  final int totalLineas;
  final int lineasCompletas;
  final int pendientes;

  /// "Cliente - Sucursal - Tipo de subpedido", mismo formato que
  /// `SubpedidoControl.tituloDisplay`.
  String get tituloDisplay {
    final partes = [clienteNombre, sucursalNombre, tipoSubpedido]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }
}

/// Header de subpedido para `DetalleCarga.subpedido` (ver
/// `subpedido_expedicion_service.py::get_carga_subpedido`) — mismo criterio
/// que `SubpedidoControlHeader` de Control de picking.
class SubpedidoCargaHeader {
  SubpedidoCargaHeader({
    required this.idPedidoSubpedido,
    required this.idPedido,
    required this.idCliente,
    this.codigoPedido,
    this.clienteNombre,
    this.idClienteSucursal,
    this.sucursalNombre,
    this.tipoSubpedido,
    required this.estado,
  });

  factory SubpedidoCargaHeader.fromJson(Map<String, dynamic> j) => SubpedidoCargaHeader(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int,
    idCliente: j['id_cliente'] as int,
    codigoPedido: j['codigo_pedido'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    idClienteSucursal: j['id_cliente_sucursal'] as int?,
    sucursalNombre: j['sucursal_nombre'] as String?,
    tipoSubpedido: j['tipo_subpedido'] as String?,
    estado: j['estado'] as String? ?? '',
  );

  final int idPedidoSubpedido;
  final int idPedido;
  final int idCliente;
  final String? codigoPedido;
  final String? clienteNombre;
  final int? idClienteSucursal;
  final String? sucursalNombre;
  final String? tipoSubpedido;
  final String estado;

  String get tituloDisplay {
    final partes = [clienteNombre, sucursalNombre, tipoSubpedido]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }
}

/// Header de la sesión de carga — `GET /pedidos/subpedidos/{id}/carga`.
class CargaSesion {
  CargaSesion({
    required this.idCarga,
    required this.modoCarga,
    required this.estado,
    this.creadoEn,
    this.completadoEn,
  });

  factory CargaSesion.fromJson(Map<String, dynamic> j) => CargaSesion(
    idCarga: j['id_carga'] as int,
    modoCarga: j['modo_carga'] as String? ?? 'ESCANEO',
    estado: j['estado'] as String? ?? 'EN_CURSO',
    creadoEn: j['creado_en'] as String?,
    completadoEn: j['completado_en'] as String?,
  );

  final int idCarga;

  /// 'ESCANEO' | 'CONTEO'
  final String modoCarga;

  /// 'EN_CURSO' | 'COMPLETADA'
  final String estado;
  final String? creadoEn;
  final String? completadoEn;
}

class ResumenCarga {
  ResumenCarga({required this.total, required this.cargados, required this.pendientes});

  factory ResumenCarga.fromJson(Map<String, dynamic> j) => ResumenCarga(
    total: j['total'] as int? ?? 0,
    cargados: j['cargados'] as int? ?? 0,
    pendientes: j['pendientes'] as int? ?? 0,
  );

  final int total;
  final int cargados;
  final int pendientes;
}

/// Línea del checklist de carga: un cajón físico (`tipo == 'CAJON'`) o una
/// unidad suelta individual de un producto sin cajón (`tipo ==
/// 'UNIDAD_SUELTA'`) — cada unidad suelta se escanea/cuenta como si fuera su
/// propio cajón (no se agrupan, a diferencia del "SIN CAJÓN" único que usa
/// Control).
class LineaCarga {
  LineaCarga({
    required this.idLinea,
    required this.tipo,
    required this.etiqueta,
    this.idContenedor,
    this.contenedorIdentificador,
    this.contenedorCodigoBarras,
    this.idPickingItem,
    this.productoNombre,
    this.productoCodigo,
    required this.productoCodigosBarra,
    this.unidadSimbolo,
    required this.cantidadObjetivo,
    required this.cantidadCargada,
    required this.completa,
  });

  factory LineaCarga.fromJson(Map<String, dynamic> j) => LineaCarga(
    idLinea: j['id_linea'] as int,
    tipo: j['tipo'] as String? ?? 'CAJON',
    etiqueta: j['etiqueta'] as String? ?? '',
    idContenedor: j['id_contenedor'] as int?,
    contenedorIdentificador: j['contenedor_identificador'] as String?,
    contenedorCodigoBarras: j['contenedor_codigo_barras'] as String?,
    idPickingItem: j['id_picking_item'] as int?,
    productoNombre: j['producto_nombre'] as String?,
    productoCodigo: j['producto_codigo'] as String?,
    productoCodigosBarra: (j['producto_codigos_barra'] as List? ?? []).cast<String>(),
    unidadSimbolo: j['unidad_simbolo'] as String?,
    cantidadObjetivo: parseDouble(j['cantidad_objetivo']),
    cantidadCargada: parseDouble(j['cantidad_cargada']),
    completa: j['completa'] as bool? ?? false,
  );

  final int idLinea;

  /// 'CAJON' | 'UNIDAD_SUELTA'
  final String tipo;
  final String etiqueta;
  final int? idContenedor;
  final String? contenedorIdentificador;
  final String? contenedorCodigoBarras;
  final int? idPickingItem;
  final String? productoNombre;
  final String? productoCodigo;
  final List<String> productoCodigosBarra;
  final String? unidadSimbolo;
  final double cantidadObjetivo;
  final double cantidadCargada;
  final bool completa;

  bool get esCajon => tipo == 'CAJON';
}

/// `GET /pedidos/subpedidos/{id}/carga`.
class DetalleCarga {
  DetalleCarga({required this.subpedido, required this.carga, required this.resumen, required this.lineas});

  factory DetalleCarga.fromJson(Map<String, dynamic> j) => DetalleCarga(
    subpedido: SubpedidoCargaHeader.fromJson(j['subpedido'] as Map<String, dynamic>),
    carga: CargaSesion.fromJson(j['carga'] as Map<String, dynamic>),
    resumen: ResumenCarga.fromJson(j['resumen'] as Map<String, dynamic>),
    lineas: (j['lineas'] as List? ?? []).cast<Map<String, dynamic>>().map(LineaCarga.fromJson).toList(),
  );

  final SubpedidoCargaHeader subpedido;
  final CargaSesion carga;
  final ResumenCarga resumen;
  final List<LineaCarga> lineas;

  /// Busca, entre las líneas ya cargadas, la que coincide con un código
  /// escaneado — contra `identificador`/`codigo_barras` si es CAJON, o
  /// contra cualquiera de los códigos de barra del producto si es
  /// UNIDAD_SUELTA. Solo considera líneas todavía no completas.
  LineaCarga? matchEscaneo(String codigoRaw) {
    final codigo = codigoRaw.trim().toLowerCase();
    for (final l in lineas) {
      if (l.completa) continue;
      if (l.esCajon) {
        final ident = l.contenedorIdentificador?.trim().toLowerCase();
        final barras = l.contenedorCodigoBarras?.trim().toLowerCase();
        if (codigo == ident || codigo == barras) return l;
      } else {
        if (l.productoCodigosBarra.any((c) => c.trim().toLowerCase() == codigo)) return l;
      }
    }
    return null;
  }
}

/// Devolución pendiente generada al reducir/quitar por Excel (desde Ventas)
/// un ítem que ya se había escaneado en la carga — ver
/// `EXPEDICION/BD_CARGA_DEVOLUCION.txt`. El producto ya salió de stock de
/// verdad al escanearse, así que hay que retirarlo físicamente del camión
/// para poder confirmar (recién ahí se acredita stock real en la ubicación
/// de reacomodo indicada).
class DevolucionCarga {
  DevolucionCarga({
    required this.idDevolucion,
    required this.idPedidoSubpedidoItem,
    required this.idProducto,
    this.productoNombre,
    this.productoCodigo,
    this.unidadSimbolo,
    required this.cantidad,
    required this.estado,
    this.ubicacionDestinoCodigo,
    this.ubicacionDestinoNombre,
  });

  factory DevolucionCarga.fromJson(Map<String, dynamic> j) => DevolucionCarga(
    idDevolucion: j['id_devolucion'] as int,
    idPedidoSubpedidoItem: j['id_pedido_subpedido_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String?,
    productoCodigo: j['producto_codigo'] as String?,
    unidadSimbolo: j['unidad_simbolo'] as String?,
    cantidad: parseDouble(j['cantidad']),
    estado: j['estado'] as String? ?? 'PENDIENTE',
    ubicacionDestinoCodigo: j['ubicacion_destino_codigo'] as String?,
    ubicacionDestinoNombre: j['ubicacion_destino_nombre'] as String?,
  );

  final int idDevolucion;
  final int idPedidoSubpedidoItem;
  final int idProducto;
  final String? productoNombre;
  final String? productoCodigo;
  final String? unidadSimbolo;
  final double cantidad;

  /// 'PENDIENTE' | 'CONFIRMADA'
  final String estado;
  final String? ubicacionDestinoCodigo;
  final String? ubicacionDestinoNombre;
}
