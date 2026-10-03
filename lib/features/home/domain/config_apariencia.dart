/// Espejo de lo que devuelve `GET /ajustes/sistema/apariencia` (ver
/// `config_apariencia_rout.py` del backend) — nombre del sistema y logo que
/// se configuran desde la web en Ajustes > Generales > Sistema > Apariencia.
/// Sin autenticación en el backend (carga en la pantalla de login), así que
/// cualquier usuario logueado en esta app también puede pedirla.
class ConfigApariencia {
  ConfigApariencia({required this.nombreSistema, required this.logoUrl});

  factory ConfigApariencia.fromJson(Map<String, dynamic> json) {
    return ConfigApariencia(
      nombreSistema: json['nombre_sistema'] as String? ?? 'ERP',
      logoUrl: json['logo_url'] as String?,
    );
  }

  final String nombreSistema;
  final String? logoUrl;
}
