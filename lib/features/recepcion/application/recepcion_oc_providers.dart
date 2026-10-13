import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../domain/orden_compra_models.dart';
import '../domain/recepcion_models.dart';
import 'recepcion_providers.dart';

/// OC aprobadas de un proveedor, acotadas al almacén base del usuario
/// (mismo criterio que el resto del módulo: nunca se elige almacén a
/// mano). Alimenta la pantalla "elegí qué OC vas a recibir" del flujo por
/// selección manual de proveedor.
final recepcionOcAprobadasProvider =
    FutureProvider.family.autoDispose<List<OrdenCompraSimple>, int>((ref, idProveedor) async {
  final usuario = await ref.watch(authControllerProvider.future);
  return ref.watch(recepcionRepositoryProvider).listarOcAprobadas(
        idProveedor: idProveedor,
        idAlmacen: usuario?.idAlmacenSeleccionado,
      );
});

/// Todas las OC aprobadas con saldo pendiente en el almacén base del
/// usuario, sin acotar a un proveedor — alimenta la pantalla "OC
/// pendientes" (menú ⚙️ de Recepción-inicio), que muestra de un vistazo
/// qué queda por recibir y cuándo.
final recepcionOcPendientesTodasProvider =
    FutureProvider.autoDispose<List<OrdenCompraSimple>>((ref) async {
  final usuario = await ref.watch(authControllerProvider.future);
  return ref.watch(recepcionRepositoryProvider).listarOcAprobadas(
        idAlmacen: usuario?.idAlmacenSeleccionado,
      );
});

/// Header + ítems pendientes de la OC elegida (por escaneo o por
/// selección), lo que necesita la pantalla de tarjetas de ítems.
final recepcionOcDetalleProvider =
    FutureProvider.family.autoDispose<OrdenCompraDetalle, int>((ref, idOc) {
  return ref.watch(recepcionRepositoryProvider).obtenerOcParaRecepcion(idOc);
});

/// Si la OC ya tiene una recepción en BORRADOR sin confirmar (típicamente
/// porque quedó esperando que se apruebe/firme un exceso de cantidad), la
/// trae acá en vez de dejar que `RecibirOcItemsScreen` cree otra — crearla
/// de nuevo duplicaría la cantidad recibida si ambas llegan a confirmarse
/// (el backend ya lo rechaza con 409, ver `recepcion_oc.py`, pero conviene
/// avisar antes de que la persona cargue de nuevo todos los ítems). `null`
/// si no hay ninguna.
final recepcionOcBorradorExistenteProvider =
    FutureProvider.family.autoDispose<Recepcion?, int>((ref, idOc) async {
  final recepciones = await ref.watch(recepcionRepositoryProvider).recepcionesPorOc(idOc);
  for (final r in recepciones) {
    if (r.estado == 'BORRADOR') return r;
  }
  return null;
});

/// Header + TODOS los ítems de una OC (no solo pendientes), sin exigir
/// estado recepcionable — para la vista de solo lectura del escáner
/// (`OcInfoScreen`).
final ocInfoDetalleProvider =
    FutureProvider.family.autoDispose<OrdenCompraDetalle, int>((ref, idOc) {
  return ref.watch(recepcionRepositoryProvider).obtenerOcInfoPorId(idOc);
});
