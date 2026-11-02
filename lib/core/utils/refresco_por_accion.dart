import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Refresco "por acción" de la app (reemplaza al viejo polling cada 15-60s
/// de `enableSilentRefresh`, que hacía que la app se viera refrescándose
/// sola todo el tiempo). Las listas se vuelven a pedir SOLO cuando:
///
/// - el usuario hace una acción que cambia datos: cualquier POST/PUT/PATCH/
///   DELETE exitoso contra el backend (lo dispara `DioClient`, ver
///   `onResponse`) — así, al confirmar una entrega, pickear, recibir, etc.,
///   todas las pantallas abiertas quedan al día;
/// - la app vuelve a primer plano (ver `WherehouseApp`);
/// - el usuario tira para abajo (pull-to-refresh, cada pantalla lo maneja);
/// - se abre una pantalla (los providers son `autoDispose`: se piden de
///   nuevo cada vez que se entra).
///
/// Varias acciones seguidas (ej. una confirmación que hace 2-3 requests) se
/// juntan en un único pulso con un debounce corto.
class RefrescoPorAccion {
  RefrescoPorAccion._();

  static final ValueNotifier<int> pulso = ValueNotifier<int>(0);
  static Timer? _debounce;

  static void notificar() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => pulso.value++);
  }
}

/// Hace que un `FutureProvider` (`autoDispose`) se vuelva a pedir con cada
/// pulso de [RefrescoPorAccion]. Llamar como primera línea del provider:
/// ```dart
/// final fooProvider = FutureProvider.autoDispose<Foo>((ref) {
///   refrescarEnAcciones(ref);
///   return repo.getFoo();
/// });
/// ```
///
/// No usar en providers que alimentan un formulario en edición activa
/// (ej. cantidades que el usuario está tipeando) — refrescar ahí pisaría
/// lo que el usuario todavía no guardó.
void refrescarEnAcciones(Ref ref) {
  void alPulso() => ref.invalidateSelf();
  RefrescoPorAccion.pulso.addListener(alPulso);
  ref.onDispose(() => RefrescoPorAccion.pulso.removeListener(alPulso));
}
