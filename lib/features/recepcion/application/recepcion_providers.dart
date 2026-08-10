import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../auth/application/auth_controller.dart';
import '../../stock/application/stock_providers.dart'
    show productosApiProvider, proveedoresApiProvider;
import '../data/almacenes_api.dart';
import '../data/recepcion_repository.dart';
import '../data/recepciones_api.dart';
import '../data/ubicaciones_api.dart';
import '../domain/recepcion_models.dart';
import '../../stock/domain/stock_models.dart'
    show ProductoSimple, ProveedorSimple;

final recepcionesApiProvider = Provider<RecepcionesApi>((ref) {
  return RecepcionesApi(ref.watch(dioClientProvider).dio);
});

final almacenesApiProvider = Provider<AlmacenesApi>((ref) {
  return AlmacenesApi(ref.watch(dioClientProvider).dio);
});

final ubicacionesApiProvider = Provider<UbicacionesApi>((ref) {
  return UbicacionesApi(ref.watch(dioClientProvider).dio);
});

final recepcionRepositoryProvider = Provider<RecepcionRepository>((ref) {
  return RecepcionRepository(
    ref.watch(recepcionesApiProvider),
    ref.watch(almacenesApiProvider),
    ref.watch(ubicacionesApiProvider),
    ref.watch(productosApiProvider),
    ref.watch(proveedoresApiProvider),
  );
});

/// Últimas 5 recepciones del usuario logueado, **solo** las que están
/// `PEND_CONTROL` o `INGRESADA` (lo que el usuario necesita ver de un
/// vistazo: qué quedó pendiente de control y qué se completó) — el
/// backend no soporta filtrar por una lista de estados en una sola
/// llamada, así que se piden por separado y se mezclan/ordenan acá.
/// Se invalida a mano (`ref.invalidate`) después de crear/confirmar una
/// recepción, más simple que modelarla como `Notifier` solo para eso.
final recepcionesRecientesProvider = FutureProvider.autoDispose<List<Recepcion>>((ref) async {
  enableSilentRefresh(ref);
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario == null) return const [];

  final repo = ref.watch(recepcionRepositoryProvider);
  final resultados = await Future.wait([
    repo.listarRecepciones(
      idUsuarioReceptor: usuario.idUsuario,
      idAlmacen: usuario.idAlmacenSeleccionado,
      estado: 'PEND_CONTROL',
      limit: 5,
    ),
    repo.listarRecepciones(
      idUsuarioReceptor: usuario.idUsuario,
      idAlmacen: usuario.idAlmacenSeleccionado,
      estado: 'INGRESADA',
      limit: 5,
    ),
  ]);

  final combinadas = [...resultados[0], ...resultados[1]]
    ..sort((a, b) => b.idRecepcion.compareTo(a.idRecepcion));
  return combinadas.take(5).toList();
});

