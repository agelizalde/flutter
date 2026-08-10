import 'package:dio/dio.dart';

import '../domain/ajuste_stock_models.dart';

/// Llamadas a `/ajuste-stock/*` (ver `ajuste_stock_rout.py`). El flujo
/// normal (`crear`) exige BORRADOR → CONFIRMADO → APLICADO (los ítems
/// quedan fijos al crear; solo se puede editar la observación mientras
/// está BORRADOR). `mermaRapida` es la excepción: un atajo de un solo paso
/// que crea+confirma+aplica del lado del backend sin pedir ubicación.
class AjusteStockApi {
  AjusteStockApi(this._dio);

  final Dio _dio;

  Future<List<AjusteStock>> listar({
    String? q,
    String? estado,
    int? idAlmacen,
    int limit = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ajuste-stock',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'estado': ?estado,
        'id_almacen': ?idAlmacen,
        'limit': limit,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(AjusteStock.fromJson).toList();
  }

  Future<AjusteStockDetalle> obtener(int idAjusteStock) async {
    final res = await _dio.get<Map<String, dynamic>>('/ajuste-stock/$idAjusteStock');
    final data = res.data!;
    return AjusteStockDetalle(
      ajuste: AjusteStock.fromJson(data['header'] as Map<String, dynamic>),
      items: (data['items'] as List)
          .cast<Map<String, dynamic>>()
          .map(AjusteStockItem.fromJson)
          .toList(),
    );
  }

  Future<int> crear({
    required String modoAjuste,
    required String motivoCategoria,
    required int idAlmacen,
    required int idZona,
    required int idUbicacion,
    String? observaciones,
    required List<AjusteStockItemCreateIn> items,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/ajuste-stock',
      data: {
        'modo_ajuste': modoAjuste,
        'motivo_categoria': motivoCategoria,
        'id_almacen': idAlmacen,
        'id_zona': idZona,
        'id_ubicacion': idUbicacion,
        'observaciones': ?observaciones,
        'items': items.map((e) => e.toJson()).toList(),
      },
    );
    return (res.data!['header'] as Map<String, dynamic>)['id_ajuste_stock'] as int;
  }

  Future<void> mermaRapida({
    required int idProducto,
    required int idUnidadMedida,
    required int idAlmacen,
    required double cantidad,
    required String motivoCategoria,
    String? observaciones,
  }) {
    return _dio.post<Map<String, dynamic>>(
      '/ajuste-stock/merma-rapida',
      data: {
        'id_producto': idProducto,
        'id_unidad_medida': idUnidadMedida,
        'id_almacen': idAlmacen,
        'cantidad': cantidad,
        'motivo_categoria': motivoCategoria,
        'observaciones': ?observaciones,
      },
    );
  }

  Future<void> confirmar(int idAjusteStock) =>
      _dio.post<void>('/ajuste-stock/$idAjusteStock/confirmar');

  Future<void> aplicar(int idAjusteStock) =>
      _dio.post<void>('/ajuste-stock/$idAjusteStock/aplicar');

  Future<void> anular({
    required int idAjusteStock,
    required int expectedVersion,
    String? motivo,
  }) {
    return _dio.post<void>(
      '/ajuste-stock/$idAjusteStock/anular',
      data: {'expected_version': expectedVersion, 'motivo': ?motivo},
    );
  }
}
