import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../pedidos/application/pedidos_providers.dart';
import '../application/entrega_providers.dart';
import '../domain/entrega_models.dart';
import 'widgets/subpedido_entrega_tile.dart';

/// Entrada al módulo de Entrega (`/entrega`) — separado de Expedición
/// (carga del camión): la carga la puede hacer cualquiera con permiso, pero
/// la entrega al cliente solo la puede confirmar quien esté asignado como
/// responsable/chofer de esa entrega (el backend ya filtra la lista, y
/// `confirmar_entrega` lo vuelve a validar).
///
/// Lista tanto los pedidos completos (subpedido EN_ENTREGA → pantalla de
/// confirmación con fotos/novedades) como los simplificados (CONFIRMADO →
/// "Entregar" con un click, mismo endpoint que la tarjeta de
/// `PedidoInfoScreen`).
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
          data: (filas) {
            // El simplificado se entrega por PEDIDO: si tuviera más de un
            // subpedido CONFIRMADO, se muestra una sola tarjeta.
            final vistos = <int>{};
            final subpedidos = [
              for (final sp in filas)
                if (!sp.esSimplificado || vistos.add(sp.idPedido)) sp,
            ];
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
                          onTap: () => sp.esSimplificado
                              ? _entregarSimplificado(context, ref, sp)
                              : context.push('/entrega/subpedido/${sp.idPedidoSubpedido}'),
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

/// Pedido simplificado: confirma y lo da por entregado (pasa directo a
/// Pendiente de facturación, sin fotos ni novedades).
Future<void> _entregarSimplificado(BuildContext context, WidgetRef ref, SubpedidoEnEntrega sp) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Entregar pedido'),
      content: Text(
        '${sp.tituloDisplay}\n\nSe da el pedido por entregado y pasa directo a Pendiente de facturación.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Entregar'),
        ),
      ],
    ),
  );
  if (confirmar != true || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(pedidosRepositoryProvider).entregarSimplificado(sp.idPedido);
    ref.invalidate(subpedidosEnEntregaProvider);
    ref.invalidate(pedidosSeguimientoProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Pedido entregado')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(describeError(e))));
  }
}
