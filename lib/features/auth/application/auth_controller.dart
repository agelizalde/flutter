import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/sesion_expirada.dart';
import '../../../core/auth/usuario_actual.dart';
import '../../../core/notifications/push_notifications_service.dart';
import '../../../core/providers.dart';

/// Cada cuánto se vuelve a pedir `/auth/me` en segundo plano mientras hay
/// sesión iniciada, para detectar sin recargar la app cambios hechos desde
/// la web (ej. un admin bloquea al usuario o le cambia permisos).
const _intervaloRefreshSesion = Duration(seconds: 15);

/// Estado de sesión de la app. `null` = no logueado, sin tocar todavía
/// (se resuelve en [build] contra el token guardado).
class AuthController extends AsyncNotifier<UsuarioActual?> {
  Timer? _refreshTimer;
  StreamSubscription<void>? _sesionExpiradaSub;

  @override
  Future<UsuarioActual?> build() async {
    final repo = ref.watch(authRepositoryProvider);

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_intervaloRefreshSesion, (_) => _refrescarSilenciosamente());
    ref.onDispose(() => _refreshTimer?.cancel());

    // Cualquier request (no solo el refresh silencioso de arriba) puede
    // toparse con un 401 — DioClient lo avisa acá para cerrar la sesión
    // local al toque, sin esperar el próximo tick. El router reacciona solo
    // (ver `_AuthRefreshListenable` en app/router.dart) y manda a /login.
    _sesionExpiradaSub?.cancel();
    _sesionExpiradaSub = ref
        .read(sesionExpiradaProvider)
        .stream
        .listen((_) => _cerrarSesionPorTokenVencido());
    ref.onDispose(() => _sesionExpiradaSub?.cancel());

    // Restos del viejo login con huella (contraseña guardada en el
    // teléfono): se borran en el primer arranque de esta versión.
    unawaited(repo.borrarCredencialesLegacy());

    if (!await repo.hasSession()) return null;
    try {
      final usuario = await repo.me();
      // Sesión restaurada al abrir la app (no un login recién hecho) — el
      // primer intento de `PushNotificationsService.inicializar()` en
      // `app/app.dart` puede haber corrido antes de que esto resolviera,
      // sin sesión todavía; este reintento es el que efectivamente deja el
      // token (si rotó, o si nunca se había registrado este dispositivo)
      // asociado al usuario. Best-effort — no debe demorar ni romper el
      // arranque de la app.
      unawaited(ref.read(pushNotificationsServiceProvider).enviarTokenAlBackend());
      return usuario;
    } catch (_) {
      // Token guardado pero inválido/vencido: tratar como no logueado.
      return null;
    }
  }

  Future<void> _cerrarSesionPorTokenVencido() async {
    final actual = state;
    if (actual is AsyncData<UsuarioActual?> && actual.value == null) {
      return; // ya estaba deslogueado, nada que hacer
    }

    final repo = ref.read(authRepositoryProvider);
    await repo.logoutLocal();
    state = const AsyncData(null);
  }

  /// Vuelve a pedir `/auth/me` y reemplaza el estado directo con
  /// `AsyncData`, sin pasar por `AsyncLoading` — así ninguna pantalla
  /// parpadea, pero si cambió `bloqueado_erp`/permisos/roles, el router y
  /// los guards de permisos lo toman en el siguiente build.
  Future<void> _refrescarSilenciosamente() async {
    final actual = state;
    if (actual is! AsyncData<UsuarioActual?> || actual.value == null) return;

    final repo = ref.read(authRepositoryProvider);
    try {
      final actualizado = await repo.me();
      state = AsyncData(actualizado);
    } catch (_) {
      // Sin conexión: se deja el estado como está. Si en cambio fue un 401
      // (token vencido/revocado), `_cerrarSesionPorTokenVencido` ya se
      // disparó en paralelo vía `sesionExpiradaProvider` y dejó el estado
      // en null.
    }
  }

  Future<void> login({
    required String emailOrUsername,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repo.login(emailOrUsername: emailOrUsername, password: password);
      final usuario = await repo.me();
      unawaited(ref.read(pushNotificationsServiceProvider).enviarTokenAlBackend());
      return usuario;
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    // Antes de que `repo.logout()` invalide el JWT — el DELETE necesita una
    // sesión válida para autenticarse. Best-effort: si falla, el token
    // queda huérfano en el backend hasta que FCM lo reporte como muerto en
    // el próximo intento de push (ver notificaciones_push_service.py).
    await ref.read(pushNotificationsServiceProvider).eliminarTokenDelBackend();
    await repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UsuarioActual?>(AuthController.new);
