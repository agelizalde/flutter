import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../domain/orden_compra_models.dart';
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

/// Header + ítems pendientes de la OC elegida (por escaneo o por
/// selección), lo que necesita la pantalla de tarjetas de ítems.
final recepcionOcDetalleProvider =
    FutureProvider.family.autoDispose<OrdenCompraDetalle, int>((ref, idOc) {
  return ref.watch(recepcionRepositoryProvider).obtenerOcParaRecepcion(idOc);
});

/// Header + TODOS los ítems de una OC (no solo pendientes), sin exigir
/// estado recepcionable — para la vista de solo lectura del escáner
/// (`OcInfoScreen`).
final ocInfoDetalleProvider =
    FutureProvider.family.autoDispose<OrdenCompraDetalle, int>((ref, idOc) {
  return ref.watch(recepcionRepositoryProvider).obtenerOcInfoPorId(idOc);
});
