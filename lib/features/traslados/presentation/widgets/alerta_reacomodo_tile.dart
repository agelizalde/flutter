import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/parsing.dart';
import '../../domain/traslado_models.dart';

/// Fila de una alerta de reacomodo (existencia parada en RECEPCION/
/// REACOMODO). Si ya tiene un traslado BORRADOR (`idTraspasoBorrador`), el
/// botón cambia a "Ver traslado" en vez de "Trasladar" para no duplicar.
class AlertaReacomodoTile extends StatelessWidget {
  const AlertaReacomodoTile({
    super.key,
    required this.alerta,
    required this.onTrasladar,
    required this.onVerTraslado,
  });

  final AlertaReacomodo alerta;
  final VoidCallback onTrasladar;
  final ValueChanged<int> onVerTraslado;

  @override
  Widget build(BuildContext context) {
    final tieneBorrador = alerta.idTraspasoBorrador != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.move_down_outlined, color: AppColors.waTx, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alerta.productoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${alerta.ubicacionNombre} (${alerta.ubicacionCodigo}) · Lote ${alerta.loteInterno}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Disponible: ${alerta.cantidadDisponible.toStringAsFixed(0)} ${alerta.unidadSimbolo}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    if (alerta.fechaVencimiento != null)
                      Text(
                        'Vence ${formatFecha(alerta.fechaVencimiento!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // El tema global fuerza `minimumSize: Size.fromHeight(50)` (ancho
          // infinito) en estos botones, pensado para que ocupen todo el
          // ancho dentro de una Column (como en el resto de la app) — acá
          // van compactos dentro de un Row, así que hay que acotar el
          // tamaño explícitamente o el ancho infinito choca con el ancho
          // acotado del Row y rompe el layout.
          if (tieneBorrador)
            OutlinedButton(
              onPressed: () => onVerTraslado(alerta.idTraspasoBorrador!),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Ver traslado'),
            )
          else
            ElevatedButton(
              onPressed: onTrasladar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Trasladar'),
            ),
        ],
      ),
    );
  }
}
