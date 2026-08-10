import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/entrega_models.dart';

/// Llamadas a `/pedidos/subpedidos/{en-entrega,{id}/entrega/*}` (ver
/// `subpedido_entrega_service.py`) — confirmación de entrega al cliente,
/// módulo separado de la carga del camión (`ExpedicionApi`): personal
/// distinto puede estar a cargo de cada paso.
class EntregaApi {
  EntregaApi(this._dio);

  final Dio _dio;

  Future<List<SubpedidoEnEntrega>> subpedidosEnEntrega() async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/subpedidos/en-entrega');
    return (res.data!['subpedidos'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(SubpedidoEnEntrega.fromJson)
        .toList();
  }

  Future<List<EntregaItem>> entregaItems(int idPedidoSubpedido) async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/subpedidos/$idPedidoSubpedido/entrega/items');
    return (res.data!['items'] as List? ?? []).cast<Map<String, dynamic>>().map(EntregaItem.fromJson).toList();
  }

  /// `rechazos`: [{id_pedido_subpedido_item, cantidad, observacion?}]
  /// `faltantes`: [{producto_libre, cantidad, observacion?}]
  ///
  /// `fotos` son `XFile` (no `dart:io File`): funcionan igual en mobile y en
  /// web — `File`/`MultipartFile.fromFile` asumen filesystem real, que no
  /// existe en web (ver `image_picker` docs).
  Future<void> confirmarEntrega(
    int idPedidoSubpedido, {
    required int expectedVersion,
    String? observacion,
    required List<Map<String, dynamic>> rechazos,
    required List<Map<String, dynamic>> faltantes,
    required List<XFile> fotos,
  }) async {
    final formData = FormData.fromMap({
      'expected_version': expectedVersion,
      if (observacion != null && observacion.isNotEmpty) 'observacion': observacion,
      'rechazos': jsonEncode(rechazos),
      'faltantes': jsonEncode(faltantes),
      'fotos': [for (final f in fotos) MultipartFile.fromBytes(await f.readAsBytes(), filename: f.name)],
    });
    await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/entrega/confirmar',
      data: formData,
    );
  }
}
