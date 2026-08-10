import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/legacy.dart';

import '../../../core/utils/silent_refresh.dart';
import '../../picking_operario/application/picking_providers.dart';
import '../../picking_operario/domain/picking_models.dart';
import '../../recepcion/application/recepcion_providers.dart';
import '../../recepcion/domain/orden_compra_models.dart';
import '../../stock/application/stock_providers.dart';
import '../../stock/domain/stock_models.dart';

/// Texto de búsqueda del buscador de Home (ya debounceado por la UI) —
/// dispara en paralelo búsqueda de producto por nombre, ubicación por
/// nombre/código y OC por código exacto.
final escanerQueryProvider = StateProvider<String>((ref) => '');

/// Catálogo general (`GET /productos`), no la vista atada a
/// `stock_existencias` (`ProductoConStock`/`buscarPorNombre`) — esa solo
/// devuelve productos que alguna vez tuvieron una existencia registrada.
/// Acá tiene que aparecer cualquier físico o servicio aunque nunca haya
/// tenido movimiento de stock (`manejaStock: null` = sin filtrar), y
/// quedan afuera los ficticios (`esComercial: false`).
final escanerProductosResultsProvider =
    FutureProvider.autoDispose<List<ProductoSimple>>((ref) {
      enableSilentRefresh(ref);
      final q = ref.watch(escanerQueryProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(productosApiProvider).buscar(q: q, manejaStock: null, esComercial: false);
    });

final escanerUbicacionesResultsProvider =
    FutureProvider.autoDispose<List<UbicacionStock>>((ref) {
      enableSilentRefresh(ref);
      final q = ref.watch(escanerQueryProvider).trim();
      if (q.isEmpty) return Future.value(const []);
      return ref.watch(stockRepositoryProvider).buscarUbicaciones(q);
    });

/// La OC solo se resuelve por código exacto (no hay búsqueda parcial de OC
/// fuera del flujo de recepción aprobada) — `null` mientras no haya un
/// match exacto, sin distinguir "no encontrada" de "todavía no escribió
/// el código completo".
final escanerOcResultProvider = FutureProvider.autoDispose<OrdenCompraDetalle?>((ref) async {
  final q = ref.watch(escanerQueryProvider).trim();
  if (q.isEmpty) return null;
  try {
    return await ref.watch(recepcionRepositoryProvider).obtenerOcInfoPorCodigo(q);
  } catch (e) {
    if (e is DioException && e.response?.statusCode == 404) return null;
    rethrow;
  }
});

/// El contenedor, igual que la OC, solo se resuelve por código exacto
/// (identificador o código de barras, ej. "COS-00003") — `null` mientras no
/// haya un match exacto.
final escanerContenedorResultProvider = FutureProvider.autoDispose<ContenedorDetalle?>((ref) async {
  final q = ref.watch(escanerQueryProvider).trim();
  if (q.isEmpty) return null;
  try {
    return await ref.watch(pickingRepositoryProvider).buscarContenedorDetalle(q);
  } catch (e) {
    if (e is DioException && e.response?.statusCode == 404) return null;
    rethrow;
  }
});
