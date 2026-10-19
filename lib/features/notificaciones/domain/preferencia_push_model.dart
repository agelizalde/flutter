/// "¿el módulo [codigo] me avisa al teléfono con una notificación del
/// sistema?" — independiente de si el módulo está INSTANTANEO/PROGRAMADO
/// (eso ya se resolvió en el backend antes de llegar acá, ver
/// `notificaciones_push_service.py::enviar_push`). Sin fila en el backend,
/// el default es `true` — ver migración.
class PreferenciaPush {
  PreferenciaPush({required this.codigo, required this.nombre, required this.habilitado});

  factory PreferenciaPush.fromJson(Map<String, dynamic> j) => PreferenciaPush(
    codigo: j['codigo'] as String,
    nombre: j['nombre'] as String,
    habilitado: j['habilitado'] == true || j['habilitado'] == 1,
  );

  final String codigo;
  final String nombre;
  final bool habilitado;

  PreferenciaPush copyWith({bool? habilitado}) =>
      PreferenciaPush(codigo: codigo, nombre: nombre, habilitado: habilitado ?? this.habilitado);
}
