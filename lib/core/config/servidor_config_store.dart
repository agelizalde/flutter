import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia local (no sensible, por eso `shared_preferences` y no
/// `SecureStorage` — esa queda reservada al JWT, ver `SecureStorage`) de la
/// URL del backend configurada a mano desde la pantalla de login. Es
/// por-dispositivo: cada teléfono guarda su propio servidor, no viaja al
/// backend ni se sincroniza entre dispositivos. Mismo patrón que
/// `ImpresoraConfigStore` (features/produccion).
class ServidorConfigStore {
  static const _kUrl = 'core_servidor_base_url';
  static const _kFijarErp = 'core_servidor_fijar_erp';

  /// Terminal que solo opera dentro de la empresa: nunca cae a `public.`
  /// (ver `Env.fijoEnErp`). Default `false` — la auto-detección normal.
  Future<bool> leerFijarErp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kFijarErp) ?? false;
  }

  Future<void> guardarFijarErp(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    if (valor) {
      await prefs.setBool(_kFijarErp, true);
    } else {
      await prefs.remove(_kFijarErp);
    }
  }

  Future<String?> leer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUrl);
  }

  Future<void> guardar(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      await prefs.setString(_kUrl, trimmed);
    } else {
      await prefs.remove(_kUrl);
    }
  }
}
