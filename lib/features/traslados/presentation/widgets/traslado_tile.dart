import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/parsing.dart';
import '../../domain/traslado_models.dart';

class TrasladoTile extends StatelessWidget {
  const TrasladoTile({super.key, required this.traslado});

  final Traslado traslado;

  @override
  Widget build(BuildContext context) {
    final estado = _EstadoVisual.de(traslado.estado);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/traslados/${traslado.idTraspaso}'),
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
                child: const Icon(Icons.swap_horiz_outlined, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      traslado.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${traslado.cantidadItems} ítem(s) · ${traslado.cantidadProductos} producto(s)'
                      '${traslado.fechaTraspaso != null ? ' · ${formatFecha(traslado.fechaTraspaso!)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
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
    );
  }
}

class _EstadoVisual {
  const _EstadoVisual(this.etiqueta, this.bg, this.fg);

  final String etiqueta;
  final Color bg;
  final Color fg;

  static _EstadoVisual de(String estado) {
    switch (estado) {
      case 'BORRADOR':
        return const _EstadoVisual('Borrador', AppColors.soft, AppColors.sub);
      case 'CONFIRMADO':
        return const _EstadoVisual('Confirmado', AppColors.okBg, AppColors.okTx);
      case 'ANULADO':
        return const _EstadoVisual('Anulado', AppColors.erBg, AppColors.erTx);
      default:
        return _EstadoVisual(estado, AppColors.soft, AppColors.sub);
    }
  }
}
