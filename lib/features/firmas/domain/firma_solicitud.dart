import '../../../core/utils/parsing.dart';

/// Código de `firmas_documentos_tipo` para la confirmación de entrega de un
/// pedido (ver `firmas_config_default.py`) — el único tipo con vista propia
/// en esta app (lista y detalle), ver [FirmaSolicitud.esPedidoEntrega].
const tipoPedidoEntrega = 'PEDIDO_ENTREGA';

/// Código de `firmas_documentos_tipo` para una orden de compra (ver
/// `firmas_config_default.py`) — segundo tipo con vista propia en el
/// detalle, ver [FirmaSolicitud.esOrdenCompra].
const tipoOrdenCompra = 'OC';

/// Código de `firmas_documentos_tipo` para una orden de pago (ver
/// `firmas_config_default.py`) — sin vista propia en el detalle (usa el
/// genérico monto/regla/motivo, ver `_DatosCard`), pero con la misma fila
/// "Proveedor - Solicitante" / "N° - Fecha" que [tipoOrdenCompra] en la
/// pantalla de pendientes, ver [FirmaSolicitud.esOrdenPago].
const tipoOrdenPago = 'OP';

/// Código de `firmas_documentos_tipo` para una diferencia de peso detectada
/// al recibir una OC (ver `recepcion_diferencia_peso_service.py`) — tercer
/// tipo con vista propia, ver [FirmaSolicitud.esDiferenciaPeso].
const tipoDiferenciaPeso = 'OC_DIFERENCIA_PESO';

/// Código de `firmas_documentos_tipo` para una excepción de cantidad
/// detectada al recibir una OC (ver `recepcion_oc_actualizacion_service.py`)
/// — cuarto tipo con vista propia, ver [FirmaSolicitud.esExcesoCantidad].
const tipoExcesoCantidad = 'OC_EXCESO_CANTIDAD';

/// Espejo de una fila de `firmas_solicitudes` (ver `_base_select` en
/// `firmas_solicitudes.py`). Esta app solo consume el flujo de resolución
/// (ver/aprobar/rechazar) — crear solicitudes, tipos de documento y reglas
/// siguen siendo exclusivos de la web (`/firmas/*` en el ERP).
class FirmaSolicitud {
  FirmaSolicitud({
    required this.idFirmaSolicitud,
    required this.idDocumentoTipo,
    required this.documentoTipoCodigo,
    required this.documentoTipoNombre,
    this.documentoTipoPermisoFallback,
    required this.idDocumento,
    required this.monto,
    this.porcentajeVariacion,
    this.idRegla,
    this.reglaNombre,
    required this.estado,
    this.idUsuarioSolicitante,
    this.solicitanteUsername,
    required this.fechaSolicitud,
    this.idUsuarioResolutor,
    this.resolutorUsername,
    this.fechaResolucion,
    this.motivo,
    required this.rowVersion,
    this.documentoCodigo,
    this.documentoProveedorNombre,
    this.puedeFirmarYo = false,
  });

  factory FirmaSolicitud.fromJson(Map<String, dynamic> j) => FirmaSolicitud(
    idFirmaSolicitud: j['id_firma_solicitud'] as int,
    idDocumentoTipo: j['id_documento_tipo'] as int,
    documentoTipoCodigo: j['documento_tipo_codigo'] as String? ?? '',
    documentoTipoNombre: j['documento_tipo_nombre'] as String? ?? '',
    documentoTipoPermisoFallback: j['documento_tipo_permiso_fallback'] as String?,
    idDocumento: j['id_documento'] as int,
    monto: parseDouble(j['monto']),
    porcentajeVariacion: parseDoubleOrNull(j['porcentaje_variacion']),
    idRegla: j['id_regla'] as int?,
    reglaNombre: j['regla_nombre'] as String?,
    estado: j['estado'] as String? ?? '',
    idUsuarioSolicitante: j['id_usuario_solicitante'] as int?,
    solicitanteUsername: j['solicitante_username'] as String?,
    fechaSolicitud: parseDateOrNull(j['fecha_solicitud']) ?? DateTime.now(),
    idUsuarioResolutor: j['id_usuario_resolutor'] as int?,
    resolutorUsername: j['resolutor_username'] as String?,
    fechaResolucion: parseDateOrNull(j['fecha_resolucion']),
    motivo: j['motivo'] as String?,
    rowVersion: j['row_version'] as int? ?? 1,
    // Solo vienen en `solicitudes_list` (enriquecido por
    // `_enriquecer_con_resumen`), no en `solicitudes_get` — quedan en
    // `null` en el detalle, que ya cae al formato genérico.
    documentoCodigo: j['documento_codigo'] as String?,
    documentoProveedorNombre: j['documento_proveedor_nombre'] as String?,
  );

  final int idFirmaSolicitud;
  final int idDocumentoTipo;
  final String documentoTipoCodigo;
  final String documentoTipoNombre;
  final String? documentoTipoPermisoFallback;
  final int idDocumento;
  final double monto;
  final double? porcentajeVariacion;
  final int? idRegla;
  final String? reglaNombre;
  final String estado;
  final int? idUsuarioSolicitante;
  final String? solicitanteUsername;
  final DateTime fechaSolicitud;
  final int? idUsuarioResolutor;
  final String? resolutorUsername;
  final DateTime? fechaResolucion;
  final String? motivo;
  final int rowVersion;
  final String? documentoCodigo;
  final String? documentoProveedorNombre;

  /// Calculado en el cliente, no viene del backend — ver
  /// `firmas_providers.dart` (mismo criterio que `FirmasPendientesPage.jsx`
  /// en la web: mi rol está habilitado en la regla que matcheó, o la
  /// solicitud cayó al permiso de fallback y yo tengo ese permiso).
  final bool puedeFirmarYo;

  bool get pendiente => estado == 'PENDIENTE';

  bool get esPedidoEntrega => documentoTipoCodigo == tipoPedidoEntrega;

  bool get esOrdenCompra => documentoTipoCodigo == tipoOrdenCompra;

  bool get esOrdenPago => documentoTipoCodigo == tipoOrdenPago;

  bool get esDiferenciaPeso => documentoTipoCodigo == tipoDiferenciaPeso;

  bool get esExcesoCantidad => documentoTipoCodigo == tipoExcesoCantidad;

  String get titulo => documentoCodigo ?? '$documentoTipoNombre #$idDocumento';

  FirmaSolicitud copyWith({bool? puedeFirmarYo}) => FirmaSolicitud(
    idFirmaSolicitud: idFirmaSolicitud,
    idDocumentoTipo: idDocumentoTipo,
    documentoTipoCodigo: documentoTipoCodigo,
    documentoTipoNombre: documentoTipoNombre,
    documentoTipoPermisoFallback: documentoTipoPermisoFallback,
    idDocumento: idDocumento,
    monto: monto,
    porcentajeVariacion: porcentajeVariacion,
    idRegla: idRegla,
    reglaNombre: reglaNombre,
    estado: estado,
    idUsuarioSolicitante: idUsuarioSolicitante,
    solicitanteUsername: solicitanteUsername,
    fechaSolicitud: fechaSolicitud,
    idUsuarioResolutor: idUsuarioResolutor,
    resolutorUsername: resolutorUsername,
    fechaResolucion: fechaResolucion,
    motivo: motivo,
    rowVersion: rowVersion,
    documentoCodigo: documentoCodigo,
    documentoProveedorNombre: documentoProveedorNombre,
    puedeFirmarYo: puedeFirmarYo ?? this.puedeFirmarYo,
  );
}
