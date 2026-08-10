import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/entrega_providers.dart';
import 'widgets/subpedido_entrega_tile.dart';

/// Entrada al módulo de Entrega (`/entrega`) — separado de Expedición
/// (carga del camión): la carga la puede hacer cualquiera con permiso, pero
/// la entrega al cliente solo la puede confirmar quien esté asignado como
/// responsable/chofer de esa entrega (el backend ya filtra la lista, y
/// `confirmar_entrega` lo vuelve a validar).
class EntregaHomeScreen extends ConsumerWidget {
  const EntregaHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario != null && !usuario.tienePermiso('pedidos_subpedidos.entregar')) {
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
              'No tenés permiso para ver el módulo de entrega.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final async = ref.watch(subpedidosEnEntregaProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al menú principal',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Entrega de pedidos'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(subpedidosEnEntregaProvider),
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
                  'PEDIDOS PENDIENTES DE ENTREGA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                if (subpedidos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 56, color: AppColors.faint),
                          SizedBox(height: 14),
                          Text(
                            'No hay pedidos esperando confirmación de entrega',
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
                        child: SubpedidoEntregaTile(
                          subpedido: sp,
                          onTap: () => context.push('/entrega/subpedido/${sp.idPedidoSubpedido}'),
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
