import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/sesion_expirada.dart';
import '../../../core/auth/usuario_actual.dart';
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

    if (!await repo.hasSession()) return null;
    try {
      return await repo.me();
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
      return repo.me();
    });
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, UsuarioActual?>(AuthController.new);
