import 'package:dio/dio.dart';

import '../domain/config_apariencia.dart';

/// Llamada a `/ajustes/sistema/apariencia` (ver `config_apariencia_rout.py`)
/// — logo/nombre de empresa configurados desde la web. Ojo: esta ruta NO
/// está en el allowlist de nginx para el acceso `public.` (ver
/// `Env.usandoAccesoPublico`), así que fuera de la red interna esto va a
/// fallar — quien la use debe tener un fallback (logo local del asset).
class ConfigAparienciaApi {
  ConfigAparienciaApi(this._dio);

  final Dio _dio;

  Future<ConfigApariencia> obtener() async {
    final res = await _dio.get<dynamic>('/ajustes/sistema/apariencia');
    final data = res.data;
    if (data is! Map) throw const FormatException('Respuesta inesperada de apariencia');
    return ConfigApariencia.fromJson(data.cast<String, dynamic>());
  }
}
