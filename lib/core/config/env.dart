import 'package:flutter/foundation.dart';

import 'servidor_config_store.dart';

/// Configuración de entorno de la app.
///
/// El backend FastAPI no expone proxy `/api` como la web (Vite) — la app
/// corre en un dispositivo físico separado, así que necesita la URL completa
/// del backend. Para producción se define en build time con
/// `--dart-define=API_BASE_URL=...`; en desarrollo se infiere un default
/// razonable según la plataforma. Además, cualquier usuario puede pisar ese
/// valor a mano desde la pantalla "Configurar servidor" (login) sin tener
/// que recompilar — ver `_runtimeOverride` abajo.
class Env {
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// Valor guardado en el dispositivo (`ServidorConfigStore`). Gana sobre el
  /// `--dart-define` de compilación porque es la forma en que alguien
  /// corrige la URL sin recompilar/reinstalar el APK.
  static String? _runtimeOverride;

  /// Relee el valor guardado en disco. Se llama una vez en `main()` antes de
  /// `runApp`, así el primer request ya usa la URL correcta.
  static Future<void> cargarOverrideGuardado() async {
    _runtimeOverride = await ServidorConfigStore().leer();
  }

  /// Actualiza el valor en memoria sin esperar una relectura de disco — lo
  /// usa la pantalla de configuración justo después de guardar. Los
  /// providers que ya armaron un `DioClient` con la URL vieja (`dioClient
  /// Provider` en `core/providers.dart`) no se enteran solos: por eso esa
  /// pantalla igual pide cerrar y reabrir la app.
  static void setOverrideEnMemoria(String? url) {
    final trimmed = url?.trim();
    _runtimeOverride = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }

  static String get apiBaseUrl {
    if (_runtimeOverride != null) return _runtimeOverride!;
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
