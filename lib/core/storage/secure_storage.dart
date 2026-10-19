import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el JWT y datos mínimos de sesión fuera de shared_prefs plano.
/// Mismo token que usa el ERP web (`erp_access_token` en localStorage allá,
/// ver CONTEXTO.md raíz §7.6) pero acá vive en almacenamiento seguro nativo.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'wherehouse_access_token';
  static const _ultimoUsuarioKey = 'wherehouse_ultimo_usuario';
  // Claves del viejo "Ingresar con huella" (guardaba usuario+contraseña en
  // el teléfono). Se quitó por inseguro en dispositivos compartidos; solo
  // quedan para borrar lo que haya dejado una versión anterior.
  static const _legacyBioUsuarioKey = 'wherehouse_bio_usuario';
  static const _legacyBioPasswordKey = 'wherehouse_bio_password';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// Último usuario que inició sesión con éxito — solo para precargar el
  /// campo en `LoginScreen`, no da acceso a nada por sí solo.
  Future<void> saveUltimoUsuario(String usuario) =>
      _storage.write(key: _ultimoUsuarioKey, value: usuario);

  Future<String?> readUltimoUsuario() => _storage.read(key: _ultimoUsuarioKey);

  /// Borra la contraseña que haya guardado una versión anterior de la app
  /// (login con huella). Se llama al arrancar; no hace nada si no hay.
  Future<void> borrarCredencialesLegacy() async {
    await _storage.delete(key: _legacyBioUsuarioKey);
    await _storage.delete(key: _legacyBioPasswordKey);
  }
}
