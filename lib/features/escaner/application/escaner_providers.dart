import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../pedidos/application/pedidos_providers.dart';
import '../../picking_operario/application/picking_providers.dart';
import '../../produccion/application/produccion_providers.dart';
import '../../recepcion/application/recepcion_providers.dart';
import '../../stock/application/stock_providers.dart';
import '../data/escaner_repository.dart';

final escanerRepositoryProvider = Provider<EscanerRepository>((ref) {
  return EscanerRepository(
    ref.watch(productosApiProvider),
    ref.watch(stockRepositoryProvider),
    ref.watch(recepcionRepositoryProvider),
    ref.watch(pedidosRepositoryProvider),
    ref.watch(produccionRepositoryProvider),
    ref.watch(pickingRepositoryProvider),
  );
});
