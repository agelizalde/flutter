import '../../../core/utils/parsing.dart';

/// Header de `recepcion` (ver `recepcion_service.py:_build_recepcion_full_query`).
class Recepcion {
  Recepcion({
    required this.idRecepcion,
    required this.idProveedor,
    required this.proveedorNombre,
    this.fechaRecepcion,
    required this.origenRecepcion,
    this.observacion,
    required this.idAlmacen,
    required this.almacenNombre,
    this.idUbicacionRecepcion,
    this.ubicacionRecepcionNombre,
    required this.estado,
    required this.requiereControl,
    required this.itemsActivos,
    required this.totalCantidad,
    required this.rowVersion,
    this.receptorUsername,
    this.usuarioControlUsername,
  });

  factory Recepcion.fromJson(Map<String, dynamic> j) => Recepcion(
    idRecepcion: j['id_recepcion'] as int,
    idProveedor: j['id_proveedor'] as int,
    proveedorNombre:
        (j['proveedor_nombre_comercial'] as String?)?.trim().isNotEmpty == true
        ? j['proveedor_nombre_comercial'] as String
        : (j['proveedor_razon_social'] as String? ?? ''),
    fechaRecepcion: parseDateOrNull(j['fecha_recepcion']),
    origenRecepcion: j['origen_recepcion'] as String? ?? 'MANUAL',
    observacion: j['observacion'] as String?,
    idAlmacen: j['id_almacen'] as int,
    almacenNombre: j['almacen_nombre'] as String? ?? '',
    idUbicacionRecepcion: j['id_ubicacion_recepcion'] as int?,
    ubicacionRecepcionNombre: j['ubicacion_recepcion_nombre'] as String?,
    estado: j['estado'] as String? ?? 'BORRADOR',
    requiereControl: j['requiere_control'] as bool? ?? false,
    itemsActivos: j['items_activos'] as int? ?? 0,
    totalCantidad: parseDouble(j['total_cantidad']),
    rowVersion: j['row_version'] as int,
    receptorUsername: j['receptor_username'] as String?,
    usuarioControlUsername: j['usuario_control_username'] as String?,
  );

  final int idRecepcion;
  final int idProveedor;
  final String proveedorNombre;
  final DateTime? fechaRecepcion;
  final String origenRecepcion;
  final String? observacion;
  final int idAlmacen;
  final String almacenNombre;
  final int? idUbicacionRecepcion;
  final String? ubicacionRecepcionNombre;
  final String estado;
  final bool requiereControl;
  final int itemsActivos;
  final double totalCantidad;
  final int rowVersion;

  /// Quién recepcionó (`receptor_username`).
  final String? receptorUsername;

  /// Quién controló (`usuario_control_username`) — `null` hasta que se
  /// resuelve un control sobre esta recepción.
  final String? usuarioControlUsername;
}

/// Resultado de la evaluación de diferencia de peso que el backend agrega a
/// la respuesta de agregar/editar un ítem de recepción pesable (ver
/// `recepcion_item_service.py`, campo `diferencia_peso`) — `null` si el ítem
/// no viene de una OC o su unidad no requiere pesaje. `estado` es
/// 'SIN_DIFERENCIA' | 'NO_REQUERIDA' | 'PENDIENTE'; solo 'PENDIENTE' bloquea
/// la confirmación de la recepción hasta resolverse desde Firmas.
class DiferenciaPesoResultado {
  DiferenciaPesoResultado({required this.estado, this.porcentajeDiferencia});

  factory DiferenciaPesoResultado.fromJson(Map<String, dynamic> j) => DiferenciaPesoResultado(
    estado: j['estado'] as String,
    porcentajeDiferencia: j['porcentaje_diferencia'] != null
        ? parseDouble(j['porcentaje_diferencia'])
        : null,
  );

  final String estado;
  final double? porcentajeDiferencia;

  bool get pendiente => estado == 'PENDIENTE';
}

/// Resultado de la evaluación de exceso de cantidad que el backend agrega a
/// la respuesta de agregar/editar un ítem de recepción NO pesable de una OC
/// (ver `recepcion_item_service.py`/`recepcion_oc_actualizacion_service.py`,
/// campo `exceso_cantidad`) — `null` si el ítem no viene de una OC, si su
/// unidad requiere pesaje (ese caso usa `diferencia_peso`) o si no superó lo
/// pendiente. `estado` es 'NO_REQUERIDA' | 'PENDIENTE'; solo 'PENDIENTE'
/// bloquea la confirmación de la recepción hasta resolverse desde Firmas.
class ExcesoCantidadResultado {
  ExcesoCantidadResultado({required this.estado, this.porcentajeVariacion});

  factory ExcesoCantidadResultado.fromJson(Map<String, dynamic> j) => ExcesoCantidadResultado(
    estado: j['estado'] as String,
    porcentajeVariacion: j['porcentaje_variacion'] != null
        ? parseDouble(j['porcentaje_variacion'])
        : null,
  );

  final String estado;
  final double? porcentajeVariacion;

  bool get pendiente => estado == 'PENDIENTE';
}