/// Historial / pendientes de control (`RecepcionHistorialScreen`, con
/// `estado` fijo opcional según desde dónde se entre). Siempre acotado al
/// **almacén base del usuario**, y **únicamente en estado `INGRESADA` o
/// `PEND_CONTROL`** (nunca BORRADOR/CONFIRMADA/CONTROLADA/ANULADA) — el
/// backend no soporta filtrar por una lista de estados en una sola
/// llamada, así que cuando no hay `estadoFijo` (Historial general) se
/// piden ambos estados por separado y se mezclan/ordenan acá, igual que
/// `recepcionesRecientesProvider`.
///
/// **Filtro por usuario receptor**: para `PEND_CONTROL` (pantalla/botón
/// "Pendientes de control") se muestran las de **todo el almacén**, sin
/// importar quién recibió — el control es una responsabilidad del
/// almacén, no de quien hizo la recepción, así que cualquiera con el
/// permiso `recepciones.controlar` debe ver todos los pendientes. Para
/// cualquier otro caso (Historial general, `INGRESADA`) se sigue
/// filtrando por el usuario logueado — cada operario ve solo lo que él
/// mismo recibió.
final recepcionListadoProvider =
    FutureProvider.family.autoDispose<List<Recepcion>, (String query, String? estado)>((ref, params) async {
  enableSilentRefresh(ref);
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario == null) return const [];

  final (query, estadoFijo) = params;
  final repo = ref.watch(recepcionRepositoryProvider);
  final q = query.isEmpty ? null : query;
  final idUsuarioReceptor = estadoFijo == 'PEND_CONTROL' ? null : usuario.idUsuario;

  if (estadoFijo != null) {
    return repo.listarRecepciones(
      q: q,
      estado: estadoFijo,
      idUsuarioReceptor: idUsuarioReceptor,
      idAlmacen: usuario.idAlmacenSeleccionado,
      limit: 50,
    );
  }

  final resultados = await Future.wait([
    repo.listarRecepciones(
      q: q,
      estado: 'PEND_CONTROL',
      idUsuarioReceptor: usuario.idUsuario,
      idAlmacen: usuario.idAlmacenSeleccionado,
      limit: 50,
    ),
    repo.listarRecepciones(
      q: q,
      estado: 'INGRESADA',
      idUsuarioReceptor: usuario.idUsuario,
      idAlmacen: usuario.idAlmacenSeleccionado,
      limit: 50,
    ),
  ]);

  return [...resultados[0], ...resultados[1]]
    ..sort((a, b) => b.idRecepcion.compareTo(a.idRecepcion));
});

final almacenesProvider = FutureProvider.autoDispose<List<AlmacenSimple>>((
  ref,
) {
  return ref.watch(recepcionRepositoryProvider).listarAlmacenes();
});

final recepcionDetalleProvider = FutureProvider.family
    .autoDispose<RecepcionDetalle, int>((ref, idRecepcion) {
      enableSilentRefresh(ref);
      return ref.watch(recepcionRepositoryProvider).obtenerDetalle(idRecepcion);
    });

/// Todo lo que necesita `RecepcionControlScreen` para armar el formulario
/// de resolución: el `id_recepcion_control` pendiente (no viene en
/// `Recepcion`, hay que buscarlo en `/recepciones/control/pendientes`), su
/// `row_version` (para el `expected_version` del resolver) y los ítems de
/// la recepción (se reusan los de `RecepcionDetalle`, ya tienen la
/// cantidad original que sirve de default para "cantidad recibida").
class PreparacionControl {
  PreparacionControl({
    required this.idRecepcionControl,
    required this.expectedVersion,
    required this.items,
  });

  final int idRecepcionControl;
  final int expectedVersion;
  final List<RecepcionItem> items;
}

final recepcionControlPreparacionProvider =
    FutureProvider.family.autoDispose<PreparacionControl, int>((ref, idRecepcion) async {
  final repo = ref.watch(recepcionRepositoryProvider);
  final pendiente = await repo.buscarControlPendiente(idRecepcion);
  if (pendiente == null) {
    throw Exception('No se encontró un control pendiente para esta recepción.');
  }
  final detalle = await repo.obtenerDetalle(idRecepcion);
  final version = await repo.obtenerVersionControl(pendiente.idRecepcionControl);
  return PreparacionControl(
    idRecepcionControl: pendiente.idRecepcionControl,
    expectedVersion: version,
    items: detalle.items,
  );
});

/// Búsqueda de producto/proveedor en los formularios de Recepción —
/// estado simple, mismo patrón que `stockSearchQueryProvider`.
final recepcionBusquedaProveedorProvider = StateProvider<String>((ref) => '');
final recepcionBusquedaProductoProvider = StateProvider<String>((ref) => '');

final recepcionResultadosProveedorProvider =
    FutureProvider.autoDispose<List<ProveedorSimple>>((ref) {
      final q = ref.watch(recepcionBusquedaProveedorProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(recepcionRepositoryProvider).buscarProveedores(q);
    });

final recepcionResultadosProductoProvider =
    FutureProvider.autoDispose<List<ProductoSimple>>((ref) {
      final q = ref.watch(recepcionBusquedaProductoProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(recepcionRepositoryProvider).buscarProductos(q);
    });
