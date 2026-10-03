import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../data/vehiculos_api.dart';
import '../data/vehiculos_repository.dart';
import '../domain/vehiculo_models.dart';

final vehiculosApiProvider = Provider<VehiculosApi>((ref) {
  return VehiculosApi(ref.watch(dioClientProvider).dio);
});

final vehiculosRepositoryProvider = Provider<VehiculosRepository>((ref) {
  return VehiculosRepository(ref.watch(vehiculosApiProvider));
});

/// Texto de búsqueda de la lista de vehículos — mismo patrón que
/// `creadorProductosQueryProvider`: vive en un provider aparte para no
/// reconstruir toda la pantalla al tipear.
final vehiculosQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final vehiculosListProvider = FutureProvider.autoDispose<List<Vehiculo>>((ref) {
  final q = ref.watch(vehiculosQueryProvider);
  return ref.watch(vehiculosRepositoryProvider).listar(q: q.isEmpty ? null : q, activo: true);
});

final vehiculoDetalleProvider = FutureProvider.autoDispose.family<Vehiculo, int>((ref, idVehiculo) {
  return ref.watch(vehiculosRepositoryProvider).detalle(idVehiculo);
});

final mantenimientosProvider = FutureProvider.autoDispose.family<List<Mantenimiento>, int>((ref, idVehiculo) {
  return ref.watch(vehiculosRepositoryProvider).mantenimientos(idVehiculo);
});
