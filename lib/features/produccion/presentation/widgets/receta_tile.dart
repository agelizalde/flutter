import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/produccion_models.dart';

String _fmtDuracionCorta(int segundos) {
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}min';
  return '${m}min';
}

/// Tarjeta de receta para elegir qué producir — insignia de nivel (tier)
/// según cuántas veces se produjo, look "gamificado" simple sin depender de
/// paquetes de animación.
class RecetaTile extends StatelessWidget {
  const RecetaTile({super.key, required this.receta, required this.onTap});

  final RecetaResumen receta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tier = tierInfoFor(receta.vecesProducida);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: tier.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Icon(tier.icon, color: tier.color, size: 24),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: tier.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            '${tier.label} · ${receta.vecesProducida}x',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tier.color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.timer_outlined, size: 13, color: AppColors.faint),
                        const SizedBox(width: 3),
                        Text(
                          _fmtDuracionCorta(receta.tiempoReferenciaSegundos),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
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
