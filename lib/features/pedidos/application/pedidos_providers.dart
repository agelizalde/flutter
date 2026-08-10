import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../data/pedidos_api.dart';
import '../data/pedidos_repository.dart';
import '../domain/pedido_models.dart';

final pedidosApiProvider = Provider<PedidosApi>((ref) {
  return PedidosApi(ref.watch(dioClientProvider).dio);
});

final pedidosRepositoryProvider = Provider<PedidosRepository>((ref) {
  return PedidosRepository(ref.watch(pedidosApiProvider));
});

/// Detalle de un pedido por `id`, para `PedidoInfoScreen` — llega desde el
/// escaneo contextual (ver `escaner/`), mismo patrón que `ocInfoDetalleProvider`.
final pedidoInfoProvider = FutureProvider.family.autoDispose<PedidoDetalle, int>((ref, idPedido) {
  return ref.watch(pedidosRepositoryProvider).obtener(idPedido);
});

final pedidoSubpedidosProvider =
    FutureProvider.family.autoDispose<List<SubpedidoResumen>, int>((ref, idPedido) {
  return ref.watch(pedidosRepositoryProvider).subpedidosDe(idPedido);
});

/// Ítems de un subpedido, para `SubpedidoItemsScreen` (llega al tocar un
/// subpedido en `PedidoInfoScreen`).
final subpedidoItemsProvider =
    FutureProvider.family.autoDispose<List<SubpedidoItemResumen>, int>((ref, idPedidoSubpedido) {
  return ref.watch(pedidosRepositoryProvider).itemsDe(idPedidoSubpedido);
});

final pedidosBusquedaProvider = StateProvider<String>((ref) => '');

/// Módulo "Pedidos" (`PedidosHomeScreen`): el backend ya devuelve solo los
/// subpedidos visibles para el permiso del usuario (ver
/// `ver_subpedidos_seguimiento_deposito` en `pedidos_rout.py`). Se trae el
/// conjunto completo (sin filtrar por estado) porque la lista agrupa por
/// pedido y necesita ver todos sus subpedidos para calcular el estado
/// agregado (el más atrasado manda, ver `_estadoAgregado` en la pantalla).
final pedidosSeguimientoProvider =
    FutureProvider.family.autoDispose<List<SubpedidoSeguimiento>, String>((ref, query) {
  enableSilentRefresh(ref, interval: const Duration(seconds: 20));
  return ref.watch(pedidosRepositoryProvider).seguimiento(q: query.isEmpty ? null : query);
});
