import 'package:dio/dio.dart';

import '../domain/firma_solicitud.dart';

/// Llamadas a `/firmas/solicitudes/*` (ver `firmas_rout.py` /
/// `firmas_solicitudes.py`). Esta app solo consume el flujo de resolución
/// (ver/aprobar/rechazar) — administrar tipos de documento y reglas sigue
/// siendo exclusivo de la web.
class FirmasApi {
  FirmasApi(this._dio);

  final Dio _dio;

  Future<List<FirmaSolicitud>> listarSolicitudes({String? estado, bool soloParaMi = false}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/firmas/solicitudes',
      queryParameters: {'estado': ?estado, 'solo_para_mi': soloParaMi},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(FirmaSolicitud.fromJson).toList();
  }

  Future<FirmaSolicitud> getSolicitud(int idFirmaSolicitud) async {
    final res = await _dio.get<Map<String, dynamic>>('/firmas/solicitudes/$idFirmaSolicitud');
    return FirmaSolicitud.fromJson(res.data!);
  }

  Future<FirmaSolicitud> aprobar({
    required int idFirmaSolicitud,
    required int expectedVersion,
    String? motivo,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/firmas/solicitudes/$idFirmaSolicitud/aprobar',
      data: {'expected_version': expectedVersion, 'motivo': ?motivo},
    );
    return FirmaSolicitud.fromJson(res.data!);
  }

  Future<FirmaSolicitud> rechazar({
    required int idFirmaSolicitud,
    required int expectedVersion,
    required String motivo,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/firmas/solicitudes/$idFirmaSolicitud/rechazar',
      data: {'expected_version': expectedVersion, 'motivo': motivo},
    );
    return FirmaSolicitud.fromJson(res.data!);
  }
}
