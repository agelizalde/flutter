import 'package:dio/dio.dart';

/// Errores de negocio mapeados desde las respuestas del backend
/// (`{"detail": "..."}`, ver CONTEXTO.md raíz §7.4).
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 401 — token vencido o inválido, la UI debe volver a /login.
class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'Sesión vencida, iniciá sesión de nuevo',
  ]);
}

/// 409 — `row_version` no coincide (optimistic locking, CONTEXTO.md raíz §7.7).
/// No reintentar solo: hay que refrescar el registro y que el usuario decida.
class ConflictException extends AppException {
  const ConflictException([
    super.message = 'El registro fue modificado por otra sesión',
  ]);
}

/// 4xx de validación / regla de negocio (422, 400, etc.).
class BusinessException extends AppException {
  const BusinessException(super.message);
}

/// Sin conexión o error de red — candidato a quedar en la cola de sync.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Sin conexión con el servidor']);
}

/// La API de Dio obliga a que los interceptores rechacen con un
/// `DioException` (no se puede `reject()` con un `AppException` directo),
/// así que lo que llega a un `catch` siempre es el `DioException` con el
/// `AppException` mapeado adentro de `.error` (ver `DioClient._mapError`).
/// Usar esto en vez de `e.toString()` para mostrarle al usuario el mensaje
/// limpio del backend en vez del volcado verboso de Dio.
String describeError(Object error) {
  if (error is AppException) return error.message;
  if (error is DioException && error.error is AppException) {
    return (error.error as AppException).message;
  }
  return error.toString();
}
