import '../../../core/utils/parsing.dart';

/// Notificación real del backend (`notificaciones`, ver
/// `notificaciones_service.py`). `ruta` es un path del front WEB (React) —
/// no sirve para navegar acá, la navegación en esta app se resuelve por
/// `tipoEntidad`/`tipo`/`idEntidad` (ver `notificacion_navegador.dart`).
class Notificacion {
  Notificacion({
    required this.idNotificacion,
    required this.tipo,
    required this.titulo,
    this.mensaje,
    required this.tipoEntidad,
    this.idEntidad,
    this.ruta,
    required this.leida,
    required this.creadoEn,
  });

  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
    idNotificacion: j['id_notificacion'] as int,
    tipo: j['tipo'] as String? ?? '',
    titulo: j['titulo'] as String? ?? '',
    mensaje: j['mensaje'] as String?,
    tipoEntidad: j['tipo_entidad'] as String? ?? '',
    idEntidad: j['id_entidad'] as int?,
    ruta: j['ruta'] as String?,
    leida: j['leida'] == true || j['leida'] == 1,
    creadoEn: parseDateOrNull(j['creado_en']) ?? DateTime.now(),
  );

  final int idNotificacion;
  final String tipo;
  final String titulo;
  final String? mensaje;
  final String tipoEntidad;
  final int? idEntidad;
  final String? ruta;
  final bool leida;
  final DateTime creadoEn;

  Notificacion copyWith({bool? leida}) => Notificacion(
    idNotificacion: idNotificacion,
    tipo: tipo,
    titulo: titulo,
    mensaje: mensaje,
    tipoEntidad: tipoEntidad,
    idEntidad: idEntidad,
    ruta: ruta,
    leida: leida ?? this.leida,
    creadoEn: creadoEn,
  );
}
