import '../../../core/utils/parsing.dart';

/// Detalle de una diferencia de peso en recepción de OC para la pantalla de
/// Firmas — espejo de `header`+`items` de `GET /recepciones/diferencia-peso/
/// {id}` (ver `obtener_diferencia_peso` en `recepcion_diferencia_peso_service
/// .py`). El conteo de bultos ya coincidía con lo pedido en la OC — lo único
/// que difiere es el peso real cargado contra el teórico; por eso no hay un
/// "cantidad a recibir" en el sentido de `OcDetalleItem` (eso es
/// `OC_EXCESO_CANTIDAD`, un tipo de solicitud hermano sin vista propia acá).
class OcDiferenciaPesoDetalle {
  OcDiferenciaPesoDetalle({required this.header, required this.items});

  factory OcDiferenciaPesoDetalle.fromJson(Map<String, dynamic> j) => OcDiferenciaPesoDetalle(
    header: OcDiferenciaPesoHeader.fromJson(j['header'] as Map<String, dynamic>),
    items: (j['items'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(OcDiferenciaPesoItem.fromJson)
        .toList(),
  );

  final OcDiferenciaPesoHeader header;
  final List<OcDiferenciaPesoItem> items;
}

class OcDiferenciaPesoHeader {
  OcDiferenciaPesoHeader({
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

  factory OcDiferenciaPesoHeader.fromJson(Map<String, dynamic> j) => OcDiferenciaPesoHeader(
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

class OcDiferenciaPesoItem {
  OcDiferenciaPesoItem({
    required this.idProducto,
    required this.productoNombre,
    required this.unidadNombre,
    required this.cantidadTeoricaBase,
    required this.cantidadRealBase,
    required this.porcentajeDiferencia,
    required this.ocCantidadSolicitada,
    required this.ocPrecioUnitario,
    required this.totalLineaTeorico,
    required this.totalLineaReal,
  });

  factory OcDiferenciaPesoItem.fromJson(Map<String, dynamic> j) => OcDiferenciaPesoItem(
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '—',
    unidadNombre: j['unidad_base_nombre'] as String? ?? '',
    cantidadTeoricaBase: parseDouble(j['cantidad_teorica_base']),
    cantidadRealBase: parseDouble(j['cantidad_real_base']),
    porcentajeDiferencia: parseDouble(j['porcentaje_diferencia']),
    ocCantidadSolicitada: parseDoubleOrNull(j['oc_cantidad_solicitada']),
    ocPrecioUnitario: parseDoubleOrNull(j['oc_precio_unitario']),
    totalLineaTeorico: parseDoubleOrNull(j['total_linea_teorico']),
    totalLineaReal: parseDoubleOrNull(j['total_linea_real']),
  );

  final int idProducto;
  final String productoNombre;
  final String unidadNombre;
  final double cantidadTeoricaBase;
  final double cantidadRealBase;
  final double porcentajeDiferencia;
  final double? ocCantidadSolicitada;
  final double? ocPrecioUnitario;
  final double? totalLineaTeorico;
  final double? totalLineaReal;
}
