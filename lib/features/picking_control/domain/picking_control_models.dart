import '../../../core/utils/parsing.dart';

/// Motivos válidos de rechazo (ver `picking_control_service.py::MOTIVOS_VALIDOS`).
/// `CANTIDAD` es el único que el backend reubica como REACOMODO (sin dar de
/// baja) — el resto (`CALIDAD`, `VENCIMIENTO`, `DANO`, `OTRO`) se tratan como
/// merma. "Modificar cantidad" en la UI usa siempre `CANTIDAD`.
const List<String> motivosControlValidos = ['CANTIDAD', 'CALIDAD', 'VENCIMIENTO', 'DANO', 'OTRO'];

/// Sesión de control activa sobre un subpedido — `picking_control` (ver
/// `picking_control_service.py::_get_control_activo`). El campo `estado`
/// solo viene poblado en el detalle (`GET /subpedido/{id}`); en el listado
/// (`GET /subpedidos`) llega `null` porque esa query no lo trae.
class ControlActivo {
  ControlActivo({
    required this.idPickingControl,
    required this.idUsuarioControlador,
    this.controladorNombre,
    this.iniciadoEn,
    this.estado,
    this.modoControl,
  });

  factory ControlActivo.fromJson(Map<String, dynamic> j) => ControlActivo(
    idPickingControl: j['id_picking_control'] as int,
    idUsuarioControlador: j['id_usuario_controlador'] as int,
    controladorNombre: j['controlador_nombre'] as String?,
    iniciadoEn: parseDateOrNull(j['iniciado_en']),
    estado: j['estado'] as String?,
    modoControl: j['modo_control'] as String?,
  );

  final int idPickingControl;
  final int idUsuarioControlador;
  final String? controladorNombre;
  final DateTime? iniciadoEn;
  final String? estado;

  /// 'LISTA' | 'CAJON' | 'PRODUCTO' -- modo con el que se inició la sesión
  /// (viene de la asignación si había una, si no default 'LISTA').
  final String? modoControl;
}

/// Asignación de controlador previa a iniciar la sesión (ver
/// `picking_control_service.py::_get_asignacion_activa`). Puede existir sin
/// que haya `ControlActivo` todavía -- alguien fue designado pero no arrancó.
class AsignacionControl {
  AsignacionControl({
    required this.idUsuarioAsignado,
    this.nombreAsignado,
    required this.modoControl,
    this.observacion,
  });

  factory AsignacionControl.fromJson(Map<String, dynamic> j) => AsignacionControl(
    idUsuarioAsignado: j['id_usuario_asignado'] as int,
    nombreAsignado: j['nombre_asignado'] as String?,
    modoControl: j['modo_control'] as String? ?? 'LISTA',
    observacion: j['observacion'] as String?,
  );

  final int idUsuarioAsignado;
  final String? nombreAsignado;
  final String modoControl;
  final String? observacion;
}

/// Fila de `GET /picking-control/subpedidos`.
class SubpedidoControl {
  SubpedidoControl({
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
    required this.totalItems,
    this.controlActivo,
    this.asignacion,
  });

