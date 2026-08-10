import 'package:dio/dio.dart';

import '../domain/produccion_models.dart';

/// Fila para `POST /produccion/ordenes/{id}/finalizar` (ver
/// `orden_service.py::OrdenConsumoRealIn`/`OrdenResultadoRealIn`/`OrdenMermaRealIn`).
class FinalizarLineaIn {
  FinalizarLineaIn({required this.id, required this.cantidadReal});

  final int id;
  final double cantidadReal;
}

/// Llamadas a `/produccion/recetas/*` y `/produccion/ordenes/*` (ver
/// `receta_rout.py`/`orden_rout.py` del backend). Solo cubre lo que necesita
/// el flujo de Taller (elegir receta → producir → finalizar), no el CRUD
/// completo de recetas ni el panel admin de órdenes (eso vive en la web).
class ProduccionApi {
  ProduccionApi(this._dio);

  final Dio _dio;

  Future<List<RecetaResumen>> listarRecetas({String? q, bool activo = true, int limit = 100}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/produccion/recetas',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'activo': activo,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(RecetaResumen.fromJson).toList();
  }

  Future<RecetaDetalle> obtenerReceta(int idReceta) async {
    final res = await _dio.get<Map<String, dynamic>>('/produccion/recetas/$idReceta');
    return RecetaDetalle.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  /// Plantilla reusable de etiqueta (ver `/produccion/etiquetas/{id}` —
  /// `etiqueta_service.py`), buscada aparte del detalle de la receta:
  /// `RecetaDetalle.etiqueta` solo trae el resumen (id/nombre/dimensiones).
  Future<EtiquetaTemplate> obtenerEtiqueta(int idEtiqueta) async {
    final res = await _dio.get<Map<String, dynamic>>('/produccion/etiquetas/$idEtiqueta');
    return EtiquetaTemplate.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  Future<OrdenPreview> preview({required int idReceta, required double cantidadReferenciaReal}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/produccion/ordenes/preview',
      data: {'id_receta': idReceta, 'cantidad_referencia_real': cantidadReferenciaReal},
    );
    return OrdenPreview.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  Future<OrdenCreada> crear({
    required int idReceta,
    required double cantidadReferenciaReal,
    required int idAlmacen,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/produccion/ordenes',
      data: {
        'id_receta': idReceta,
        'cantidad_referencia_real': cantidadReferenciaReal,
        'id_almacen': idAlmacen,
      },
    );
    return OrdenCreada.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  Future<void> iniciar(int idOrden) async {
    await _dio.post<Map<String, dynamic>>('/produccion/ordenes/$idOrden/iniciar');
  }

  Future<OrdenProduccion> obtenerOrden(int idOrden) async {
    final res = await _dio.get<Map<String, dynamic>>('/produccion/ordenes/$idOrden');
    return OrdenProduccion.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  /// Resuelve el código escaneado de una orden de producción (`codigo`,
  /// único) — usado por el escaneo contextual de la app de depósito.
  Future<OrdenProduccion> buscarPorCodigo(String codigo) async {
    final res = await _dio.get<Map<String, dynamic>>('/produccion/ordenes/buscar/$codigo');
    return OrdenProduccion.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  Future<List<EtiquetaProduccion>> etiquetas(int idOrden) async {
    final res = await _dio.get<Map<String, dynamic>>('/produccion/ordenes/$idOrden/etiquetas');
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(EtiquetaProduccion.fromJson).toList();
  }

  Future<List<OrdenListItem>> listarOrdenes({String? estado, int? idAlmacen, int limit = 50}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/produccion/ordenes',
      queryParameters: {'estado': ?estado, 'id_almacen': ?idAlmacen, 'limit': limit},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(OrdenListItem.fromJson).toList();
  }

  Future<void> pausar({required int idOrden, required int expectedVersion}) async {
    await _dio.post<Map<String, dynamic>>(
      '/produccion/ordenes/$idOrden/pausar',
      data: {'expected_version': expectedVersion},
    );
  }

  Future<void> reanudar({required int idOrden, required int expectedVersion}) async {
    await _dio.post<Map<String, dynamic>>(
      '/produccion/ordenes/$idOrden/reanudar',
      data: {'expected_version': expectedVersion},
    );
  }

  /// No manda `id_ubicacion_destino`: el backend usa automáticamente la
  /// ubicación recomendada de la zona de Producción del almacén (ver
  /// `orden_service.py::_resolver_ubicacion_produccion`) — decisión de
  /// producto para mantener el flujo mobile simple, sin paso extra.
  Future<void> finalizar({
    required int idOrden,
    required int expectedVersion,
    required List<FinalizarLineaIn> consumo,
    required List<FinalizarLineaIn> resultado,
    required List<FinalizarLineaIn> mermas,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/produccion/ordenes/$idOrden/finalizar',
      data: {
        'expected_version': expectedVersion,
        'consumo': consumo.map((e) => {'id_orden_consumo': e.id, 'cantidad_real': e.cantidadReal}).toList(),
        'resultado': resultado.map((e) => {'id_orden_resultado': e.id, 'cantidad_real': e.cantidadReal}).toList(),
        'mermas': mermas.map((e) => {'id_orden_merma': e.id, 'cantidad_real': e.cantidadReal}).toList(),
      },
    );
  }

  Future<void> anular({required int idOrden, required int expectedVersion, String? motivo}) async {
    await _dio.post<Map<String, dynamic>>(
      '/produccion/ordenes/$idOrden/anular',
      data: {'expected_version': expectedVersion, 'motivo_anulacion': ?motivo},
    );
  }
}
