import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/creador_api.dart';
import '../domain/creador_models.dart';

final creadorApiProvider = Provider<CreadorApi>((ref) {
  return CreadorApi(ref.watch(dioClientProvider).dio);
});

/// Almacén "base" del usuario logueado (`id_almacen_seleccionado`, ver
/// `UsuarioActual`) — Zonas y Ubicaciones se crean siempre ahí, el
/// formulario simple no lo pide (mismo criterio que
/// `project_traslados_solicitudes_recepcion`).
final creadorAlmacenActualProvider = Provider.autoDispose<int?>((ref) {
  return ref.watch(authControllerProvider).value?.idAlmacenSeleccionado;
});

// =========================================================
// PROVEEDORES — búsqueda + listado de la pestaña
// =========================================================

final creadorProveedoresQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final creadorProveedoresListProvider =
    FutureProvider.autoDispose<List<ProveedorCreador>>((ref) {
      final q = ref.watch(creadorProveedoresQueryProvider);
      return ref.watch(creadorApiProvider).proveedoresListar(q: q);
    });

// =========================================================
// MARCAS
// =========================================================

final creadorMarcasQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final creadorMarcasListProvider =
    FutureProvider.autoDispose<List<MarcaCreador>>((ref) {
      final q = ref.watch(creadorMarcasQueryProvider);
      return ref.watch(creadorApiProvider).marcasListar(q: q);
    });

// =========================================================
// PRODUCTOS
// =========================================================

final creadorProductosQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final creadorProductosListProvider =
    FutureProvider.autoDispose<List<ProductoCreador>>((ref) {
      final q = ref.watch(creadorProductosQueryProvider);
      return ref.watch(creadorApiProvider).productosListar(q: q);
    });

// =========================================================
// CÓDIGOS DE BARRA
// =========================================================

/// Producto elegido en la pestaña "Código de barra" — a diferencia de los
/// demás catálogos, acá primero hay que elegir un producto y recién
/// entonces se ve/agrega su lista de códigos (flujo de 2 pasos, ver
/// `CodigosBarraTab`).
final creadorCodigosBarraProductoProvider =
    StateProvider.autoDispose<ProductoCreador?>((ref) => null);

final creadorCodigosBarraQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final creadorCodigosBarraListProvider =
    FutureProvider.autoDispose<List<CodigoBarraCreador>>((ref) async {
      final producto = ref.watch(creadorCodigosBarraProductoProvider);
      if (producto == null) return const [];
      final q = ref.watch(creadorCodigosBarraQueryProvider);
      return ref
          .watch(creadorApiProvider)
          .codigosBarraListar(idProducto: producto.idProducto, q: q);
    });

// =========================================================
// ZONAS
// =========================================================

final creadorZonasQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final creadorZonasListProvider = FutureProvider.autoDispose<List<ZonaCreador>>((
  ref,
) async {
  final idAlmacen = ref.watch(creadorAlmacenActualProvider);
  if (idAlmacen == null) return const [];
  final q = ref.watch(creadorZonasQueryProvider);
  return ref.watch(creadorApiProvider).zonasListar(idAlmacen: idAlmacen, q: q);
});

// =========================================================
// UBICACIONES
// =========================================================

final creadorUbicacionesQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

final creadorUbicacionesListProvider =
    FutureProvider.autoDispose<List<UbicacionCreador>>((ref) async {
      final idAlmacen = ref.watch(creadorAlmacenActualProvider);
      if (idAlmacen == null) return const [];
      final q = ref.watch(creadorUbicacionesQueryProvider);
      return ref
          .watch(creadorApiProvider)
          .ubicacionesListar(idAlmacen: idAlmacen, q: q);
    });

/// Todas las zonas del almacén actual, sin depender del texto de búsqueda
/// de la pestaña — la usan el picker de zona en el alta de Ubicación y el
/// propio tab de Zonas al armar el picker de "ubicación padre" (que primero
/// necesita saber en qué zona buscar).
final creadorZonasDelAlmacenProvider =
    FutureProvider.autoDispose<List<ZonaCreador>>((ref) async {
      final idAlmacen = ref.watch(creadorAlmacenActualProvider);
      if (idAlmacen == null) return const [];
      return ref.watch(creadorApiProvider).zonasListar(idAlmacen: idAlmacen);
    });
