import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/produccion_models.dart';

String _fmtDuracionCorta(int segundos) {
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}min';
  return '${m}min';
}

/// Tarjeta de receta para elegir qué producir — look plano y consistente
/// (mismo ícono/acento de marca para todas), sin insignias de "nivel" por
/// cuántas veces se produjo.
class RecetaTile extends StatelessWidget {
  const RecetaTile({super.key, required this.receta, required this.onTap});

  final RecetaResumen receta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.receipt_long_outlined, color: AppColors.accentDark, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receta.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      receta.productoPrincipalNombre ?? receta.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 13, color: AppColors.faint),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDuracionCorta(receta.tiempoReferenciaSegundos),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                        ),
                        if (receta.vecesProducida > 0) ...[
                          const SizedBox(width: 10),
                          const Icon(Icons.circle, size: 3, color: AppColors.faint),
                          const SizedBox(width: 10),
                          Text(
                            'Producida ${receta.vecesProducida}x',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
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
