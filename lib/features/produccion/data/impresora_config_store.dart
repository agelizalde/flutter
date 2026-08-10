import 'package:shared_preferences/shared_preferences.dart';

import '../domain/impresora_config.dart';

/// Persistencia local (no sensible, por eso `shared_preferences` y no
/// `SecureStorage` — esa queda reservada al JWT) de la config de impresora.
/// Es por-dispositivo: cada tablet/celular guarda su propia impresora
/// configurada, no viaja al backend.
class ImpresoraConfigStore {
  static const _kIp = 'produccion_impresora_ip';
  static const _kPuerto = 'produccion_impresora_puerto';
  static const _kAnchoMm = 'produccion_impresora_ancho_mm';
  static const _kAltoMm = 'produccion_impresora_alto_mm';

  Future<ImpresoraConfig> leer() async {
    final prefs = await SharedPreferences.getInstance();
    return ImpresoraConfig(
      ip: prefs.getString(_kIp),
      puerto: prefs.getInt(_kPuerto) ?? 9100,
      anchoMm: prefs.getDouble(_kAnchoMm) ?? 60,
      altoMm: prefs.getDouble(_kAltoMm) ?? 40,
    );
  }

  Future<void> guardar(ImpresoraConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final ip = config.ip?.trim();
    if (ip != null && ip.isNotEmpty) {
      await prefs.setString(_kIp, ip);
    } else {
      await prefs.remove(_kIp);
    }
    await prefs.setInt(_kPuerto, config.puerto);
    await prefs.setDouble(_kAnchoMm, config.anchoMm);
    await prefs.setDouble(_kAltoMm, config.altoMm);
  }
}
