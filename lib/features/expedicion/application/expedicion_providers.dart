import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../data/expedicion_api.dart';
import '../data/expedicion_repository.dart';
import '../domain/expedicion_models.dart';

final expedicionApiProvider = Provider<ExpedicionApi>((ref) {
  return ExpedicionApi(ref.watch(dioClientProvider).dio);
});

final expedicionRepositoryProvider = Provider<ExpedicionRepository>((ref) {
  return ExpedicionRepository(ref.watch(expedicionApiProvider));
});

/// Lista de subpedidos en EN_CARGA, refrescada cada 20s mientras la pantalla
/// esté abierta (mismo criterio que `subpedidosControlProvider`).
final subpedidosEnCargaProvider = FutureProvider.autoDispose<List<SubpedidoEnCarga>>((ref) {
  enableSilentRefresh(ref, interval: const Duration(seconds: 20));
  return ref.watch(expedicionRepositoryProvider).subpedidosEnCarga();
});

/// Detalle del checklist de carga de un subpedido, parametrizado por
/// `idPedidoSubpedido`. Se invalida manualmente tras cada escaneo/conteo
/// para reflejar el progreso.
final detalleCargaProvider = FutureProvider.autoDispose.family<DetalleCarga, int>((ref, idPedidoSubpedido) {
  return ref.watch(expedicionRepositoryProvider).detalle(idPedidoSubpedido);
});

/// Devoluciones PENDIENTE de un subpedido EN_CARGA (Ventas redujo/quitó por
/// Excel algo que ya se había escaneado) — se invalida manualmente tras
/// confirmar una, mismo criterio que `detalleCargaProvider`.
final devolucionesCargaProvider = FutureProvider.autoDispose.family<List<DevolucionCarga>, int>((ref, idPedidoSubpedido) {
  return ref.watch(expedicionRepositoryProvider).devoluciones(idPedidoSubpedido);
});
