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

  /// Config de Ajustes → Operaciones → Entrega — ver [EntregaConfig]. La del
  /// almacén de ESE subpedido (la misma con la que valida el backend).
  Future<EntregaConfig> entregaConfig(int idPedidoSubpedido) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/pedidos/subpedidos/entrega/config',
      queryParameters: {'id_pedido_subpedido': idPedidoSubpedido},
    );
    return EntregaConfig.fromJson(res.data!);
  }

  /// `rechazos`: [{id_pedido_subpedido_item, cantidad, observacion?}]
  /// `devoluciones`: mismo shape que `rechazos` (el cliente entrega de vuelta
  /// algo que sí llegó con el pedido)
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
    required List<Map<String, dynamic>> devoluciones,
    required List<Map<String, dynamic>> faltantes,
    required List<XFile> fotos,
  }) async {
    final formData = FormData.fromMap({
      'expected_version': expectedVersion,
      if (observacion != null && observacion.isNotEmpty) 'observacion': observacion,
      'rechazos': jsonEncode(rechazos),
      'devoluciones': jsonEncode(devoluciones),
      'faltantes': jsonEncode(faltantes),
      'fotos': [for (final f in fotos) MultipartFile.fromBytes(await f.readAsBytes(), filename: f.name)],
    });
    await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/entrega/confirmar',
      data: formData,
    );
  }

  /// Documento completo del pedido (todos sus subpedidos, con cliente/
  /// sucursal) — lo usa Firmas para revisar la entrega al resolver una
  /// solicitud `PEDIDO_ENTREGA`, ver [PedidoEntregaResumen].
  Future<PedidoEntregaResumen> documentoEntrega(int idPedidoSubpedido) async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/subpedidos/$idPedidoSubpedido/entrega/documento');
    return PedidoEntregaResumen.fromJson(res.data!, idPedidoSubpedido: idPedidoSubpedido);
  }

  /// Vehículos activos para el selector de móvil — atrás del permiso de
  /// entregar, no de `vehiculos.ver`.
  Future<List<VehiculoEntregaOpcion>> vehiculos() async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/subpedidos/entrega/vehiculos');
    return (res.data!['items'] as List? ?? []).cast<Map<String, dynamic>>().map(VehiculoEntregaOpcion.fromJson).toList();
  }

  /// Cambia el móvil del reparto (solo PROPIO, EN_ENTREGA, responsable
  /// asignado — lo valida el backend).
  Future<void> cambiarVehiculo(int idPedidoSubpedido, {required int idVehiculo}) async {
    await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/entrega/vehiculo',
      data: {'id_vehiculo_entrega': idVehiculo},
    );
  }

  /// "Entrega simple": un solo click, sin fotos ni novedades — el backend da la
  /// mercadería por entregada, libera los cajones y manda directo a Pendiente
  /// de facturación sin aprobación. Solo disponible cuando
  /// `EntregaConfig.entregaHabilitada` está apagado (el backend la rechaza si
  /// no).
  Future<void> confirmarEntregaSimple(int idPedidoSubpedido, {required int expectedVersion}) async {
    await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/entrega/confirmar-simple',
      data: {'expected_version': expectedVersion},
    );
  }
}
