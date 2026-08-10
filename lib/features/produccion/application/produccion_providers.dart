import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../auth/application/auth_controller.dart';
import '../data/produccion_api.dart';
import '../data/produccion_repository.dart';
import '../domain/produccion_models.dart';

final produccionApiProvider = Provider<ProduccionApi>((ref) {
  return ProduccionApi(ref.watch(dioClientProvider).dio);
});

final produccionRepositoryProvider = Provider<ProduccionRepository>((ref) {
  return ProduccionRepository(ref.watch(produccionApiProvider));
});

/// Búsqueda de receta en `ProduccionHomeScreen`.
final produccionBusquedaRecetaProvider = StateProvider<String>((ref) => '');

final recetasListadoProvider = FutureProvider.autoDispose<List<RecetaResumen>>((ref) {
  enableSilentRefresh(ref);
  final q = ref.watch(produccionBusquedaRecetaProvider).trim();
  return ref.watch(produccionRepositoryProvider).listarRecetas(q: q.isEmpty ? null : q);
});

final recetaDetalleProvider = FutureProvider.family.autoDispose<RecetaDetalle, int>((ref, idReceta) {
  return ref.watch(produccionRepositoryProvider).obtenerReceta(idReceta);
});

/// Plantilla de etiqueta (catálogo reusable, `produccion_etiquetas`) — se
/// busca aparte de la receta usando `RecetaDetalle.etiqueta.idEtiqueta`.
final etiquetaTemplateProvider = FutureProvider.family.autoDispose<EtiquetaTemplate, int>((ref, idEtiqueta) {
  return ref.watch(produccionRepositoryProvider).obtenerEtiqueta(idEtiqueta);
});

/// Órdenes en curso (EN_PROCESO/PAUSADA) del almacén del usuario, para
/// "retomar" una producción sin tener que recordar el id.
final ordenesEnCursoProvider = FutureProvider.autoDispose<List<OrdenListItem>>((ref) async {
  enableSilentRefresh(ref);
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario?.idAlmacenSeleccionado == null) return const [];
  return ref.watch(produccionRepositoryProvider).ordenesEnCurso(idAlmacen: usuario!.idAlmacenSeleccionado!);
});

/// Detalle "en vivo" de una orden — refresco silencioso cada 15s para que
/// el cronómetro/estado se mantenga sincronizado si se pausa/reanuda desde
/// otro dispositivo (ej. la web).
final ordenDetalleProvider = FutureProvider.family.autoDispose<OrdenProduccion, int>((ref, idOrden) {
  enableSilentRefresh(ref);
  return ref.watch(produccionRepositoryProvider).obtenerOrden(idOrden);
});

/// Etiquetas de los lotes generados por una orden ya finalizada.
final etiquetasProvider = FutureProvider.family.autoDispose<List<EtiquetaProduccion>, int>((ref, idOrden) {
  return ref.watch(produccionRepositoryProvider).etiquetas(idOrden);
});
