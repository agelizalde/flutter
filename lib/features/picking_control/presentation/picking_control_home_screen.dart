import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/picking_control_providers.dart';
import 'widgets/subpedido_control_tile.dart';

/// Entrada al módulo de control de picking (`/picking-control`). Lista los
/// subpedidos con al menos un cajón cerrado (o un pick sin cajón con sesión
/// finalizada) — el criterio exacto de "listo para control" lo resuelve el
/// backend, acá solo se muestra lo que ya viene filtrado.
class PickingControlHomeScreen extends ConsumerWidget {
  const PickingControlHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario != null && !usuario.tienePermiso('control_picking.controlar')) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver al menú principal',
            onPressed: () => context.go('/'),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tenés permiso para ver el módulo de control de picking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final async = ref.watch(subpedidosControlProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al menú principal',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Control de picking'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(subpedidosControlProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 60),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (subpedidos) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'SUBPEDIDOS PARA CONTROLAR',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                if (subpedidos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.fact_check_outlined, size: 56, color: AppColors.faint),
                          SizedBox(height: 14),
                          Text(
                            'No hay subpedidos listos para controlar por ahora',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...subpedidos.map((sp) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SubpedidoControlTile(
                          subpedido: sp,
                          onTap: () => context.push('/picking-control/subpedido/${sp.idPedidoSubpedido}'),
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}
