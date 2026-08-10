import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/entrega_models.dart';

/// Tile de un subpedido en EN_ENTREGA, para `EntregaHomeScreen` — mismo
/// lenguaje visual que `SubpedidoExpedicionTile` (módulo de carga).
class SubpedidoEntregaTile extends StatelessWidget {
  const SubpedidoEntregaTile({super.key, required this.subpedido, required this.onTap});

  final SubpedidoEnEntrega subpedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'En ruta',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDark),
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
              if (subpedido.metodoEntrega == 'TERCERIZADO') ...[
                const SizedBox(height: 6),
                Row(
                  children: const [
                    Icon(Icons.local_shipping_outlined, size: 14, color: AppColors.muted),
                    SizedBox(width: 6),
                    Text(
                      'Tercerizado',
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
