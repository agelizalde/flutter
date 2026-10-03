import '../../../core/utils/parsing.dart';

/// Detalle de una excepción de cantidad en recepción de OC para la pantalla
/// de Firmas — espejo de `header`+`items` de `GET /recepciones/exceso-oc/
/// {id}` (ver `obtener_exceso` en `recepcion_oc_actualizacion_service.py`).
/// A diferencia de `OC_DIFERENCIA_PESO`, acá lo que difiere es la cantidad
/// recibida contra el saldo pendiente de la OC (no el peso de un bulto ya
/// contado), y aprobarla sí actualiza `cantidad_solicitada` del ítem de OC.
class OcExcesoCantidadDetalle {
  OcExcesoCantidadDetalle({required this.header, required this.items});

  factory OcExcesoCantidadDetalle.fromJson(Map<String, dynamic> j) => OcExcesoCantidadDetalle(
    header: OcExcesoCantidadHeader.fromJson(j['header'] as Map<String, dynamic>),
    items: (j['items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(OcExcesoCantidadItem.fromJson)
        .toList(),
  );

  final OcExcesoCantidadHeader header;
  final List<OcExcesoCantidadItem> items;
}

class OcExcesoCantidadHeader {
  OcExcesoCantidadHeader({
    required this.idOc,
    this.ocCodigo,
    required this.proveedorNombre,
    required this.monedaSimbolo,
    this.solicitanteUsername,
    required this.solicitadoEn,
    this.resolutorUsername,
    this.resueltoEn,
    this.motivo,
    required this.totalAnterior,
    required this.totalNuevo,
  });

  factory OcExcesoCantidadHeader.fromJson(Map<String, dynamic> j) => OcExcesoCantidadHeader(
    idOc: j['id_oc'] as int,
    ocCodigo: j['oc_codigo'] as String?,
    proveedorNombre: j['oc_proveedor_nombre'] as String? ?? '—',
    monedaSimbolo: j['moneda_simbolo'] as String? ?? 'Gs.',
    solicitanteUsername: j['solicitante_username'] as String?,
    solicitadoEn: parseDateOrNull(j['solicitado_en']) ?? DateTime.now(),
    resolutorUsername: j['resolutor_username'] as String?,
    resueltoEn: parseDateOrNull(j['resuelto_en']),
    motivo: j['motivo'] as String?,
    totalAnterior: parseDouble(j['total_anterior']),
    totalNuevo: parseDouble(j['total_nuevo']),
  );

  final int idOc;
  final String? ocCodigo;
  final String proveedorNombre;
  final String monedaSimbolo;
  final String? solicitanteUsername;
  final DateTime solicitadoEn;
  final String? resolutorUsername;
  final DateTime? resueltoEn;
  final String? motivo;
  final double totalAnterior;
  final double totalNuevo;

  String get ocCodigoDisplay => ocCodigo ?? 'OC #$idOc';
}

class OcExcesoCantidadItem {
  OcExcesoCantidadItem({
    required this.idProducto,
    required this.productoNombre,
    required this.unidadNombre,
    required this.cantidadOcOriginal,
    required this.saldoPendiente,
    required this.cantidadRecibidaActual,
    required this.cantidadExceso,
    required this.cantidadOcNueva,
    required this.ocPrecioUnitario,
    required this.totalLineaOriginal,
  });

  factory OcExcesoCantidadItem.fromJson(Map<String, dynamic> j) => OcExcesoCantidadItem(
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '—',
    unidadNombre: j['unidad_nombre'] as String? ?? '',
    cantidadOcOriginal: parseDouble(j['cantidad_oc_original']),
    saldoPendiente: parseDouble(j['saldo_pendiente']),
    cantidadRecibidaActual: parseDouble(j['cantidad_recibida_actual']),
    cantidadExceso: parseDouble(j['cantidad_exceso']),
    cantidadOcNueva: parseDouble(j['cantidad_oc_nueva']),
    ocPrecioUnitario: parseDoubleOrNull(j['oc_precio_unitario']),
    totalLineaOriginal: parseDoubleOrNull(j['total_linea_original']),
  );

  final int idProducto;
  final String productoNombre;
  final String unidadNombre;
  final double cantidadOcOriginal;
  final double saldoPendiente;
  final double cantidadRecibidaActual;
  final double cantidadExceso;
  final double cantidadOcNueva;
  final double? ocPrecioUnitario;
  final double? totalLineaOriginal;
}
