import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda el JWT y datos mínimos de sesión fuera de shared_prefs plano.
/// Mismo token que usa el ERP web (`erp_access_token` en localStorage allá,
/// ver CONTEXTO.md raíz §7.6) pero acá vive en almacenamiento seguro nativo.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'wherehouse_access_token';

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}
