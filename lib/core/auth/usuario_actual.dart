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

  // Igualdad por valor — clave para que el polling de `/auth/me` cada 15s
  // (`AuthController._refrescarSilenciosamente`) no golpee a TODA la app:
  // Riverpod solo notifica a quien mira `authControllerProvider` cuando el
  // nuevo `AsyncData` es distinto del anterior. Sin este `==`, cada
  // instancia nueva (aunque venga con los mismos datos) se consideraba
  // "distinta" por igualdad de referencia, y como casi cada pantalla
  // consulta permisos/almacén de este objeto, se disparaba un rebuild
  // global cada 15 segundos — el "parón" periódico. Con esto, solo se
  // notifica (y se repintan las pantallas) cuando algo realmente cambió
  // (bloqueo, permisos, rol, almacén, etc.).
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsuarioActual &&
        other.idUsuario == idUsuario &&
        other.email == email &&
        other.username == username &&
        other.nombreMostrar == nombreMostrar &&
        other.idAlmacenSeleccionado == idAlmacenSeleccionado &&
        other.bloqueadoErp == bloqueadoErp &&
        other.bloqueoMensaje == bloqueoMensaje &&
        _sameElements(other.roles, roles) &&
        _sameElements(other.permissions, permissions);
  }

  @override
  int get hashCode => Object.hash(
        idUsuario,
        email,
        username,
        nombreMostrar,
        idAlmacenSeleccionado,
        bloqueadoErp,
        bloqueoMensaje,
        // Hash sin orden — tiene que coincidir con la comparación de abajo,
        // que también ignora el orden.
        roles.toSet().fold<int>(0, (acc, r) => acc ^ r.hashCode),
        permissions.toSet().fold<int>(0, (acc, p) => acc ^ p.hashCode),
      );
}

/// Compara ignorando el orden: el backend los manda como `set` de Python,
/// así que el mismo contenido puede llegar en distinto orden entre un
/// llamado y el siguiente (más aún si el caché de permisos del backend
/// vence entre medio) — comparar por posición daría "cambió" cuando en
/// realidad es el mismo conjunto de roles/permisos.
bool _sameElements(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  return a.toSet().containsAll(b);
}
