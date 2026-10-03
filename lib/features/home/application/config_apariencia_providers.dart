import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/config_apariencia_api.dart';
import '../domain/config_apariencia.dart';

final configAparienciaApiProvider = Provider<ConfigAparienciaApi>((ref) {
  return ConfigAparienciaApi(ref.watch(dioClientProvider).dio);
});

/// `autoDispose`: se pide de nuevo cada vez que se abre la tarjeta virtual
/// (única consumidora hoy) en vez de quedar cacheada toda la sesión — así
/// un cambio de logo/nombre en Apariencia se refleja sin reabrir la app.
/// `null` si falla (sin red interna, `public.` no la sirve, etc.) — quien
/// la consuma cae al logo local del asset, no a un error visible.
final configAparienciaProvider = FutureProvider.autoDispose<ConfigApariencia?>((ref) async {
  try {
    return await ref.watch(configAparienciaApiProvider).obtener();
  } catch (_) {
    return null;
  }
});