  factory SubpedidoControl.fromJson(Map<String, dynamic> j) => SubpedidoControl(
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
    totalItems: j['total_items'] as int? ?? 0,
    controlActivo: j['control_activo'] == null
        ? null
        : ControlActivo.fromJson(j['control_activo'] as Map<String, dynamic>),
    asignacion: j['asignacion'] == null
        ? null
        : AsignacionControl.fromJson(j['asignacion'] as Map<String, dynamic>),
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
  final int totalItems;
  final ControlActivo? controlActivo;
  final AsignacionControl? asignacion;

  /// "Cliente - Sucursal - Tipo de subpedido", mismo formato que
  /// `SubpedidoPicking.tituloDisplay` en Picking Operario.
  String get tituloDisplay {
    final partes = [clienteNombre, sucursalNombre, tipoSubpedido]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }
}

/// Ítem pickeado disponible para controlar — fila de `picking_items` +
/// producto/lote/cajón/zona (ver `picking_control_service.py::_items_query`).
/// Ya viene filtrado server-side por "listo para control" (cajón cerrado o,
/// si no tiene cajón, sesión de picking finalizada).
class ItemControl {
  ItemControl({
    required this.idPickingItem,
    required this.idStockReservaDetalle,
    required this.idPedidoSubpedidoItem,
    required this.idProducto,
    required this.productoNombre,
    this.productoCodigo,
    this.productoSku,
    required this.idUnidadMedida,
    required this.unidadNombre,
    required this.unidadSimbolo,
    required this.cantidadReservada,
    required this.cantidadPickeada,
    this.idContenedor,
    this.contenedorIdentificador,
    this.contenedorCodigoBarras,
    this.idLote,
    this.loteInterno,
    this.loteProveedor,
    this.fechaVencimiento,
    required this.idZona,
    this.zonaNombre,
    this.zonaCodigo,
    required this.zonaOrden,
    required this.idUbicacion,
    this.ubicacionCodigo,
    this.ubicacionNombre,
    this.pickerNombre,
    this.pickeadoEn,
    this.idPickingControlItem,
    this.cantidadControlada,
    this.resultadoControl,
    this.motivosRechazo,
    this.observacionControl,
  });

