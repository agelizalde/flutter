/// Espejo de lo que devuelve `GET /auth/me` (`item`, ver
/// `build_current_user` en `core/security.py` del backend).
class UsuarioActual {
  UsuarioActual({
    required this.idUsuario,
    required this.email,
    this.username,
    required this.nombreMostrar,
    required this.idAlmacenSeleccionado,
    required this.roles,
    required this.permissions,
    required this.bloqueadoErp,
    required this.bloqueoMensaje,
  });

  factory UsuarioActual.fromJson(Map<String, dynamic> json) {
    return UsuarioActual(
      idUsuario: json['id_usuario'] as int,
      email: json['email'] as String,
      username: json['username'] as String?,
      nombreMostrar: json['nombre_mostrar'] as String? ??
          json['username'] as String? ??
          json['email'] as String,
      idAlmacenSeleccionado: json['id_almacen_seleccionado'] as int?,
      roles: (json['roles'] as List<dynamic>? ?? []).cast<String>(),
      permissions: (json['permissions'] as List<dynamic>? ?? []).cast<String>(),
      bloqueadoErp: json['bloqueado_erp'] as bool? ?? false,
      bloqueoMensaje: json['bloqueo_mensaje'] as String?,
    );
  }

  final int idUsuario;
  final String email;
  final String? username;
  final String nombreMostrar;
  final int? idAlmacenSeleccionado;
  final List<String> roles;
  final List<String> permissions;

  /// Bloqueo administrativo de ERP (ver `core/security.py::build_current_user`
  /// del backend) — si es `true`, el usuario sigue autenticado pero el
  /// backend rechaza con 403 cualquier endpoint salvo `/auth/me` y
  /// `/auth/logout`. El frontend debe mostrar [BlockedUserScreen] en vez
  /// de dejarlo navegar.
  final bool bloqueadoErp;
  final String? bloqueoMensaje;

  /// Mismo criterio que `has_permission` en el backend (`modulo.accion`).
  bool tienePermiso(String codigo) => permissions.contains(codigo);
}
