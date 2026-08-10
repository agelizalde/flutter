import 'package:dio/dio.dart';

import '../config/env.dart';
import '../errors/app_exception.dart';
import '../storage/secure_storage.dart';

/// Cliente HTTP único de la app. Agrega el JWT en cada request y traduce
/// los errores del backend (ver CONTEXTO.md raíz §7.4) a [AppException].
class DioClient {
  DioClient(this._secureStorage)
    : dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) {
          handler.reject(_mapError(error));
        },
      ),
    );
  }

  final Dio dio;
  final SecureStorage _secureStorage;

  DioException _mapError(DioException error) {
    final status = error.response?.statusCode;
    final detail = _extraerDetalle(error.response?.data);

    final AppException mapped = switch (status) {
      401 => UnauthorizedException(
        detail ?? 'Sesión vencida, iniciá sesión de nuevo',
      ),
      409 => ConflictException(
        detail ?? 'El registro fue modificado por otra sesión',
      ),
      400 || 422 => BusinessException(detail ?? 'Datos inválidos'),
      null => const NetworkException(),
      _ => BusinessException(detail ?? 'Error inesperado del servidor'),
    };

    return error.copyWith(error: mapped);
  }

  /// `detail` de FastAPI viene como `String` para errores de negocio
  /// (`HTTPException(detail="...")`) pero como **lista** de objetos
  /// `{loc, msg, type}` cuando el 422 viene de una validación de Pydantic
  /// (`field_validator`/`model_validator` con `raise ValueError(...)`) —
  /// sin este caso, `.toString()` mostraba el volcado crudo de la lista de
  /// Dart en vez del mensaje de validación real.
  String? _extraerDetalle(Object? data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    if (detail is List) {
      final mensajes = detail
          .map((e) => e is Map ? e['msg']?.toString() : e.toString())
          .whereType<String>()
          // Pydantic v2 antepone "Value error, " a los ValueError de los
          // validadores propios — no aporta nada al usuario.
          .map((m) => m.replaceFirst('Value error, ', ''))
          .toList();
      if (mensajes.isNotEmpty) return mensajes.join('. ');
    }
    return null;
  }
}