/// Fila de `recepcion_items` (ver `recepcion_item_service.py:_build_item_query`).
class RecepcionItem {
  RecepcionItem({
    required this.idRecepcionItem,
    required this.idRecepcion,
    required this.idProducto,
    required this.productoNombre,
    required this.requiereLote,
    required this.requiereVencimiento,
    required this.requiereFaena,
    this.vidaUtilDias,
    required this.idUnidadMedida,
    required this.unidadSimbolo,
    required this.cantidad,
    this.cantidadRechazada = 0,
    this.loteProveedor,
    this.fechaVencimiento,
    this.fechaFaenado,
    this.observacion,
    this.observacionRechazo,
    this.idOrdenCompraItem,
    required this.rowVersion,
    this.diferenciaPeso,
    this.excesoCantidad,
  });

  factory RecepcionItem.fromJson(Map<String, dynamic> j) => RecepcionItem(
    idRecepcionItem: j['id_recepcion_item'] as int,
    idRecepcion: j['id_recepcion'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    // A diferencia de `almacenaje` en GET /productos/{id} (que devuelve
    // 0/1), este endpoint serializa estos flags como bool real.
    requiereLote: j['requiere_lote'] as bool? ?? false,
    requiereVencimiento: j['requiere_vencimiento'] as bool? ?? false,
    requiereFaena: j['requiere_faena'] as bool? ?? false,
    vidaUtilDias: j['vida_util_dias'] as int?,
    // Unidad de registro — siempre la base del producto.
    idUnidadMedida: j['id_unidad_medida'] as int,
    unidadSimbolo: j['unidad_simbolo'] as String? ?? '',
    cantidad: parseDouble(j['cantidad']),
    cantidadRechazada: parseDouble(j['cantidad_rechazada']),
    loteProveedor: j['lote_proveedor'] as String?,
    fechaVencimiento: parseDateOrNull(j['fecha_vencimiento']),
    fechaFaenado: parseDateOrNull(j['fecha_faenado']),
    observacion: j['observacion'] as String?,
    observacionRechazo: j['observacion_rechazo'] as String?,
    idOrdenCompraItem: j['id_orden_compra_item'] as int?,
    rowVersion: j['row_version'] as int,
    diferenciaPeso: j['diferencia_peso'] != null
        ? DiferenciaPesoResultado.fromJson(j['diferencia_peso'] as Map<String, dynamic>)
        : null,
    excesoCantidad: j['exceso_cantidad'] != null
        ? ExcesoCantidadResultado.fromJson(j['exceso_cantidad'] as Map<String, dynamic>)
        : null,
  );

  final int idRecepcionItem;
  final int idRecepcion;
  final int idProducto;
  final String productoNombre;
  final bool requiereLote;
  final bool requiereVencimiento;
  final bool requiereFaena;
  final int? vidaUtilDias;
  final int idUnidadMedida;
  final String unidadSimbolo;
  final double cantidad;
  final double cantidadRechazada;

  final String? loteProveedor;
  final DateTime? fechaVencimiento;
  final DateTime? fechaFaenado;
  final String? observacion;
  final String? observacionRechazo;
  final int? idOrdenCompraItem;
  final int rowVersion;

  /// Solo viene seteado en la respuesta de agregar/editar un ítem pesable —
  /// no en `GET /recepciones/{id}/items` (ver nota en `recepcion_item_service.py`).
  final DiferenciaPesoResultado? diferenciaPeso;

  /// Solo viene seteado en la respuesta de agregar/editar un ítem NO pesable
  /// de una OC que superó lo pendiente — no en `GET /recepciones/{id}/items`.
  final ExcesoCantidadResultado? excesoCantidad;
}

/// Recepción + sus ítems + su control de calidad (si tuvo), lo que necesita
/// la pantalla de detalle.
class RecepcionDetalle {
  RecepcionDetalle({
    required this.recepcion,
    required this.items,
    this.control,
  });

  final Recepcion recepcion;
  final List<RecepcionItem> items;
  final ControlRecepcion? control;
}

/// Cantidades de un ítem dentro de un control de recepción (ver
/// `recepcion_ver.py::_get_control_recepcion`): lo que se pretendía
/// recibir, lo que efectivamente se recibió, y lo que se rechazó.
class ControlRecepcionItem {
  ControlRecepcionItem({
    required this.idRecepcionControlItem,
    required this.idRecepcionItem,
    required this.productoNombre,
    required this.cantidadPretendida,
    required this.cantidadRecibida,
    required this.cantidadRechazada,
  });

  factory ControlRecepcionItem.fromJson(Map<String, dynamic> j) =>
      ControlRecepcionItem(
        idRecepcionControlItem: j['id_recepcion_control_item'] as int,
        idRecepcionItem: j['id_recepcion_item'] as int,
        productoNombre: j['producto_nombre'] as String? ?? '',
        cantidadPretendida: parseDouble(j['cantidad_pretendida']),
        cantidadRecibida: parseDouble(j['cantidad_recibida']),
        cantidadRechazada: parseDouble(j['cantidad_rechazada']),
      );

