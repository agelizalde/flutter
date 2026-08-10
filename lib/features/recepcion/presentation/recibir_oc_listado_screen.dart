import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/recepcion_oc_providers.dart';
import '../domain/orden_compra_models.dart';

/// Paso 2 del flujo "Recibir OC" (solo cuando se llegó eligiendo proveedor
/// a mano, no escaneando): elegí cuál de sus OC aprobadas vas a recibir.
class RecibirOcListadoScreen extends ConsumerWidget {
  const RecibirOcListadoScreen({super.key, required this.idProveedor, this.nombreProveedor});

  final int idProveedor;
  final String? nombreProveedor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recepcionOcAprobadasProvider(idProveedor));

    return Scaffold(
      appBar: AppBar(title: Text(nombreProveedor ?? 'OC aprobadas')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recepcionOcAprobadasProvider(idProveedor)),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 60),
                  Icon(Icons.inbox_outlined, size: 40, color: AppColors.faint),
                  SizedBox(height: 12),
                  Text(
                    'Este proveedor no tiene OC aprobadas con saldo pendiente en tu almacén.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final oc = items[i];
                return _OcTile(
                  oc: oc,
                  onTap: () => context.push('/recepcion/oc/${oc.idOc}/items'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OcTile extends StatelessWidget {
  const _OcTile({required this.oc, required this.onTap});

  final OrdenCompraSimple oc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.description_outlined, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oc.codigo,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${oc.itemsPendientes} ítem(s) pendiente(s)',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                        if (oc.fechaEntrega != null)
                          Text(
                            'Entrega ${formatFecha(oc.fechaEntrega!)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
