import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/picking_control_models.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Tile de un ítem dentro de `ControlCajonScreen` — muestra producto, lote
/// y cantidad pickeada, con dos botones (✓ aprobar directo, ✗ abre el
/// bottom sheet de rechazar/modificar cantidad). Si ya fue revisado, queda
/// resaltado con el resultado pero los botones siguen activos por si el
/// controlador se equivocó y quiere corregir su propia revisión.
class ItemControlTile extends StatelessWidget {
  const ItemControlTile({
    super.key,
    required this.item,
    required this.onAprobar,
    required this.onRechazar,
  });

  final ItemControl item;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  @override
  Widget build(BuildContext context) {
    final aprobado = item.resultadoControl == 'APROBADO';
    final rechazado = item.resultadoControl == 'RECHAZADO';

    return Material(
      color: rechazado ? AppColors.erBg : aprobado ? AppColors.okBg : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productoNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmtCantidad(item.cantidadPickeada)} ${item.unidadSimbolo}'
                    '${item.loteInterno != null ? ' · lote ${item.loteInterno}' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  if (item.pickerNombre != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Pickeado por ${item.pickerNombre}',
                      style: const TextStyle(fontSize: 11, color: AppColors.faint),
                    ),
                  ],
                  if (rechazado) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Corregido: ${_fmtCantidad(item.cantidadControlada ?? 0)} ${item.unidadSimbolo}'
                      '${item.motivosRechazo != null ? ' · ${item.motivosRechazo}' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.erTx),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CircleButton(
              icon: Icons.check,
              selected: aprobado,
              color: const Color(0xFF22C55E),
              onTap: onAprobar,
            ),
            const SizedBox(width: 8),
            _CircleButton(
              icon: Icons.close,
              selected: rechazado,
              color: AppColors.erTx,
              onTap: onRechazar,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.soft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: selected ? Colors.white : AppColors.muted),
        ),
      ),
    );
  }
}
