import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../domain/recepcion_models.dart';

/// Fila de recepción reusada por `RecepcionHomeScreen` (últimas 5) y
/// `RecepcionHistorialScreen` (historial completo) — una sola definición
/// para que ambas pantallas se vean y comporten igual.
class RecepcionTile extends StatelessWidget {
  const RecepcionTile({super.key, required this.recepcion});

  final Recepcion recepcion;

  @override
  Widget build(BuildContext context) {
    final estado = EstadoRecepcionVisual.de(recepcion.estado);
    final esPendienteControl = recepcion.estado == 'PEND_CONTROL';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/recepcion/${recepcion.idRecepcion}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: esPendienteControl ? AppColors.alertBg : AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    esPendienteControl ? Icons.warning_amber_rounded : Icons.move_to_inbox_outlined,
                    color: esPendienteControl ? AppColors.alertTx : AppColors.accentDark,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recepcion.proveedorNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${recepcion.almacenNombre} · ${recepcion.itemsActivos} ítem(s)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      if (recepcion.requiereControl) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            'Recepcionó: ${recepcion.receptorUsername ?? '—'}',
                            if (recepcion.usuarioControlUsername != null)
                              'Controló: ${recepcion.usuarioControlUsername}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.faint),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: estado.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    estado.etiqueta,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estado.fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EstadoRecepcionVisual {
  const EstadoRecepcionVisual(this.etiqueta, this.bg, this.fg);

  final String etiqueta;
  final Color bg;
  final Color fg;

  static EstadoRecepcionVisual de(String estado) {
    switch (estado) {
      case 'BORRADOR':
        return const EstadoRecepcionVisual('Borrador', AppColors.soft, AppColors.sub);
      case 'CONFIRMADA':
        return const EstadoRecepcionVisual('Confirmada', AppColors.inBg, AppColors.inTx);
      case 'PEND_CONTROL':
        return const EstadoRecepcionVisual('Pend. control', AppColors.waBg, AppColors.waTx);
      case 'CONTROLADA':
        return const EstadoRecepcionVisual('Controlada', AppColors.inBg, AppColors.inTx);
      case 'INGRESADA':
        return const EstadoRecepcionVisual('Ingresada', AppColors.okBg, AppColors.okTx);
      case 'ANULADA':
        return const EstadoRecepcionVisual('Anulada', AppColors.erBg, AppColors.erTx);
      default:
        return EstadoRecepcionVisual(estado, AppColors.soft, AppColors.sub);
    }
  }
}
