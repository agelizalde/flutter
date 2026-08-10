import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/picking_providers.dart';
import 'widgets/subpedido_picking_tile.dart';

String _fmtDuracionCorta(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Entrada al módulo de picking del operario (`/picking-operario`). Si hay
/// una sesión de zona activa, la destaca arriba con acceso directo a
/// `PickingTrabajoScreen`; si no, lista los subpedidos con tareas asignadas
/// al usuario logueado para elegir zona.
class PickingHomeScreen extends ConsumerWidget {
  const PickingHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario != null && !usuario.tienePermiso('picking_operario.ver')) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tenés permiso para ver el módulo de picking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final async = ref.watch(misTareasProvider);
    final despickeoAsync = ref.watch(tareasDespickeoProvider);
    final tareasDespickeo = despickeoAsync.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al menú principal',
          onPressed: () => context.go('/'),
        ),
        title: const Text('Picking'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(misTareasProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 60),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (data) {
            // Solo subpedidos donde al operario le queda al menos una tarea
            // pendiente — uno donde ya completó todo no es un picking
            // "pendiente" aunque el backend lo siga trayendo (por si otra
            // pantalla necesita verlo igual, ej. para revisar lo ya hecho).
            final subpedidos = data.subpedidos.where((sp) => sp.tienePendientes).toList();
            final sesion = data.sesionActiva;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (sesion != null) ...[
                  Material(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/picking-operario/trabajo'),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Zona en curso',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Subpedido #${sesion.idPedidoSubpedido} · ${_fmtDuracionCorta(DateTime.now().difference(sesion.iniciadoEn))}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (tareasDespickeo.isNotEmpty) ...[
                  Material(
                    color: AppColors.waBg,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/picking-operario/quitar-productos'),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.undo_rounded, color: AppColors.waTx, size: 28),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quitar productos',
                                    style: TextStyle(color: AppColors.waTx, fontWeight: FontWeight.w800, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${tareasDespickeo.length} producto${tareasDespickeo.length != 1 ? 's' : ''} para sacar del cajón',
                                    style: const TextStyle(color: AppColors.waTx, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.waTx),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'MIS SUBPEDIDOS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                if (subpedidos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: AppColors.faint),
                          SizedBox(height: 14),
                          Text(
                            'Actualmente no tenés ningún picking pendiente',
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
                        child: SubpedidoPickingTile(
                          subpedido: sp,
                          onTap: () {
                            if (sesion != null && sesion.idPedidoSubpedido != sp.idPedidoSubpedido) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Terminá tu zona activa antes de iniciar otra.')),
                              );
                              return;
                            }
                            if (sesion != null && sesion.idPedidoSubpedido == sp.idPedidoSubpedido) {
                              context.push('/picking-operario/trabajo');
                              return;
                            }
                            context.push('/picking-operario/subpedido/${sp.idPedidoSubpedido}/zona');
                          },
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
