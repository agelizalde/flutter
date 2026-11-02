import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/refresco_por_accion.dart';
import '../../auth/application/auth_controller.dart';
import '../../recepcion/application/recepcion_providers.dart' show ubicacionesApiProvider;
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/application/stock_providers.dart'
    show productosApiProvider, stockRepositoryProvider;
import '../../stock/domain/stock_models.dart' show ProductoSimple;
import '../data/ajuste_stock_api.dart';
import '../data/ajuste_stock_repository.dart';
import '../domain/ajuste_stock_models.dart';

final ajusteStockApiProvider = Provider<AjusteStockApi>((ref) {
  return AjusteStockApi(ref.watch(dioClientProvider).dio);
});

final ajusteStockRepositoryProvider = Provider<AjusteStockRepository>((ref) {
  return AjusteStockRepository(
    ref.watch(ajusteStockApiProvider),
    ref.watch(ubicacionesApiProvider),
    ref.watch(stockRepositoryProvider),
    ref.watch(productosApiProvider),
  );
});

/// `true` si el usuario puede confirmar y aplicar: en ese caso los controles
/// (por ubicación / por producto) se aplican apenas se crean en vez de
/// quedar en BORRADOR esperando a alguien con esos permisos.
final puedeAplicarAjusteDirectoProvider = Provider<bool>((ref) {
  final u = ref.watch(authControllerProvider).value;
  return (u?.tienePermiso('ajuste_stock.confirmar') ?? false) &&
      (u?.tienePermiso('ajuste_stock.aplicar') ?? false);
});

/// Historial (`AjusteStockHistorialScreen`): solo ajustes APLICADOS del
/// último mes en el almacén seleccionado. El backend filtra la fecha por
/// `fecha_conteo`; acá se re-filtra y ordena por la fecha de aplicación.
final ajustesStockListadoProvider = FutureProvider.autoDispose<List<AjusteStock>>((ref) async {
  refrescarEnAcciones(ref);
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];

  final ahora = DateTime.now();
  final desde = DateTime(ahora.year, ahora.month - 1, ahora.day);
  final items = await ref.watch(ajusteStockRepositoryProvider).listar(
    estado: 'APLICADO',
    idAlmacen: usuario!.idAlmacenSeleccionado,
    fechaDesde: desde,
    limit: 500,
  );
  DateTime fecha(AjusteStock a) => a.fechaAplicacion ?? a.fechaConteo ?? desde;
  return items.where((a) => !fecha(a).isBefore(desde)).toList()
    ..sort((a, b) => fecha(b).compareTo(fecha(a)));
});

final ajusteStockDetalleProvider =
    FutureProvider.family.autoDispose<AjusteStockDetalle, int>((ref, idAjusteStock) {
  refrescarEnAcciones(ref);
  return ref.watch(ajusteStockRepositoryProvider).obtenerDetalle(idAjusteStock);
});

/// Búsqueda de producto para agregar items nuevos al conteo.
final ajusteBusquedaProductoProvider = StateProvider<String>((ref) => '');

final ajusteResultadosProductoProvider =
    FutureProvider.autoDispose<List<ProductoSimple>>((ref) {
  final q = ref.watch(ajusteBusquedaProductoProvider).trim();
  if (q.isEmpty) return Future.value(const []);
  return ref.watch(ajusteStockRepositoryProvider).buscarProductos(q);
});

/// Búsqueda de ubicación para el conteo (bottom sheet del formulario nuevo).
final ajusteBusquedaUbicacionProvider = StateProvider<String>((ref) => '');

final ajusteResultadosUbicacionProvider = FutureProvider.autoDispose<List<UbicacionSimple>>((ref) async {
  final q = ref.watch(ajusteBusquedaUbicacionProvider).trim();
  if (q.isEmpty) return const [];
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];
  return ref.watch(ajusteStockRepositoryProvider).buscarUbicaciones(
    idAlmacen: usuario!.idAlmacenSeleccionado!,
    q: q,
  );
});
