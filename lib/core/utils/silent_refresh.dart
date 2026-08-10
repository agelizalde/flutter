import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hace que un `FutureProvider`/`FutureProvider.family` se vuelva a pedir
/// solo cada [interval] mientras la pantalla que lo mira esté abierta
/// (gracias a `.autoDispose`, el timer se cancela solo al cerrarla).
///
/// No se nota: `AsyncValue.when` usa `skipLoadingOnRefresh: true` por
/// defecto, así que mientras se refresca sigue mostrando los datos
/// anteriores en vez de tirar un loading — recién cambia la UI si la
/// respuesta nueva trae datos distintos.
///
/// Llamar como primera línea del callback del provider:
/// ```dart
/// final fooProvider = FutureProvider.autoDispose<Foo>((ref) {
///   enableSilentRefresh(ref);
///   return repo.getFoo();
/// });
/// ```
///
/// No usar en providers que alimentan un formulario en edición activa
/// (ej. cantidades que el usuario está tipeando) — refrescar ahí pisaría
/// lo que el usuario todavía no guardó.
void enableSilentRefresh(Ref ref, {Duration interval = const Duration(seconds: 15)}) {
  final timer = Timer.periodic(interval, (_) => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
}
