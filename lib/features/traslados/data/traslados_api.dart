import 'package:dio/dio.dart';

import '../domain/traslado_models.dart';

/// Ítem para `POST /traslados/ejecutar` (ver
/// `traslados_service.py::TrasladoEjecutarItemIn`).
class EjecutarTrasladoItemIn {
  EjecutarTrasladoItemIn({
    required this.idExistenciaOrigen,
    required this.cantidad,
    required this.idUbicacionDestino,
    this.observaciones,
  });

  final int idExistenciaOrigen;
  final double cantidad;
  final int idUbicacionDestino;
  final String? observaciones;

  Map<String, dynamic> toJson() => {
    'id_existencia_origen': idExistenciaOrigen,
    'cantidad': cantidad,
    'id_ubicacion_destino': idUbicacionDestino,
    'observaciones': ?observaciones,
  };
}

/// Llamadas a `/traslados/*` (ver `traslados_rout.py`). Solo cubre el
/// flujo "ejecutar" (crear + confirmar en un paso) — es el que prefiere el
/// propio backend (CONTEXTO_WHEREHOUSE.md §5) y el único que usa la web
/// para esta misma pantalla; no se implementa el flujo legacy
/// borrador→confirmar→anular.
class TrasladosApi {
  TrasladosApi(this._dio);

  final Dio _dio;

  Future<List<AlertaReacomodo>> alertasReacomodo({int? idAlmacen}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/traslados/alertas-reacomodo',
      queryParameters: {'id_almacen': ?idAlmacen},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(AlertaReacomodo.fromJson).toList();
  }

  Future<List<Traslado>> listar({
    String? q,
    String? estado,
    int? idAlmacen,
    int limit = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/traslados',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'estado': ?estado,
        'id_almacen': ?idAlmacen,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(Traslado.fromJson).toList();
  }

  Future<TrasladoDetalle> obtener(int idTraspaso) async {
    final res = await _dio.get<Map<String, dynamic>>('/traslados/$idTraspaso');
    final data = res.data!;
    return TrasladoDetalle(
      traslado: Traslado.fromJson(data['header'] as Map<String, dynamic>),
      items: (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(TrasladoItem.fromJson)
          .toList(),
      movimientos: (data['movimientos'] as List)
          .cast<Map<String, dynamic>>()
          .map(TrasladoMovimiento.fromJson)
          .toList(),
    );
  }

  Future<EjecutarTrasladoResultado> ejecutar({
    int? idAlmacen,
    String? observaciones,
    required List<EjecutarTrasladoItemIn> items,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/traslados/ejecutar',
      data: {
        'id_almacen': ?idAlmacen,
        'observaciones': ?observaciones,
        'items': items.map((e) => e.toJson()).toList(),
      },
    );
    return EjecutarTrasladoResultado.fromJson(res.data!);
  }
}
