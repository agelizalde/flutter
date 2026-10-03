import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Señal global de "el backend cerró la sesión" (401 en cualquier request
/// que no sea el propio `/auth/login`). La dispara [DioClient] y la escucha
/// [AuthController] para forzar el estado a "no logueado" al toque.
///
/// Vive separado de [authControllerProvider] a propósito: `dioClientProvider`
/// no puede depender de `authControllerProvider` sin crear un ciclo
/// (authController -> authRepository -> dioClient -> authController). Este
/// provider no depende de nada, así que tanto DioClient como AuthController
/// pueden apoyarse en él sin problema.
final sesionExpiradaProvider = Provider<StreamController<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});
