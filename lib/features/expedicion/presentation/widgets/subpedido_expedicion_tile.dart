import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/expedicion_models.dart';

/// Tile de un subpedido en EN_CARGA, para `ExpedicionHomeScreen` — mismo
/// lenguaje visual que `SubpedidoControlTile` de Control de picking.
class SubpedidoExpedicionTile extends StatelessWidget {
  const SubpedidoExpedicionTile({super.key, required this.subpedido, required this.onTap});

  final SubpedidoEnCarga subpedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listo = subpedido.totalLineas > 0 && subpedido.pendientes == 0;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subpedido.tituloDisplay,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: listo ? AppColors.okBg : AppColors.waBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      listo ? 'Listo' : '${subpedido.pendientes} pend.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: listo ? AppColors.okTx : AppColors.waTx,
                      ),
                    ),
                  ),
                ],
              ),
              if (subpedido.codigoPedido != null) ...[
                const SizedBox(height: 3),
                Text(
                  subpedido.codigoPedido!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
              if (subpedido.modoCarga != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      subpedido.modoCarga == 'ESCANEO' ? Icons.qr_code_scanner : Icons.dialpad,
                      size: 14,
                      color: AppColors.accentDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      subpedido.modoCarga == 'ESCANEO' ? 'Modo escaneo' : 'Modo conteo',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accentDark),
                    ),
                  ],
                ),
              ],
              if (subpedido.metodoEntrega == 'TERCERIZADO') ...[
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.muted),
                    SizedBox(width: 6),
                    Text(
                      'Tercerizado — sin asignar',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ] else if (subpedido.responsablesNombres != null && subpedido.responsablesNombres!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        subpedido.responsablesNombres!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