  final int idRecepcionControlItem;
  final int idRecepcionItem;
  final String productoNombre;
  final double cantidadPretendida;
  final double cantidadRecibida;
  final double cantidadRechazada;
}

/// Control de calidad de una recepción — quién recepcionó, quién controló,
/// resultado (si ya se resolvió) y el desglose por ítem. `null` si la
/// recepción nunca requirió control.
class ControlRecepcion {
  ControlRecepcion({
    required this.idRecepcionControl,
    required this.estado,
    this.resultado,
    this.observacion,
    this.usuarioControloUsername,
    this.usuarioControladoUsername,
    required this.items,
  });

  factory ControlRecepcion.fromJson(Map<String, dynamic> j) =>
      ControlRecepcion(
        idRecepcionControl: j['id_recepcion_control'] as int,
        estado: j['estado'] as String? ?? 'PENDIENTE',
        resultado: j['resultado'] as String?,
        observacion: j['observacion'] as String?,
        usuarioControloUsername: j['usuario_controlo_username'] as String?,
        usuarioControladoUsername:
            j['usuario_controlado_username'] as String?,
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => ControlRecepcionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final int idRecepcionControl;

  /// 'PENDIENTE' | 'CONTROLADO'
  final String estado;

  /// 'POSITIVO' | 'NEGATIVO' | null mientras está PENDIENTE.
  final String? resultado;
  final String? observacion;
  final String? usuarioControloUsername;
  final String? usuarioControladoUsername;
  final List<ControlRecepcionItem> items;
}

/// Resultado de `POST /recepciones/{id}/confirmar` (ver
/// `recepcion_confirmacion.py:recepcion_confirmar`).
class ConfirmarRecepcionResultado {
  ConfirmarRecepcionResultado({
    required this.accion,
    required this.recepcion,
    this.ingreso,
  });

  factory ConfirmarRecepcionResultado.fromJson(Map<String, dynamic> j) =>
      ConfirmarRecepcionResultado(
        accion: j['accion'] as String,
        recepcion: Recepcion.fromJson(j['recepcion'] as Map<String, dynamic>),
        ingreso: j['ingreso'] != null
            ? IngresoResumen.fromJson(j['ingreso'] as Map<String, dynamic>)
            : null,
      );

  /// 'confirmada_e_ingresada' | 'confirmada_con_control'
  final String accion;
  final Recepcion recepcion;
  final IngresoResumen? ingreso;
}

class IngresoResumen {
  IngresoResumen({required this.countItems});

  factory IngresoResumen.fromJson(Map<String, dynamic> j) =>
      IngresoResumen(countItems: j['count_items'] as int? ?? 0);

  final int countItems;
}

/// Fila de `GET /almacenes` (ver `ubicacion_almacen_rout.py`).
class AlmacenSimple {
  AlmacenSimple({
    required this.idAlmacen,
    required this.nombre,
    required this.codigo,
  });

  factory AlmacenSimple.fromJson(Map<String, dynamic> j) => AlmacenSimple(
    idAlmacen: j['id_almacen'] as int,
    nombre: j['nombre'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
  );

  final int idAlmacen;
  final String nombre;
  final String codigo;
}

/// Fila de `GET /recepciones/control/pendientes` (ver
/// `recepcion_control_service.py:recepcion_control_list_pendientes`) —
/// solo lo necesario para encontrar el `id_recepcion_control` de una
/// recepción puntual.
class RecepcionControlPendiente {
  RecepcionControlPendiente({required this.idRecepcionControl, required this.idRecepcion});

  factory RecepcionControlPendiente.fromJson(Map<String, dynamic> j) => RecepcionControlPendiente(
    idRecepcionControl: j['id_recepcion_control'] as int,
    idRecepcion: j['id_recepcion'] as int,
  );

  final int idRecepcionControl;
  final int idRecepcion;
}

/// Fila de `GET /ubicaciones` (ver `ubicacion_rout.py`), filtrada a
/// `tipo_ubicacion=RECEPCION` para el selector de ubicación de recepción.
class UbicacionSimple {
  UbicacionSimple({
    required this.idUbicacion,
    required this.nombre,
    required this.codigo,
    this.idZona,
    this.idAlmacen,
  });

  factory UbicacionSimple.fromJson(Map<String, dynamic> j) => UbicacionSimple(
    idUbicacion: j['id_ubicacion'] as int,
    nombre: j['nombre'] as String? ?? '',
    codigo: j['codigo'] as String? ?? '',
    idZona: j['id_zona'] as int?,
    idAlmacen: j['id_almacen'] as int?,
  );

  final int idUbicacion;
  final String nombre;
  final String codigo;

  /// Presentes cuando viene de `GET /ubicaciones` (búsqueda genérica) —
  /// `null` cuando viene de `listarDeRecepcion` (no los necesita). Ajuste
  /// de Stock los necesita para armar el header (`id_zona`/`id_almacen`
  /// son obligatorios ahí, no solo `id_ubicacion`).
  final int? idZona;
  final int? idAlmacen;
}
