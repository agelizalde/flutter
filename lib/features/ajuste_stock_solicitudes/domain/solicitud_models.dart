import '../../../core/utils/parsing.dart';

/// Solicitud de control de stock (`ajustes_stock_solicitudes`, ver
/// `ajuste_stock_solicitudes_service.py`). Nace PENDIENTE sin ítems -- el
/// operario asignado hace el conteo real con el flujo normal de
/// `NuevoAjusteScreen` y recién ahí se linkea con un `AjusteStock`.
class SolicitudAjusteStock {
  SolicitudAjusteStock({
    required this.idSolicitud,
    required this.idAlmacen,
    required this.idZona,
    required this.idUbicacion,
    required this.ubicacionNombre,
    required this.ubicacionCodigo,
    required this.zonaNombre,
    required this.motivoCategoria,
    this.observaciones,
    required this.estado,
    required this.idUsuarioSolicitante,
    this.solicitanteNombre,
    required this.idUsuarioAsignado,
    this.asignadoNombre,
    this.idAjusteStock,
    this.motivoCancelacion,
    required this.creadoEn,
    required this.rowVersion,
  });

  factory SolicitudAjusteStock.fromJson(Map<String, dynamic> j) => SolicitudAjusteStock(
    idSolicitud: j['id_solicitud'] as int,
    idAlmacen: j['id_almacen'] as int,
    idZona: j['id_zona'] as int,
    idUbicacion: j['id_ubicacion'] as int,
    ubicacionNombre: j['ubicacion_nombre'] as String? ?? '',
    ubicacionCodigo: j['ubicacion_codigo'] as String? ?? '',
    zonaNombre: j['zona_nombre'] as String? ?? '',
    motivoCategoria: j['motivo_categoria'] as String? ?? 'CONTEO_FISICO',
    observaciones: j['observaciones'] as String?,
    estado: j['estado'] as String? ?? 'PENDIENTE',
    idUsuarioSolicitante: j['id_usuario_solicitante'] as int,
    solicitanteNombre: j['solicitante_nombre'] as String?,
    idUsuarioAsignado: j['id_usuario_asignado'] as int,
    asignadoNombre: j['asignado_nombre'] as String?,
    idAjusteStock: j['id_ajuste_stock'] as int?,
    motivoCancelacion: j['motivo_cancelacion'] as String?,
    creadoEn: parseDateOrNull(j['creado_en']) ?? DateTime.now(),
    rowVersion: j['row_version'] as int,
  );

  final int idSolicitud;
  final int idAlmacen;
  final int idZona;
  final int idUbicacion;
  final String ubicacionNombre;
  final String ubicacionCodigo;
  final String zonaNombre;
  final String motivoCategoria;
  final String? observaciones;

  /// 'PENDIENTE' | 'COMPLETADA' | 'CANCELADA'
  final String estado;
  final int idUsuarioSolicitante;
  final String? solicitanteNombre;
  final int idUsuarioAsignado;
  final String? asignadoNombre;
  final int? idAjusteStock;
  final String? motivoCancelacion;
  final DateTime creadoEn;
  final int rowVersion;
}

/// Usuario elegible para asignarle una solicitud (`GET /usuarios/asignables`).
class UsuarioAsignable {
  UsuarioAsignable({required this.idUsuario, required this.nombreMostrar, this.username});

  factory UsuarioAsignable.fromJson(Map<String, dynamic> j) => UsuarioAsignable(
    idUsuario: j['id_usuario'] as int,
    nombreMostrar: (j['nombre_mostrar'] as String?)?.trim().isNotEmpty == true
        ? j['nombre_mostrar'] as String
        : (j['username'] as String? ?? 'Usuario #${j['id_usuario']}'),
    username: j['username'] as String?,
  );

  final int idUsuario;
  final String nombreMostrar;
  final String? username;
}
