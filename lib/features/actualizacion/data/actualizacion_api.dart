import 'package:dio/dio.dart';

import '../domain/version_app.dart';

/// Llamada a `/ajustes/sistema/app-android/ultima` (ver `app_android_rout.py`)
/// — la última versión activa publicada del .apk. Cualquier usuario logueado
/// puede pedirla, no requiere permiso especial.
class ActualizacionApi {
  ActualizacionApi(this._dio);

  final Dio _dio;

  Future<VersionApp?> ultimaVersion() async {
    final res = await _dio.get<dynamic>('/ajustes/sistema/app-android/ultima');
    final data = res.data;
    if (data is! Map) return null;
    return VersionApp.fromJson(data.cast<String, dynamic>());
  }
}
