import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/refresco_por_accion.dart';
import '../data/entrega_api.dart';
import '../data/entrega_repository.dart';
import '../domain/entrega_models.dart';

final entregaApiProvider = Provider<EntregaApi>((ref) {
  return EntregaApi(ref.watch(dioClientProvider).dio);
});

final entregaRepositoryProvider = Provider<EntregaRepository>((ref) {
  return EntregaRepository(ref.watch(entregaApiProvider));
});

/// Lista de subpedidos en EN_ENTREGA (camión ya cargado, esperando que el
/// chofer asignado confirme la entrega al cliente) — el backend ya filtra
/// para que cada uno solo vea lo suyo. Se refresca con cada acción del
/// usuario (`refrescarEnAcciones`), igual que `subpedidosEnCargaProvider`.
final subpedidosEnEntregaProvider = FutureProvider.autoDispose<List<SubpedidoEnEntrega>>((ref) {
  refrescarEnAcciones(ref);
  return ref.watch(entregaRepositoryProvider).subpedidosEnEntrega();
});

/// Ítems del subpedido para el picker de "Rechazo" en la pantalla de
/// entrega.
final entregaItemsProvider = FutureProvider.autoDispose.family<List<EntregaItem>, int>((ref, idPedidoSubpedido) {
  return ref.watch(entregaRepositoryProvider).entregaItems(idPedidoSubpedido);
});

/// Config de Ajustes → Operaciones → Entrega (fotos, aprobación, novedades
/// permitidas) — se pide cada vez que se abre la pantalla de confirmar entrega,
/// no se cachea entre aperturas. Por subpedido: el backend resuelve el almacén
/// del armado de ese subpedido, igual que al validar la confirmación.
final entregaConfigProvider = FutureProvider.autoDispose.family<EntregaConfig, int>((ref, idPedidoSubpedido) {
  return ref.watch(entregaRepositoryProvider).entregaConfig(idPedidoSubpedido);
});

/// Documento de entrega del pedido — lo consume la pantalla de detalle de
/// Firmas para mostrar cliente/sucursal/ETA/quién entregó/etc. al resolver
/// una solicitud `PEDIDO_ENTREGA`.
final pedidoEntregaResumenProvider = FutureProvider.autoDispose.family<PedidoEntregaResumen, int>((ref, idPedidoSubpedido) {
  return ref.watch(entregaRepositoryProvider).documentoEntrega(idPedidoSubpedido);
});
