import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../domain/produccion_models.dart';

/// Fila de "Mis producciones" — historial de órdenes FINALIZADAS (ver
/// `ProduccionRepository.misProducciones`), a diferencia de
/// [OrdenEnCursoTile] que atiende el trabajo pendiente ("Retomar" en el
/// Home, EN_PROCESO/PAUSADA).
class MiProduccionTile extends StatelessWidget {
  const MiProduccionTile({super.key, required this.orden});

  final OrdenListItem orden;

  String _fmtFecha(DateTime f) {
    final d = f.day.toString().padLeft(2, '0');
    final m = f.month.toString().padLeft(2, '0');
    return '$d/$m/${f.year} ${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final fecha = orden.finalizadoEn ?? orden.creadoEn;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/produccion/ordenes/${orden.idOrden}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.okBg, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.check_circle_outline, color: AppColors.okTx, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orden.recetaNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [orden.codigo, if (fecha != null) _fmtFecha(fecha)].join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppColors.okTx, fontWeight: FontWeight.w600),
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
