import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/picking_models.dart';

/// Tile de un subpedido con tareas de picking asignadas, para
/// `PickingHomeScreen` — mismo lenguaje visual que `RecepcionTile`/tarjetas
/// de resultado de Traslados (Material + InkWell, sin `ListTile` plano).
class SubpedidoPickingTile extends StatelessWidget {
  const SubpedidoPickingTile({super.key, required this.subpedido, required this.onTap});

  final SubpedidoPicking subpedido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = subpedido.total;
    final completadas = subpedido.completadas;
    final pct = total > 0 ? completadas / total : 0.0;
    final listo = total > 0 && completadas == total;

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
                      listo ? 'Listo' : '$completadas/$total',
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
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: AppColors.soft,
                  color: listo ? const Color(0xFF22C55E) : AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
