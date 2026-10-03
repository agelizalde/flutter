import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pedidos/application/pedidos_providers.dart';
import '../../picking_operario/application/picking_providers.dart';
import '../../produccion/application/produccion_providers.dart';
import '../../recepcion/application/recepcion_providers.dart';
import '../../stock/application/stock_providers.dart' show productosApiProvider;
import '../data/escaner_repository.dart';

final escanerRepositoryProvider = Provider<EscanerRepository>((ref) {
  return EscanerRepository(
    ref.watch(productosApiProvider),
    ref.watch(ubicacionesApiProvider),
    ref.watch(zonasApiProvider),
    ref.watch(recepcionRepositoryProvider),
    ref.watch(pedidosRepositoryProvider),
    ref.watch(produccionRepositoryProvider),
    ref.watch(pickingRepositoryProvider),
  );
});
