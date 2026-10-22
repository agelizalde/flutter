import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el JWT y datos mínimos de sesión fuera de shared_prefs plano.
/// Mismo token que usa el ERP web (`erp_access_token` en localStorage allá,
/// ver CONTEXTO.md raíz §7.6) pero acá vive en almacenamiento seguro nativo.
///
/// iOS: se guarda con accesibilidad `first_unlock` (legible desde que el
/// teléfono se desbloqueó una vez tras encenderse), no con el default
/// `unlocked` de la librería. Con `unlocked`, si iOS levantaba la app en
/// segundo plano con el teléfono bloqueado (push de FCM, prewarming), la
/// lectura del token fallaba, `AuthController` lo tomaba como "no hay
/// sesión" y el usuario encontraba el login al abrir la app aunque su
/// sesión (incluso fija) siguiera vigente en el backend.
class SecureStorage {
  SecureStorage(this._storage, [this._legacyIos]);

  final FlutterSecureStorage _storage;

  /// Mismo almacenamiento con las opciones viejas (`unlocked`) — solo para
  /// migrar lo guardado por versiones anteriores. En iOS la accesibilidad
  /// es parte de la búsqueda del Keychain, así que con las opciones nuevas
  /// esos ítems "no existen".
  final FlutterSecureStorage? _legacyIos;

  static const _tokenKey = 'wherehouse_access_token';
  static const _ultimoUsuarioKey = 'wherehouse_ultimo_usuario';
  // Claves del viejo "Ingresar con huella" (guardaba usuario+contraseña en
  // el teléfono). Se quitó por inseguro en dispositivos compartidos; solo
  // quedan para borrar lo que haya dejado una versión anterior.
  static const _legacyBioUsuarioKey = 'wherehouse_bio_usuario';
  static const _legacyBioPasswordKey = 'wherehouse_bio_password';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _leer(_tokenKey);

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    await _legacyIos?.delete(key: _tokenKey);
  }

  /// Último usuario que inició sesión con éxito — solo para precargar el
  /// campo en `LoginScreen`, no da acceso a nada por sí solo.
  Future<void> saveUltimoUsuario(String usuario) => _storage.write(key: _ultimoUsuarioKey, value: usuario);

  Future<String?> readUltimoUsuario() => _leer(_ultimoUsuarioKey);

  /// Borra la contraseña que haya guardado una versión anterior de la app
  /// (login con huella). Se llama al arrancar; no hace nada si no hay.
  Future<void> borrarCredencialesLegacy() async {
    await _storage.delete(key: _legacyBioUsuarioKey);
    await _storage.delete(key: _legacyBioPasswordKey);
    await _legacyIos?.delete(key: _legacyBioUsuarioKey);
    await _legacyIos?.delete(key: _legacyBioPasswordKey);
  }

  /// Lee con las opciones actuales y, si no está y hay un ítem guardado con
  /// las viejas, lo migra (borrar viejo → escribir nuevo; el orden importa
  /// porque `write` con otra accesibilidad no ve el viejo y `SecItemAdd`
  /// chocaría con duplicado). Si la escritura nueva falla, se restaura el
  /// viejo para no perder la sesión.
  Future<String?> _leer(String key) async {
    final actual = await _storage.read(key: key);
    final legacy = _legacyIos;
    if (actual != null || legacy == null) return actual;

    final viejo = await legacy.read(key: key);
    if (viejo == null) return null;
    await legacy.delete(key: key);
    try {
      await _storage.write(key: key, value: viejo);
    } catch (_) {
      await legacy.write(key: key, value: viejo);
    }
    return viejo;
  }
}

/// Construye el [SecureStorage] de la app con las opciones por plataforma
/// (ver comentario de la clase).
SecureStorage crearSecureStorage() {
  if (!Platform.isIOS) return SecureStorage(const FlutterSecureStorage());
  return SecureStorage(
    const FlutterSecureStorage(iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock)),
    const FlutterSecureStorage(),
  );
}
