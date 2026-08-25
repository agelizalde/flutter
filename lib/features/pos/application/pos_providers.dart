import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../pedidos/application/pedidos_providers.dart' show pedidosRepositoryProvider;
import '../../pedidos/domain/pedido_models.dart' show ClienteSimple;
import '../data/pos_api.dart';
import '../data/pos_repository.dart';
import '../domain/pos_models.dart';

final posApiProvider = Provider<PosApi>((ref) {
  return PosApi(ref.watch(dioClientProvider).dio);
});

final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(ref.watch(posApiProvider), ref.watch(pedidosRepositoryProvider));
});

/// El punto de venta del usuario logueado — 403/error si no tiene ninguno
/// activo asignado (ver `PosScreen`, que muestra ese caso aparte, no como
/// error genérico).
final miPuntoVentaProvider = FutureProvider.autoDispose<PuntoVentaActual>((ref) {
  return ref.watch(posRepositoryProvider).miPuntoVenta();
});

/// Gatea el ícono "Punto de venta" del Home: además del permiso `pos.vender`
/// (chequeado igual que el resto de los módulos, ver `_ModuloDeposito` en
/// `home_screen.dart`), hace falta que el usuario tenga un punto de venta
/// ACTIVO asignado (`puntos_venta.id_usuario_asignado`, Ajustes → Puntos de
/// venta en la web) — tener el permiso solo habilita el rol "puede vender
/// por POS en general", no le da automáticamente una caja propia. `false`
/// tanto si no tiene el permiso como si el backend devuelve 403 (sin punto
/// de venta asignado) — nunca se propaga como error visible en el Home.
final tienePuntoVentaAsignadoProvider = FutureProvider.autoDispose<bool>((ref) async {
  final usuario = ref.watch(authControllerProvider).value;
  if (usuario == null || !usuario.tienePermiso('pos.vender')) return false;
  try {
    await ref.watch(posRepositoryProvider).miPuntoVenta();
    return true;
  } catch (_) {
    return false;
  }
});

final posBusquedaClienteProvider = StateProvider<String>((ref) => '');
final posBusquedaProductoProvider = StateProvider<String>((ref) => '');

final posResultadosClienteProvider = FutureProvider.autoDispose<List<ClienteSimple>>((ref) {
  final q = ref.watch(posBusquedaClienteProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(posRepositoryProvider).clientesListar(q: q);
});

final posResultadosProductoProvider = FutureProvider.autoDispose<List<ProductoPosSimple>>((ref) {
  final q = ref.watch(posBusquedaProductoProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(posRepositoryProvider).buscarProductos(q: q);
});
