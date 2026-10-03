import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/vehiculo_models.dart';

String _formatFechaIso(DateTime fecha) {
  final m = fecha.month.toString().padLeft(2, '0');
  final d = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year}-$m-$d';
}

/// Llamadas a `/vehiculos` y `/vehiculos/{id}/mantenimientos` (ver
/// `vehiculos_route.py` y `vehiculos_mantenimientos_route.py`) — versión
/// simple para depósito: ver vehículos, ver su historial de mantenimientos y
/// cargar uno nuevo con título libre (sin asignar partes ni periodicidad,
/// eso queda para el ERP web, ver `MantenimientosTab.jsx`).
class VehiculosApi {
  VehiculosApi(this._dio);

  final Dio _dio;

  Future<List<Vehiculo>> listar({String? q, bool? activo}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/vehiculos',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (activo != null) 'activo': activo,
        'limit': 100,
      },
    );
    return (res.data!['items'] as List? ?? []).cast<Map<String, dynamic>>().map(Vehiculo.fromJson).toList();
  }

  Future<Vehiculo> detalle(int idVehiculo) async {
    final res = await _dio.get<Map<String, dynamic>>('/vehiculos/$idVehiculo');
    return Vehiculo.fromJson(res.data!);
  }

  Future<List<Mantenimiento>> mantenimientos(int idVehiculo) async {
    final res = await _dio.get<Map<String, dynamic>>('/vehiculos/$idVehiculo/mantenimientos');
    return (res.data!['items'] as List? ?? []).cast<Map<String, dynamic>>().map(Mantenimiento.fromJson).toList();
  }

  /// `archivo` es `XFile` (no `dart:io File`): funciona igual en mobile y web
  /// (mismo motivo que `EntregaApi.confirmarEntrega`). Solo fotos (galería/
  /// cámara vía `image_picker`) — el backend también acepta PDF, pero esta
  /// app no tiene selector de archivos genérico instalado.
  Future<Mantenimiento> crearMantenimiento(
    int idVehiculo, {
    required String titulo,
    String? descripcion,
    required DateTime fechaRealizado,
    int? kilometraje,
    double? costo,
    XFile? archivo,
  }) async {
    final formData = FormData.fromMap({
      'titulo': titulo,
      if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
      'fecha_realizado': _formatFechaIso(fechaRealizado),
      if (kilometraje != null) 'kilometraje': kilometraje,
      if (costo != null) 'costo': costo,
      if (archivo != null) 'file': MultipartFile.fromBytes(await archivo.readAsBytes(), filename: archivo.name),
    });
    final res = await _dio.post<Map<String, dynamic>>('/vehiculos/$idVehiculo/mantenimientos', data: formData);
    return Mantenimiento.fromJson(res.data!);
  }
}
