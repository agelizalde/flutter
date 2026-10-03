import '../../../core/utils/parsing.dart';

/// Tarea de picking (fila de `stock_reserva_picking`, ver
/// `picking_operario_service.py::get_mis_tareas`).
class TareaPicking {
  TareaPicking({
    required this.idStockReservaDetalle,
    this.idPickingItem,
    required this.idPedidoSubpedidoItem,
    required this.idProducto,
    required this.productoNombre,
    required this.productoCodigo,
    required this.idUnidadMedida,
    required this.unidadNombre,
    required this.unidadSimbolo,
    required this.idUbicacion,
    required this.ubicacionCodigo,
    required this.ubicacionNombre,
    required this.zonaNombre,
    required this.zonaCodigo,
    required this.zonaOrden,
    required this.idZona,
    required this.cantidad,
    required this.estado,
    this.contenedorId,
    this.contenedorIdentificador,
    this.cantidadPickeada,
    required this.pickingPorPeso,
    required this.puedeDevolver,
    this.codigosBarra = const [],
  });

  factory TareaPicking.fromJson(Map<String, dynamic> j) => TareaPicking(
    idStockReservaDetalle: j['id_stock_reserva_detalle'] as int,
    idPickingItem: j['id_picking_item'] as int?,
    idPedidoSubpedidoItem: j['id_pedido_subpedido_item'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    productoCodigo: j['producto_codigo'] as String? ?? '',
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadNombre: j['unidad_nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    idUbicacion: j['id_ubicacion'] as int,
    ubicacionCodigo: j['ubicacion_codigo'] as String? ?? '',
    ubicacionNombre: j['ubicacion_nombre'] as String? ?? '',
    zonaNombre: j['zona_nombre'] as String? ?? '',
    zonaCodigo: j['zona_codigo'] as String? ?? '',
    zonaOrden: j['zona_orden'] as int? ?? 0,
    idZona: j['id_zona'] as int,
    cantidad: parseDouble(j['cantidad']),
    estado: j['estado'] as String? ?? 'ASIGNADO',
    contenedorId: j['contenedor_id'] as int?,
    contenedorIdentificador: j['contenedor_identificador'] as String?,
    cantidadPickeada: parseDoubleOrNull(j['cantidad_pickeada']),
    pickingPorPeso: j['picking_por_peso'] as bool? ?? false,
    puedeDevolver: j['puede_devolver'] as bool? ?? true,
    codigosBarra: (j['codigos_barra'] as List?)?.cast<String>() ?? const [],
  );

  final int idStockReservaDetalle;
  final int? idPickingItem;
  final int idPedidoSubpedidoItem;
  final int idProducto;
  final String productoNombre;
  final String productoCodigo;
  final int idUnidadMedida;
  final String unidadNombre;
  final String unidadSimbolo;
  final int idUbicacion;
  final String ubicacionCodigo;
  final String ubicacionNombre;
  final String zonaNombre;
  final String zonaCodigo;
  final int zonaOrden;
  final int idZona;
  final double cantidad;

  /// 'ASIGNADO' | 'EN_PROCESO' | 'COMPLETADO' | 'CANCELADO'
  final String estado;
  final int? contenedorId;
  final String? contenedorIdentificador;
  final double? cantidadPickeada;

  /// Si `true`, la unidad de medida de esta tarea es pesable
  /// (`unidades.pesable`) — el operario puede ingresar cualquier peso real,
  /// sin tope ni autorización de supervisor.
  final bool pickingPorPeso;

  /// Igual criterio que `ItemPickeadoCajon.puedeDevolver`: una vez que el
  /// subpedido ya tiene Control en curso o terminado, ya no se puede
  /// devolver este ítem — ver `get_mis_tareas` en el backend.
  final bool puedeDevolver;

  /// Códigos de barra ACTIVOS de este producto (`productos_codigos_barra`,
  /// puede haber más de uno) — se usan para "Escaneo de producto"
  /// (Ajustes -> Operaciones -> Picking -> APP - Picking): la app compara
  /// el código escaneado contra esta lista para dar feedback inmediato
  /// (✓/✗) sin ida y vuelta al servidor, pero el servidor vuelve a
  /// validarlo igual en `completar_tarea` si `escaneo_producto_obligatorio`
  /// está prendido — esto es solo para la UX, no la fuente de verdad. Vacía
  /// si el producto no tiene ningún código cargado (no hay nada que
  /// escanear para él, ninguna de las dos reglas de escaneo le aplica).
  final List<String> codigosBarra;

  bool get tieneCodigoBarras => codigosBarra.isNotEmpty;

  bool get pendiente => estado == 'ASIGNADO' || estado == 'EN_PROCESO';
  bool get completada => estado == 'COMPLETADO';
  bool get cancelada => estado == 'CANCELADO';
}

/// Subpedido con tareas de picking asignadas al operario logueado.
class SubpedidoPicking {
  SubpedidoPicking({
    required this.idPedidoSubpedido,
    this.idPedido,
    this.codigoPedido,
    this.clienteNombre,
    this.sucursalNombre,
    this.tipoSubpedido,
    this.estadoSubpedido,
    required this.total,
    required this.completadas,
    required this.tareas,
  });

  factory SubpedidoPicking.fromJson(Map<String, dynamic> j) => SubpedidoPicking(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int?,
    codigoPedido: j['codigo_pedido'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    sucursalNombre: j['sucursal_nombre'] as String?,
    tipoSubpedido: j['tipo_subpedido'] as String?,
    estadoSubpedido: j['estado_subpedido'] as String?,
    total: j['total'] as int? ?? 0,
    completadas: j['completadas'] as int? ?? 0,
    tareas: (j['tareas'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(TareaPicking.fromJson)
        .toList(),
  );

  final int idPedidoSubpedido;
  final int? idPedido;
  final String? codigoPedido;
  final String? clienteNombre;
  final String? sucursalNombre;
  final String? tipoSubpedido;
  final String? estadoSubpedido;
  final int total;
  final int completadas;
  final List<TareaPicking> tareas;

  /// "Cliente - Sucursal - Tipo de subpedido", omitiendo las partes que no
  /// vinieron (sucursal y tipo son opcionales según el pedido).
  String get tituloDisplay {
    final partes = [clienteNombre, sucursalNombre, tipoSubpedido]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }

  /// "Cliente - Sucursal" — igual que [tituloDisplay] pero sin el tipo de
  /// subpedido, para el header de `PickingTrabajoScreen` (que ya muestra el
  /// tiempo transcurrido al lado).
  String get clienteSucursalDisplay {
    final partes = [clienteNombre, sucursalNombre]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }

  /// Solo cuenta como "pendiente" si al usuario le queda al menos una tarea
  /// sin completar en este subpedido.
  bool get tienePendientes => completadas < total;

  /// Zonas con al menos una tarea pendiente, en orden de `zonaOrden`, sin
  /// duplicados — lo que se le ofrece al operario en `ZonaSelectorScreen`.
  List<({int idZona, String nombre, String codigo, int pendientes})> get zonasPendientes {
    final mapa = <int, ({int idZona, String nombre, String codigo, int pendientes})>{};
    for (final t in tareas) {
      if (!t.pendiente) continue;
      final actual = mapa[t.idZona];
      mapa[t.idZona] = (
        idZona: t.idZona,
        nombre: t.zonaNombre,
        codigo: t.zonaCodigo,
        pendientes: (actual?.pendientes ?? 0) + 1,
      );
    }
    final lista = mapa.values.toList();
    lista.sort((a, b) => a.idZona.compareTo(b.idZona));
    return lista;
  }
}

/// Sesión de zona activa (cronómetro) — `picking_sesion_zona` (ver
/// `picking_operario_service.py::get_sesion_activa`).
class SesionZona {
  SesionZona({
    required this.idSesion,
    required this.idPedidoSubpedido,
    required this.idZona,
    this.idContenedorActivo,
    this.contenedorIdentificador,
    required this.iniciadoEn,
    this.ubicacionArmadoCodigo,
    this.ubicacionArmadoNombre,
  });

  factory SesionZona.fromJson(Map<String, dynamic> j) => SesionZona(
    idSesion: j['id_sesion'] as int,
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idZona: j['id_zona'] as int,
    idContenedorActivo: j['id_contenedor_activo'] as int?,
    contenedorIdentificador: j['contenedor_identificador'] as String?,
    iniciadoEn: DateTime.parse(j['iniciado_en'] as String),
    ubicacionArmadoCodigo: j['ubicacion_armado_codigo'] as String?,
    ubicacionArmadoNombre: j['ubicacion_armado_nombre'] as String?,
  );

  final int idSesion;
  final int idPedidoSubpedido;
  final int idZona;
  final int? idContenedorActivo;
  final String? contenedorIdentificador;
  final DateTime iniciadoEn;

  /// Ubicación de armado efectiva del pedido/subpedido (donde el operario
  /// tiene que dejar los cajones al terminar) — resuelta server-side
  /// (`pedidos_subpedido.id_ubicacion_armado` o `pedidos.id_ubicacion_armado`,
  /// ver `picking_operario_service.py::_resolver_ubicacion_armado`).
  final String? ubicacionArmadoCodigo;
  final String? ubicacionArmadoNombre;
}

/// `GET /picking-operario/mis-tareas`.
class MisTareasResponse {
  MisTareasResponse({required this.subpedidos, this.sesionActiva});

  factory MisTareasResponse.fromJson(Map<String, dynamic> j) => MisTareasResponse(
    subpedidos: (j['subpedidos'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SubpedidoPicking.fromJson)
        .toList(),
    sesionActiva: j['sesion_activa'] == null
        ? null
        : SesionZona.fromJson(j['sesion_activa'] as Map<String, dynamic>),
  );

  final List<SubpedidoPicking> subpedidos;
  final SesionZona? sesionActiva;
}

/// `GET /picking-operario/contenedor/buscar`.
class ContenedorPicking {
  ContenedorPicking({
    required this.idContenedor,
    required this.identificador,
    this.codigoBarras,
    required this.estado,
    this.descripcion,
    this.tipoNombre,
    this.ubicacionCodigo,
    this.ubicacionNombre,
    required this.itemsPickingCount,
  });

  factory ContenedorPicking.fromJson(Map<String, dynamic> j) => ContenedorPicking(
    idContenedor: j['id_contenedor'] as int,
    identificador: j['identificador'] as String? ?? '',
    codigoBarras: j['codigo_barras'] as String?,
    estado: j['estado'] as String? ?? 'VACIO',
    descripcion: j['descripcion'] as String?,
    tipoNombre: j['tipo_nombre'] as String?,
    ubicacionCodigo: j['ubicacion_codigo'] as String?,
    ubicacionNombre: j['ubicacion_nombre'] as String?,
    itemsPickingCount: j['items_picking_count'] as int? ?? 0,
  );

  final int idContenedor;
  final String identificador;
  final String? codigoBarras;

  /// 'VACIO' | 'LLENO' | 'EN_TRANSITO' | 'BLOQUEADO' | 'MANTENIMIENTO'
  final String estado;
  final String? descripcion;
  final String? tipoNombre;
  final String? ubicacionCodigo;
  final String? ubicacionNombre;
  final int itemsPickingCount;
}

/// `GET /picking-operario/contenedor/detalle?codigo=` — usado por el
/// buscador genérico (`/escaner`) para mostrar a qué subpedido está afectado
/// un cajón y qué tiene pickeado adentro.
class ContenedorDetalle {
  ContenedorDetalle({
    required this.idContenedor,
    required this.identificador,
    required this.estado,
    this.subpedido,
    required this.items,
  });

  factory ContenedorDetalle.fromJson(Map<String, dynamic> j) => ContenedorDetalle(
    idContenedor: j['contenedor']['id_contenedor'] as int,
    identificador: j['contenedor']['identificador'] as String? ?? '',
    estado: j['contenedor']['estado'] as String? ?? 'VACIO',
    subpedido: j['subpedido'] == null
        ? null
        : SubpedidoContenedor.fromJson(j['subpedido'] as Map<String, dynamic>),
    items: (j['items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ItemContenedor.fromJson)
        .toList(),
  );

  final int idContenedor;
  final String identificador;

  /// 'VACIO' | 'LLENO' | 'EN_TRANSITO' | 'BLOQUEADO' | 'MANTENIMIENTO'
  final String estado;

  /// null si el cajón no tiene ningún picking activo adentro ahora mismo.
  final SubpedidoContenedor? subpedido;
  final List<ItemContenedor> items;
}

class SubpedidoContenedor {
  SubpedidoContenedor({
    required this.idPedidoSubpedido,
    required this.idPedido,
    this.codigoPedido,
    this.clienteNombre,
    this.sucursalNombre,
    this.tipoSubpedido,
    required this.estado,
  });

  factory SubpedidoContenedor.fromJson(Map<String, dynamic> j) => SubpedidoContenedor(
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int,
    codigoPedido: j['codigo_pedido'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    sucursalNombre: j['sucursal_nombre'] as String?,
    tipoSubpedido: j['tipo_subpedido'] as String?,
    estado: j['estado'] as String? ?? '',
  );

  final int idPedidoSubpedido;
  final int idPedido;
  final String? codigoPedido;
  final String? clienteNombre;
  final String? sucursalNombre;
  final String? tipoSubpedido;
  final String estado;

  String get tituloDisplay {
    final partes = [clienteNombre, sucursalNombre]
        .where((p) => p != null && p.trim().isNotEmpty)
        .toList();
    return partes.isEmpty ? (codigoPedido ?? 'Subpedido #$idPedidoSubpedido') : partes.join(' - ');
  }
}

class ItemContenedor {
  ItemContenedor({
    required this.idProducto,
    required this.productoNombre,
    this.productoCodigo,
    this.unidadSimbolo,
    required this.cantidad,
  });

  factory ItemContenedor.fromJson(Map<String, dynamic> j) => ItemContenedor(
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    productoCodigo: j['producto_codigo'] as String?,
    unidadSimbolo: j['unidad_simbolo'] as String?,
    cantidad: parseDouble(j['cantidad']),
  );

  final int idProducto;
  final String productoNombre;
  final String? productoCodigo;
  final String? unidadSimbolo;
  final double cantidad;
}

/// `POST /picking-operario/tarea/{id}/completar`.
class CompletarTareaResultado {
  CompletarTareaResultado({
    required this.idStockReservaDetalle,
    required this.cantidadPickeada,
    this.cantidadRestante,
    this.idTareaRestante,
    required this.pickeoParcial,
    required this.subpedidoAvanzadoAControl,
    this.ajusteStockDiferencia,
  });

  factory CompletarTareaResultado.fromJson(Map<String, dynamic> j) => CompletarTareaResultado(
    idStockReservaDetalle: j['id_stock_reserva_detalle'] as int,
    cantidadPickeada: parseDouble(j['cantidad_pickeada']),
    cantidadRestante: parseDoubleOrNull(j['cantidad_restante']),
    idTareaRestante: j['id_tarea_restante'] as int?,
    pickeoParcial: j['pickeo_parcial'] as bool? ?? false,
    subpedidoAvanzadoAControl: j['subpedido_avanzado_a_control'] as bool? ?? false,
    ajusteStockDiferencia: parseDoubleOrNull(j['ajuste_stock_diferencia']),
  );

  final int idStockReservaDetalle;
  final double cantidadPickeada;
  final double? cantidadRestante;
  final int? idTareaRestante;
  final bool pickeoParcial;
  final bool subpedidoAvanzadoAControl;

  /// Si no-nulo, el peso pesado superó el stock físico registrado y el
  /// backend corrigió automáticamente la existencia (ver
  /// `picking_operario_service.py::_ajustar_stock_por_diferencia_pesaje`) —
  /// esta es la diferencia que se sumó.
  final double? ajusteStockDiferencia;
}

/// `POST /picking-operario/zona/sesion/{id}/cajon`.
class SeleccionarCajonResultado {
  SeleccionarCajonResultado({
    required this.idSesion,
    this.idContenedorActivo,
    this.cajonAnteriorCerrado,
  });

  factory SeleccionarCajonResultado.fromJson(Map<String, dynamic> j) => SeleccionarCajonResultado(
    idSesion: j['id_sesion'] as int,
    idContenedorActivo: j['id_contenedor_activo'] as int?,
    cajonAnteriorCerrado: j['cajon_anterior_cerrado'] as int?,
  );

  final int idSesion;

  /// `null` = picking sin cajón (hay productos que no entran en un cajón).
  final int? idContenedorActivo;
  final int? cajonAnteriorCerrado;
}

/// Devuelto por `CajonSelectorScreen` cuando el operario elige explícitamente
/// pickear sin cajón, a diferencia de `null` (cancelado / sin cambios) o un
/// `ContenedorPicking` (cajón elegido) — los tres casos requieren manejo
/// distinto en quien llama a la pantalla (ver `ZonaSelectorScreen` y
/// `PickingTrabajoScreen._cambiarCajon`).
class SinCajonSeleccionado {
  const SinCajonSeleccionado();
}

/// Tarea de "devolución"/despickeo — `picking_despickeo_tareas` (ver
/// `subpedido_despickeo_service.py::listar_mis_tareas_despickeo`). Se genera
/// server-side cuando un cambio en Ventas (cantidad, producto, regla de
/// fulfillment) deja sin sentido algo que YA se había pickeado físicamente:
/// alguien tiene que sacarlo del cajón de armado y llevarlo a la ubicación
/// de reacomodo indicada. Solo le llegan al operario que estaba pickeando
/// esa zona cuando se generó la tarea (`id_usuario_operario` en el backend).
class TareaDespickeo {
  TareaDespickeo({
    required this.idDespickeoTarea,
    required this.idPedidoSubpedidoItem,
    required this.idStockReservaDetalle,
    required this.idPedidoSubpedido,
    required this.idPedido,
    this.codigoPedido,
    this.clienteNombre,
    required this.idProducto,
    required this.productoNombre,
    this.productoCodigo,
    required this.idUnidadMedida,
    required this.unidadNombre,
    required this.unidadSimbolo,
    required this.cantidad,
    required this.estado,
    this.ubicacionDestinoCodigo,
    this.ubicacionDestinoNombre,
  });

  factory TareaDespickeo.fromJson(Map<String, dynamic> j) => TareaDespickeo(
    idDespickeoTarea: j['id_despickeo_tarea'] as int,
    idPedidoSubpedidoItem: j['id_pedido_subpedido_item'] as int,
    idStockReservaDetalle: j['id_stock_reserva_detalle'] as int,
    idPedidoSubpedido: j['id_pedido_subpedido'] as int,
    idPedido: j['id_pedido'] as int,
    codigoPedido: j['codigo_pedido'] as String?,
    clienteNombre: j['cliente_nombre'] as String?,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    productoCodigo: j['producto_codigo'] as String?,
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadNombre: j['unidad_nombre'] as String? ?? '',
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    cantidad: parseDouble(j['cantidad']),
    estado: j['estado'] as String? ?? 'PENDIENTE',
    ubicacionDestinoCodigo: j['ubicacion_destino_codigo'] as String?,
    ubicacionDestinoNombre: j['ubicacion_destino_nombre'] as String?,
  );

  final int idDespickeoTarea;
  final int idPedidoSubpedidoItem;
  final int idStockReservaDetalle;
  final int idPedidoSubpedido;
  final int idPedido;
  final String? codigoPedido;
  final String? clienteNombre;
  final int idProducto;
  final String productoNombre;
  final String? productoCodigo;
  final int idUnidadMedida;
  final String unidadNombre;
  final String unidadSimbolo;
  final double cantidad;

  /// Siempre 'PENDIENTE' en el listado (el backend solo devuelve pendientes).
  final String estado;
  final String? ubicacionDestinoCodigo;
  final String? ubicacionDestinoNombre;
}

/// Config efectiva de Picking (Ajustes -> Operaciones -> Picking,
/// `GET /picking-operario/config?id_pedido_subpedido=`) para el almacén real
/// de un subpedido — ver `picking_config_service.py` en el backend. El
/// servidor sigue siendo la fuente de verdad (devuelve 400 igual si se
/// ignora); esto es solo para que la UI no ofrezca acciones que van a
/// rechazarse (usa/no contenedor, cajón obligatorio, pickeo parcial,
/// cancelar/modificar/devolver y si esas acciones piden credenciales de
/// supervisor). `usaContenedor=false` es el maestro: cuando está apagado,
/// `cajonObligatorio` siempre viene en `false` (el backend lo garantiza) y
/// la app no debe ofrecer elegir/escanear un cajón en ningún lado.
///
/// `escaneoZonaObligatorio` es la ÚNICA excepción a "el servidor sigue
/// siendo la fuente de verdad": no hay invariante persistida que audite si
/// la zona se escaneó o se tocó, así que `ZonaSelectorScreen` es el único
/// lugar que la exige — ver ese archivo.
class PickingConfig {
  const PickingConfig({
    required this.pickingHabilitado,
    required this.escaneoZonaObligatorio,
    required this.ubicacionProductoHabilitada,
    required this.escaneoUbicacionObligatorio,
    required this.usaContenedor,
    required this.cajonObligatorio,
    required this.escaneoProductoHabilitado,
    required this.escaneoProductoObligatorio,
    required this.permitePickeoParcial,
    required this.ajusteAutomaticoPesoHabilitado,
    required this.permiteModificarCantidad,
    required this.modificarCantidadRequiereSupervisor,
    required this.permiteCancelarTarea,
    required this.cancelarRequiereSupervisor,
    required this.permiteDevolverItem,
    required this.sesionIdleTimeoutMinutos,
  });

  factory PickingConfig.fromJson(Map<String, dynamic> j) => PickingConfig(
    pickingHabilitado: j['picking_habilitado'] as bool? ?? true,
    escaneoZonaObligatorio: j['escaneo_zona_obligatorio'] as bool? ?? false,
    ubicacionProductoHabilitada: j['ubicacion_producto_habilitada'] as bool? ?? false,
    escaneoUbicacionObligatorio: j['escaneo_ubicacion_obligatorio'] as bool? ?? false,
    usaContenedor: j['usa_contenedor'] as bool? ?? true,
    cajonObligatorio: j['cajon_obligatorio'] as bool? ?? false,
    escaneoProductoHabilitado: j['escaneo_producto_habilitado'] as bool? ?? false,
    escaneoProductoObligatorio: j['escaneo_producto_obligatorio'] as bool? ?? false,
    permitePickeoParcial: j['permite_pickeo_parcial'] as bool? ?? true,
    ajusteAutomaticoPesoHabilitado: j['ajuste_automatico_peso_habilitado'] as bool? ?? true,
    permiteModificarCantidad: j['permite_modificar_cantidad'] as bool? ?? true,
    modificarCantidadRequiereSupervisor: j['modificar_cantidad_requiere_supervisor'] as bool? ?? true,
    permiteCancelarTarea: j['permite_cancelar_tarea'] as bool? ?? true,
    cancelarRequiereSupervisor: j['cancelar_requiere_supervisor'] as bool? ?? true,
    permiteDevolverItem: j['permite_devolver_item'] as bool? ?? true,
    sesionIdleTimeoutMinutos: j['sesion_idle_timeout_minutos'] as int? ?? 10,
  );

  final bool pickingHabilitado;
  final bool escaneoZonaObligatorio;

  /// Maestro de [escaneoUbicacionObligatorio] — ver docstring de
  /// `ubicacion_producto_habilitada` en picking_config_service.py.
  final bool ubicacionProductoHabilitada;
  final bool escaneoUbicacionObligatorio;
  final bool usaContenedor;
  final bool cajonObligatorio;

  /// Maestro de [escaneoProductoObligatorio] — a diferencia de las demás
  /// reglas de escaneo de esta clase, ÉSTA sí tiene invariante persistida:
  /// el servidor vuelve a validar el código escaneado en `completar_tarea`
  /// si `escaneoProductoObligatorio` está prendido (ver
  /// `TareaPicking.codigosBarra`/`tieneCodigoBarras`).
  final bool escaneoProductoHabilitado;
  final bool escaneoProductoObligatorio;
  final bool permitePickeoParcial;
  final bool ajusteAutomaticoPesoHabilitado;
  final bool permiteModificarCantidad;
  final bool modificarCantidadRequiereSupervisor;
  final bool permiteCancelarTarea;
  final bool cancelarRequiereSupervisor;
  final bool permiteDevolverItem;
  final int sesionIdleTimeoutMinutos;
}

/// `POST /picking-operario/tarea/{id}/cancelar`.
class CancelarTareaResultado {
  CancelarTareaResultado({
    required this.idStockReservaDetalle,
    this.supervisorEmail,
    required this.subpedidoAvanzadoAControl,
  });

  factory CancelarTareaResultado.fromJson(Map<String, dynamic> j) => CancelarTareaResultado(
    idStockReservaDetalle: j['id_stock_reserva_detalle'] as int,
    supervisorEmail: j['supervisor_email'] as String?,
    subpedidoAvanzadoAControl: j['subpedido_avanzado_a_control'] as bool? ?? false,
  );

  final int idStockReservaDetalle;
  final String? supervisorEmail;
  final bool subpedidoAvanzadoAControl;
}

/// `POST /picking-operario/tarea/{id}/modificar-cantidad`.
class ModificarCantidadResultado {
  ModificarCantidadResultado({
    required this.idStockReservaDetalle,
    required this.cantidadAnterior,
    required this.cantidadNueva,
  });

  factory ModificarCantidadResultado.fromJson(Map<String, dynamic> j) => ModificarCantidadResultado(
    idStockReservaDetalle: j['id_stock_reserva_detalle'] as int,
    cantidadAnterior: parseDouble(j['cantidad_anterior']),
    cantidadNueva: parseDouble(j['cantidad_nueva']),
  );

  final int idStockReservaDetalle;
  final double cantidadAnterior;
  final double cantidadNueva;
}

/// Ítem de `GET /picking-operario/cajon/{id}/items` — a diferencia de
/// [ItemContenedor] (solo lectura, del buscador genérico), este trae
/// `idPickingItem`/`puedeDevolver`, necesarios para poder devolverlo.
class ItemPickeadoCajon {
  ItemPickeadoCajon({
    required this.idPickingItem,
    required this.idStockReservaDetalle,
    required this.idProducto,
    required this.productoNombre,
    this.productoCodigo,
    this.unidadSimbolo,
    required this.cantidadPickeada,
    required this.puedeDevolver,
  });

  factory ItemPickeadoCajon.fromJson(Map<String, dynamic> j) => ItemPickeadoCajon(
    idPickingItem: j['id_picking_item'] as int,
    idStockReservaDetalle: j['id_stock_reserva_detalle'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    productoCodigo: j['producto_codigo'] as String?,
    unidadSimbolo: j['unidad_simbolo'] as String?,
    cantidadPickeada: parseDouble(j['cantidad_pickeada']),
    puedeDevolver: j['puede_devolver'] as bool? ?? false,
  );

  final int idPickingItem;
  final int idStockReservaDetalle;
  final int idProducto;
  final String productoNombre;
  final String? productoCodigo;
  final String? unidadSimbolo;
  final double cantidadPickeada;

  /// `false` si el subpedido ya tiene una sesión de control EN_PROCESO o
  /// COMPLETADO — a partir de ahí devolver rompería lo que control ya
  /// revisó (ver `tiene_control_activo` en `get_cajon_items`, backend).
  final bool puedeDevolver;
}

/// `GET /picking-operario/cajon/{id}/items`.
class CajonItemsResponse {
  CajonItemsResponse({required this.idContenedor, required this.identificador, required this.items});

  factory CajonItemsResponse.fromJson(Map<String, dynamic> j) => CajonItemsResponse(
    idContenedor: j['contenedor']['id_contenedor'] as int,
    identificador: j['contenedor']['identificador'] as String? ?? '',
    items: (j['items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(ItemPickeadoCajon.fromJson)
        .toList(),
  );

  final int idContenedor;
  final String identificador;
  final List<ItemPickeadoCajon> items;
}

/// `POST /picking-operario/picking-item/{id}/devolver`.
class DevolverItemResultado {
  DevolverItemResultado({
    required this.idPickingItem,
    required this.cantidadDevuelta,
    required this.cantidadMantenida,
  });

  factory DevolverItemResultado.fromJson(Map<String, dynamic> j) => DevolverItemResultado(
    idPickingItem: j['id_picking_item'] as int,
    cantidadDevuelta: parseDouble(j['cantidad_devuelta']),
    cantidadMantenida: parseDouble(j['cantidad_mantenida']),
  );

  final int idPickingItem;
  final double cantidadDevuelta;
  final double cantidadMantenida;
}

/// `POST /picking-operario/despickeo/{id}/confirmar`.
class ConfirmarDespickeoResultado {
  ConfirmarDespickeoResultado({
    required this.idDespickeoTarea,
    required this.cantidad,
    required this.idExistenciaDestino,
  });

  factory ConfirmarDespickeoResultado.fromJson(Map<String, dynamic> j) => ConfirmarDespickeoResultado(
    idDespickeoTarea: j['id_despickeo_tarea'] as int,
    cantidad: parseDouble(j['cantidad']),
    idExistenciaDestino: j['id_existencia_destino'] as int,
  );

  final int idDespickeoTarea;
  final double cantidad;
  final int idExistenciaDestino;
}
