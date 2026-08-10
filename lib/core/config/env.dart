import 'package:flutter/foundation.dart';

/// Configuración de entorno de la app.
///
/// El backend FastAPI no expone proxy `/api` como la web (Vite) — la app
/// corre en un dispositivo físico separado, así que necesita la URL completa
/// del backend. Para producción se define en build time con
/// `--dart-define=API_BASE_URL=...`; en desarrollo se infiere un default
/// razonable según la plataforma.
class Env {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;

    if (kIsWeb) return 'http://127.0.0.1:8000';

    // El emulador de Android no resuelve "localhost" a la máquina host —
    // necesita el alias especial 10.0.2.2. iOS simulator y desktop sí
    // pueden usar localhost directo.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  /// Resuelve una URL de archivo servido por el backend (fotos de
  /// producto, etc.) a una URL absoluta. El storage local devuelve rutas
  /// relativas (`/static/...`); el backend OCI ya devuelve la URL completa
  /// — se detecta por el esquema, no hay flag aparte que lo indique.
  static String resolveStorageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$apiBaseUrl$url';
  }
}
