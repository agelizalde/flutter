import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/impresora_config_store.dart';
import '../data/impresora_service.dart';
import '../domain/impresora_config.dart';

final impresoraConfigStoreProvider = Provider<ImpresoraConfigStore>((ref) => ImpresoraConfigStore());

final impresoraServiceProvider = Provider<ImpresoraService>((ref) => ImpresoraService());

/// Config de impresora persistida en el dispositivo (ver
/// `ImpresoraConfigStore`) — mismo patrón que `AuthController`: `build()`
/// carga el estado inicial, `guardar()` escribe y actualiza el state local
/// sin tener que releer de `shared_preferences`.
class ImpresoraConfigController extends AsyncNotifier<ImpresoraConfig> {
  @override
  Future<ImpresoraConfig> build() {
    return ref.watch(impresoraConfigStoreProvider).leer();
  }

  Future<void> guardar(ImpresoraConfig config) async {
    await ref.read(impresoraConfigStoreProvider).guardar(config);
    state = AsyncValue.data(config);
  }
}

final impresoraConfigControllerProvider =
    AsyncNotifierProvider<ImpresoraConfigController, ImpresoraConfig>(ImpresoraConfigController.new);
