import 'package:dio/dio.dart';

import '../config/env.dart';
import '../errors/app_exception.dart';
import '../storage/secure_storage.dart';
import 'conexion_estado.dart';

/// Cliente HTTP único de la app. Agrega el JWT en cada request y traduce
/// los errores del backend (ver CONTEXTO.md raíz §7.4) a [AppException].
class DioClient {
  DioClient(this._secureStorage, {void Function()? onUnauthorized})
    : dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          // Sin esto, Dio espera indefinido (no hay timeout por defecto).
          // El caso real que lo hizo evidente: usuario pasa de wifi a
          // datos móviles con un request en curso (o uno periódico de
          // `enableSilentRefresh` que arranca justo en la ventana de
          // transición) — el socket quedó abierto sobre la interfaz wifi
          // que ya no existe, Android no manda ni siquiera un RST, y sin
          // timeout esa espera puede durar minutos. La app se ve
          // "congelada" (`skipLoadingOnRefresh` de `enableSilentRefresh`
          // ni muestra loading) en vez de mostrar un error o migrar a
          // public. — con estos timeouts el request falla en ventana
          // acotada, `onError` de abajo dispara el failover a public. (ver
          // `_debeFailover`) o `ConexionEstado.marcarSinConexion` si ya no
          // hay a dónde más ir.
          connectTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 30),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // `Env.apiBaseUrl` puede cambiar durante la sesión (erp. ↔
          // public., ver `Env._origenActivo`) — releerlo acá en vez de
          // fijarlo una sola vez en `BaseOptions` es lo que permite que un
          // cambio de red tome efecto sin reconstruir el `DioClient`.
          options.baseUrl = Env.apiBaseUrl;
          final token = await _secureStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Cualquier respuesta real del backend (incluso un 4xx de
          // negocio) es prueba de que la conexión funciona — recupera a
          // `SinConexionScreen` sin esperar al próximo chequeo periódico.
          ConexionEstado.marcarConectado();
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          // El propio login también responde 401 ante credenciales
          // inválidas — eso no es "sesión vencida", es un error de negocio
          // normal que la pantalla de login ya muestra solita. Excluirlo
          // evita pisar ese mensaje con un logout local espurio.
          final esLogin = error.requestOptions.path.contains('/auth/login');
          if (error.response?.statusCode == 401 && !esLogin) {
            onUnauthorized?.call();
          }

          if (_debeFailover(error)) {
            Env.marcarErpCaido();
            try {
              final reintento = await _reintentarEnOtroOrigen(
                error.requestOptions,
              );
              ConexionEstado.marcarConectado();
              handler.resolve(reintento);
              return;
            } on DioException catch (e) {
              final mapeado = _mapError(e);
              _actualizarEstadoConexion(mapeado);
              handler.reject(mapeado);
              return;
            }
          }

          final mapeado = _mapError(error);
          _actualizarEstadoConexion(mapeado);
          handler.reject(mapeado);
        },
      ),
    );
  }

  /// Único punto donde un request termina en fallo definitivo (sin más
  /// origen al que caer) — si lo que quedó adentro es un `NetworkException`
  /// es que no hay conexión con NINGÚN servidor, y `SinConexionScreen` tiene
  /// que aparecer; cualquier otro error (401/404/422/etc.) prueba que el
  /// request SÍ llegó al backend.
  void _actualizarEstadoConexion(DioException mapeado) {
    final error = mapeado.error;
    if (error is NetworkException) {
      ConexionEstado.marcarSinConexion(error.message);
    } else {
      ConexionEstado.marcarConectado();
    }
  }

  final Dio dio;
  final SecureStorage _secureStorage;

  /// Solo falla sobre a public. una vez por request (evita loop si public.
  /// también falla) y solo cuando el fallo es realmente de conexión (no
  /// tiene sentido reintentar un 404/422 en otro origen) estando en modo
  /// automático y apuntando a erp. — un error mientras ya estamos en
  /// public. no tiene a dónde más ir.
  bool _debeFailover(DioException error) {
    if (error.requestOptions.extra['_reintentoFailover'] == true) {
      return false;
    }
    if (!Env.modoAutoDominioActivo || !Env.estaUsandoErp) return false;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        // Socket que quedó colgado tras un cambio de red (ver el comentario
        // de `connectTimeout`/`sendTimeout`/`receiveTimeout` más arriba) se
        // reporta como send/receiveTimeout, no connectionError — sin esto,
        // ese caso agotaba el timeout pero se quedaba en erp. hasta el
        // próximo chequeo de `BackendMonitor` en vez de migrar al toque.
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.unknown;
  }

  Future<Response<dynamic>> _reintentarEnOtroOrigen(
    RequestOptions options,
  ) {
    final nuevo = options.copyWith(
      baseUrl: Env.apiBaseUrl,
      extra: {...options.extra, '_reintentoFailover': true},
    );
    return dio.fetch<dynamic>(nuevo);
  }

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
      null => NetworkException(_mensajeSinConexion(error)),
      _ => BusinessException(detail ?? 'Error inesperado del servidor'),
    };

    return error.copyWith(error: mapped);
  }

  /// Sin `error.response` no hay `detail` del backend — el único dato que
  /// tenemos es el propio `DioException`. Se muestra el detalle técnico
  /// (host, causa) en vez del genérico "Sin conexión con el servidor" a
  /// secas, porque en el campo (LAN vs túnel público, redes con DNS raro)
  /// ese detalle es lo que permite diagnosticar sin acceso a los logs.
  String _mensajeSinConexion(DioException error) {
    final causa = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'tiempo de espera agotado',
      DioExceptionType.badCertificate => 'certificado inválido',
      _ => error.error?.toString() ?? error.message ?? 'error desconocido',
    };
    return 'Sin conexión con el servidor ($causa)';
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
