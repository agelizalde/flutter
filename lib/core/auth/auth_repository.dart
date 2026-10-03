import '../network/dio_client.dart';
import '../storage/secure_storage.dart';
import 'usuario_actual.dart';

/// Reusa el mismo backend de auth que el ERP web (`POST /auth/login`,
/// `GET /auth/me`, `POST /auth/logout` — ver CONTEXTO.md raíz §3.1 y
/// CONTEXTO_WHEREHOUSE.md §4).
class AuthRepository {
  AuthRepository(this._dioClient, this._secureStorage);

  final DioClient _dioClient;
  final SecureStorage _secureStorage;

  Future<void> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final response = await _dioClient.dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email_or_username': emailOrUsername, 'password': password},
    );
    final token = response.data!['access_token'] as String;
    await _secureStorage.saveToken(token);
  }

  Future<UsuarioActual> me() async {
    final response = await _dioClient.dio.get<Map<String, dynamic>>('/auth/me');
    final item = response.data!['item'] as Map<String, dynamic>;
    return UsuarioActual.fromJson(item);
  }

  Future<void> logout() async {
    try {
      await _dioClient.dio.post<void>('/auth/logout');
    } finally {
      await _secureStorage.clearToken();
    }
  }

  /// `POST /auth/change-password` (ver `auth_rout.py`/`auth_service.py` del
  /// backend) — requiere la contraseña actual, valida `new_password` con al
  /// menos 8 caracteres server-side. `cerrarOtrasSesiones` revoca todas las
  /// demás sesiones activas del usuario salvo la actual (default `true` en
  /// el backend).
  Future<void> cambiarPassword({
    required String actual,
    required String nueva,
    bool cerrarOtrasSesiones = true,
  }) async {
    await _dioClient.dio.post<void>(
      '/auth/change-password',
      data: {
        'current_password': actual,
        'new_password': nueva,
        'logout_other_sessions': cerrarOtrasSesiones,
      },
    );
  }

  /// Limpia el token guardado sin avisarle al backend — se usa cuando ya
  /// sabemos que el token es inválido/vencido (401 recibido en cualquier
  /// otro request, ver `sesionExpiradaProvider`), así no generamos un
  /// segundo request condenado a fallar igual.
  Future<void> logoutLocal() => _secureStorage.clearToken();

  Future<bool> hasSession() async {
    final token = await _secureStorage.readToken();
    return token != null;
  }
}
