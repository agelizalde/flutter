import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/picking_providers.dart';
import 'widgets/tarea_despickeo_tile.dart';

/// "Quitar productos" (`/picking-operario/quitar-productos`) — lista las
/// tareas de devolución/despickeo pendientes: productos que ya se habían
/// pickeado y quedaron sin sentido por un cambio posterior en Ventas
/// (cantidad, producto, regla de fulfillment) y hay que sacar del cajón de
/// armado y llevar a la ubicación de reacomodo indicada.
class QuitarProductosScreen extends ConsumerWidget {
  const QuitarProductosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tareasDespickeoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quitar productos')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tareasDespickeoProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 60),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (tareas) {
            if (tareas.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.faint),
                          SizedBox(height: 14),
                          Text(
                            'No tenés productos pendientes de sacar',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.waTx),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estos productos ya no hacen falta en el pedido — sacalos del cajón y dejalos en la ubicación indicada.',
                          style: const TextStyle(fontSize: 12, color: AppColors.waTx, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                ...tareas.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TareaDespickeoTile(tarea: t),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }
}