  factory ItemControl.fromJson(Map<String, dynamic> j) => ItemControl(
    idPickingItem: j['id_picking_item'] as int,
    idStockReservaDetalle: j['id_stock_reserva_detalle'] as int,
    idPedidoSubpedidoItem: j['id_pedido_subpedido_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    productoCodigo: j['producto_codigo'] as String?,
    productoSku: j['producto_sku'] as String?,
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadNombre: j['unidad_nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    cantidadReservada: parseDouble(j['cantidad_reservada']),
    cantidadPickeada: parseDouble(j['cantidad_pickeada']),
    idContenedor: j['id_contenedor'] as int?,
    contenedorIdentificador: j['contenedor_identificador'] as String?,
    contenedorCodigoBarras: j['contenedor_codigo_barras'] as String?,
    idLote: j['id_lote'] as int?,
    loteInterno: j['lote_interno'] as String?,
    loteProveedor: j['lote_proveedor'] as String?,
    fechaVencimiento: j['fecha_vencimiento'] as String?,
    idZona: j['id_zona'] as int,
    zonaNombre: j['zona_nombre'] as String?,
    zonaCodigo: j['zona_codigo'] as String?,
    zonaOrden: j['zona_orden'] as int? ?? 0,
    idUbicacion: j['id_ubicacion'] as int,
    ubicacionCodigo: j['ubicacion_codigo'] as String?,
    ubicacionNombre: j['ubicacion_nombre'] as String?,
    pickerNombre: j['picker_nombre'] as String?,
    pickeadoEn: j['pickeado_en'] as String?,
    idPickingControlItem: j['id_picking_control_item'] as int?,
    cantidadControlada: parseDoubleOrNull(j['cantidad_controlada']),
    resultadoControl: j['resultado_control'] as String?,
    motivosRechazo: j['motivos_rechazo'] as String?,
    observacionControl: j['observacion_control'] as String?,
  );

  final int idPickingItem;
  final int idStockReservaDetalle;
  final int idPedidoSubpedidoItem;
  final int idProducto;
  final String productoNombre;
  final String? productoCodigo;
  final String? productoSku;
  final int idUnidadMedida;
  final String unidadNombre;
  final String unidadSimbolo;
  final double cantidadReservada;
  final double cantidadPickeada;

  /// `null` = este pick se hizo sin cajón ("SIN CAJÓN" en la UI).
  final int? idContenedor;
  final String? contenedorIdentificador;
  final String? contenedorCodigoBarras;
  final int? idLote;
  final String? loteInterno;
  final String? loteProveedor;
  final String? fechaVencimiento;
  final int idZona;
  final String? zonaNombre;
  final String? zonaCodigo;
  final int zonaOrden;
  final int idUbicacion;
  final String? ubicacionCodigo;
  final String? ubicacionNombre;
  final String? pickerNombre;
  final String? pickeadoEn;

  /// `id_picking_control_item` de la sesión de control activa — con éste se
  /// llama a `POST .../item/{id}/revisar`.
  final int? idPickingControlItem;
  final double? cantidadControlada;

  /// 'APROBADO' | 'RECHAZADO' | null (pendiente)
  final String? resultadoControl;
  final String? motivosRechazo;
  final String? observacionControl;

  bool get controlado => resultadoControl != null;

  /// Devuelve una copia con el resultado de una revisión aplicado -- usado
  /// por las 3 pantallas de control (cajón/lista/producto) para reflejar
  /// al instante el resultado de `revisar_item` sin volver a pedir el
  /// detalle completo.
  ItemControl copyWith({
    double? cantidadControlada,
    String? resultadoControl,
    String? motivosRechazo,
    String? observacionControl,
  }) {
    return ItemControl(
      idPickingItem: idPickingItem,
      idStockReservaDetalle: idStockReservaDetalle,
      idPedidoSubpedidoItem: idPedidoSubpedidoItem,
      idProducto: idProducto,
      productoNombre: productoNombre,
      productoCodigo: productoCodigo,
      productoSku: productoSku,
      idUnidadMedida: idUnidadMedida,
      unidadNombre: unidadNombre,
      unidadSimbolo: unidadSimbolo,
      cantidadReservada: cantidadReservada,
      cantidadPickeada: cantidadPickeada,
      idContenedor: idContenedor,
      contenedorIdentificador: contenedorIdentificador,
      contenedorCodigoBarras: contenedorCodigoBarras,
      idLote: idLote,
      loteInterno: loteInterno,
      loteProveedor: loteProveedor,
      fechaVencimiento: fechaVencimiento,
      idZona: idZona,
      zonaNombre: zonaNombre,
      zonaCodigo: zonaCodigo,
      zonaOrden: zonaOrden,
      idUbicacion: idUbicacion,
      ubicacionCodigo: ubicacionCodigo,
      ubicacionNombre: ubicacionNombre,
      pickerNombre: pickerNombre,
      pickeadoEn: pickeadoEn,
      idPickingControlItem: idPickingControlItem,
      cantidadControlada: cantidadControlada ?? this.cantidadControlada,
      resultadoControl: resultadoControl ?? this.resultadoControl,
      motivosRechazo: motivosRechazo ?? this.motivosRechazo,
      observacionControl: observacionControl ?? this.observacionControl,
    );
  }
}

/// Header de subpedido para `DetalleControl.subpedido` (ver
/// `picking_control_service.py::_get_subpedido_header`).
class SubpedidoControlHeader {
  SubpedidoControlHeader({
    required this.idPedidoSubpedido,
    required this.idPedido,
    required this.idCliente,
    this.codigoPedido,
    this.clienteNombre,
    this.idClienteSucursal,
    this.sucursalNombre,
    this.tipoSubpedido,
    required this.estado,
    this.eta,
    this.observacion,
  });

  factory SubpedidoControlHeader.fromJson(Map<String, dynamic> j) => SubpedidoControlHeader(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int,
    idCliente: j['id_cliente'] as int,
    codigoPedido: j['codigo_pedido'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    idClienteSucursal: j['id_cliente_sucursal'] as int?,
    sucursalNombre: j['sucursal_nombre'] as String?,
    tipoSubpedido: j['tipo_subpedido'] as String?,
    estado: j['estado'] as String? ?? '',
    eta: j['eta'] as String?,
    observacion: j['observacion'] as String?,
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
  final String? eta;
  final String? observacion;

  String get tituloDisplay {
    final partes = [clienteNombre, sucursalNombre, tipoSubpedido]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }
}

class ResumenControl {
  ResumenControl({
    required this.total,
    required this.pendientes,
    required this.aprobados,
    required this.rechazados,
    required this.pctCompletado,
  });

  factory ResumenControl.fromJson(Map<String, dynamic> j) => ResumenControl(
    total: j['total'] as int? ?? 0,
    pendientes: j['pendientes'] as int? ?? 0,
    aprobados: j['aprobados'] as int? ?? 0,
    rechazados: j['rechazados'] as int? ?? 0,
    pctCompletado: j['pct_completado'] as int? ?? 0,
  );

  final int total;
  final int pendientes;
  final int aprobados;
  final int rechazados;
  final int pctCompletado;
}

/// Ítems de control agrupados por cajón físico, para
/// `PickingControlDetalleScreen` — agrupación 100% client-side, el backend
/// ya trae `id_contenedor`/`contenedor_identificador` por ítem. `idContenedor
/// == null` agrupa bajo el pseudo-cajón "SIN CAJÓN".
class GrupoCajonControl {
  GrupoCajonControl({required this.idContenedor, required this.etiqueta, required this.items});

  final int? idContenedor;
  final String etiqueta;
  final List<ItemControl> items;

  int get total => items.length;
  int get pendientes => items.where((i) => !i.controlado).length;
  int get aprobados => items.where((i) => i.resultadoControl == 'APROBADO').length;
  int get rechazados => items.where((i) => i.resultadoControl == 'RECHAZADO').length;
}

/// Ítems de control agrupados por producto (mismo criterio que
/// `ProductoAggRow` en el WorkScreen web) -- útil cuando un producto quedó
/// repartido en más de un cajón/zona y el controlador quiere revisarlo
/// todo junto en vez de ir cajón por cajón.
class GrupoProductoControl {
  GrupoProductoControl({required this.idProducto, required this.etiqueta, required this.items});

  final int idProducto;
  final String etiqueta;
  final List<ItemControl> items;

  int get total => items.length;
  int get pendientes => items.where((i) => !i.controlado).length;
  int get aprobados => items.where((i) => i.resultadoControl == 'APROBADO').length;
  int get rechazados => items.where((i) => i.resultadoControl == 'RECHAZADO').length;
}

/// `GET /picking-control/subpedido/{id}`.
class DetalleControl {
  DetalleControl({
    required this.subpedido,
    this.controlActivo,
    this.asignacion,
    required this.resumen,
    required this.items,
  });

  factory DetalleControl.fromJson(Map<String, dynamic> j) => DetalleControl(
    subpedido: SubpedidoControlHeader.fromJson(j['subpedido'] as Map<String, dynamic>),
    controlActivo: j['control_activo'] == null
        ? null
        : ControlActivo.fromJson(j['control_activo'] as Map<String, dynamic>),
    asignacion: j['asignacion'] == null
        ? null
        : AsignacionControl.fromJson(j['asignacion'] as Map<String, dynamic>),
    resumen: ResumenControl.fromJson(j['resumen'] as Map<String, dynamic>),
    items: (j['items'] as List? ?? []).cast<Map<String, dynamic>>().map(ItemControl.fromJson).toList(),
  );

  final SubpedidoControlHeader subpedido;
  final ControlActivo? controlActivo;
  final AsignacionControl? asignacion;
  final ResumenControl resumen;
  final List<ItemControl> items;

  /// Cajones ordenados alfabéticamente por identificador, con "SIN CAJÓN"
  /// siempre al final (mismo criterio que un cajón más: no es un caso de
  /// error, solo el último grupo a revisar).
  List<GrupoCajonControl> get gruposPorCajon {
    final orden = <int?>[];
    final mapa = <int?, List<ItemControl>>{};
    for (final item in items) {
      final key = item.idContenedor;
      final grupo = mapa.putIfAbsent(key, () {
        orden.add(key);
        return <ItemControl>[];
      });
      grupo.add(item);
    }

    final grupos = orden.map((key) {
      final itemsGrupo = mapa[key]!;
      final etiqueta = key == null
          ? 'SIN CAJÓN'
          : (itemsGrupo.first.contenedorIdentificador ?? 'Cajón #$key');
      return GrupoCajonControl(idContenedor: key, etiqueta: etiqueta, items: itemsGrupo);
    }).toList();

    grupos.sort((a, b) {
      if (a.idContenedor == null) return 1;
      if (b.idContenedor == null) return -1;
      return a.etiqueta.compareTo(b.etiqueta);
    });
    return grupos;
  }

  /// Productos ordenados alfabéticamente, cada uno con todas sus líneas
  /// (puede tener más de una si el mismo producto quedó repartido en
  /// distintos cajones/zonas).
  List<GrupoProductoControl> get gruposPorProducto {
    final orden = <int>[];
    final mapa = <int, List<ItemControl>>{};
    for (final item in items) {
      final key = item.idProducto;
      final grupo = mapa.putIfAbsent(key, () {
        orden.add(key);
        return <ItemControl>[];
      });
      grupo.add(item);
    }

    final grupos = orden.map((key) {
      final itemsGrupo = mapa[key]!;
      return GrupoProductoControl(idProducto: key, etiqueta: itemsGrupo.first.productoNombre, items: itemsGrupo);
    }).toList();

    grupos.sort((a, b) => a.etiqueta.compareTo(b.etiqueta));
    return grupos;
  }
}

/// `POST /picking-control/subpedido/{id}/iniciar`.
class IniciarControlResultado {
  IniciarControlResultado({
    required this.accion,
    required this.modo,
    required this.idPickingControl,
    required this.totalItems,
    this.pendientes,
  });

  factory IniciarControlResultado.fromJson(Map<String, dynamic> j) => IniciarControlResultado(
    accion: j['accion'] as String? ?? 'iniciado',
    modo: j['modo'] as String?,
    idPickingControl: j['id_picking_control'] as int,
    totalItems: j['total_items'] as int?,
    pendientes: j['pendientes'] as int?,
  );

  /// 'iniciado' (sesión nueva) | 'retomado' (ya había una propia en curso)
  final String accion;
  final String? modo;
  final int idPickingControl;
  final int? totalItems;
  final int? pendientes;
}

class ProgresoControl {
  ProgresoControl({
    required this.total,
    required this.pendientes,
    required this.aprobados,
    required this.rechazados,
  });

  factory ProgresoControl.fromJson(Map<String, dynamic> j) => ProgresoControl(
    total: j['total'] as int? ?? 0,
    pendientes: j['pendientes'] as int? ?? 0,
    aprobados: j['aprobados'] as int? ?? 0,
    rechazados: j['rechazados'] as int? ?? 0,
  );

  final int total;
  final int pendientes;
  final int aprobados;
  final int rechazados;
}

/// `POST /picking-control/sesion/{id}/item/{id}/revisar`.
class RevisarItemResultado {
  RevisarItemResultado({
    required this.idPickingControlItem,
    required this.resultado,
    required this.cantidadControlada,
    required this.progreso,
  });

  factory RevisarItemResultado.fromJson(Map<String, dynamic> j) => RevisarItemResultado(
    idPickingControlItem: j['id_picking_control_item'] as int,
    resultado: j['resultado'] as String? ?? '',
    cantidadControlada: parseDouble(j['cantidad_controlada']),
    progreso: ProgresoControl.fromJson(j['progreso'] as Map<String, dynamic>),
  );

  final int idPickingControlItem;
  final String resultado;
  final double cantidadControlada;
  final ProgresoControl progreso;
}
