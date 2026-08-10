import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../ajuste_stock/domain/ajuste_stock_models.dart' show labelMotivoAjuste;
import '../../ajuste_stock/presentation/nuevo_ajuste_screen.dart';
import '../application/ajuste_stock_solicitudes_providers.dart';
import '../domain/solicitud_models.dart';

/// Tareas pendientes asignadas al usuario logueado (flujo B de Ajuste de
/// Stock). Se llega acá desde el banner del Home o desde el módulo de
/// Ajuste de Stock. Tocar una tarea lleva directo al conteo
/// (`NuevoAjusteScreen` con la ubicación/motivo ya fijados).
class MisSolicitudesScreen extends ConsumerWidget {
  const MisSolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misSolicitudesPendientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis solicitudes')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(misSolicitudesPendientesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 60),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (solicitudes) {
            if (solicitudes.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: AppColors.faint),
                          SizedBox(height: 14),
                          Text(
                            'No tenés ningún control de stock pendiente',
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
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: solicitudes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _SolicitudTile(solicitud: solicitudes[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({required this.solicitud});

  final SolicitudAjusteStock solicitud;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => NuevoAjusteScreen(solicitud: solicitud)),
            );
            if (context.mounted) {
              ProviderScope.containerOf(context).invalidate(misSolicitudesPendientesProvider);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.fact_check_outlined, color: AppColors.waTx, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${solicitud.ubicacionNombre} (${solicitud.ubicacionCodigo})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        labelMotivoAjuste(solicitud.motivoCategoria),
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      if (solicitud.solicitanteNombre != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Pedido por ${solicitud.solicitanteNombre}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
