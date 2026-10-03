import 'package:image_picker/image_picker.dart';

import '../domain/entrega_models.dart';
import 'entrega_api.dart';

/// Repositorio de Entrega — passthrough fino sobre [EntregaApi], mismo
/// patrón que `ExpedicionRepository`: sin try/catch ni cache local, los
/// errores se propagan como `DioException` y se capturan en la pantalla con
/// `describeError`.
class EntregaRepository {
  EntregaRepository(this._api);

  final EntregaApi _api;

  Future<List<SubpedidoEnEntrega>> subpedidosEnEntrega() => _api.subpedidosEnEntrega();

  Future<List<EntregaItem>> entregaItems(int idPedidoSubpedido) => _api.entregaItems(idPedidoSubpedido);

  Future<EntregaConfig> entregaConfig() => _api.entregaConfig();

  Future<PedidoEntregaResumen> documentoEntrega(int idPedidoSubpedido) => _api.documentoEntrega(idPedidoSubpedido);

  Future<void> confirmarEntrega(
    int idPedidoSubpedido, {
    required int expectedVersion,
    String? observacion,
    required List<Map<String, dynamic>> rechazos,
    required List<Map<String, dynamic>> devoluciones,
    required List<Map<String, dynamic>> faltantes,
    required List<XFile> fotos,
  }) => _api.confirmarEntrega(
    idPedidoSubpedido,
    expectedVersion: expectedVersion,
    observacion: observacion,
    rechazos: rechazos,
    devoluciones: devoluciones,
    faltantes: faltantes,
    fotos: fotos,
  );

  Future<void> confirmarEntregaSimple(int idPedidoSubpedido, {required int expectedVersion}) =>
      _api.confirmarEntregaSimple(idPedidoSubpedido, expectedVersion: expectedVersion);
}
