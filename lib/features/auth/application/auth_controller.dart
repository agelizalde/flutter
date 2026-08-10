import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Future<UsuarioActual?> build() async {
    final repo = ref.watch(authRepositoryProvider);

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_intervaloRefreshSesion, (_) => _refrescarSilenciosamente());
    ref.onDispose(() => _refreshTimer?.cancel());

    if (!await repo.hasSession()) return null;
    try {
      return await repo.me();
    } catch (_) {
      // Token guardado pero inválido/vencido: tratar como no logueado.
      return null;
    }
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
      // Sin conexión o token vencido: se deja el estado como está, un
      // request real a la API va a disparar el 401 normal si corresponde.
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
