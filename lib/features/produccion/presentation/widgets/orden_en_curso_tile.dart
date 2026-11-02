import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../domain/produccion_models.dart';

String _fmtReloj(int segundos) {
  final s = segundos < 0 ? 0 : segundos;
  final h = s ~/ 3600;
  final mStr = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
  final sStr = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$mStr:$sStr' : '$mStr:$sStr';
}

/// Orden EN_PROCESO/PAUSADA en "Retomar" del Home, con el cronómetro a la
/// derecha — mismo dibujo que la demo de `produccion_ayuda.dart`. Si está en
/// curso, el reloj sigue corriendo desde lo que trajo el listado.
class OrdenEnCursoTile extends StatefulWidget {
  const OrdenEnCursoTile({super.key, required this.orden});

  final OrdenListItem orden;

  @override
  State<OrdenEnCursoTile> createState() => _OrdenEnCursoTileState();
}

class _OrdenEnCursoTileState extends State<OrdenEnCursoTile> {
  Timer? _tick;
  late DateTime _base;

  bool get _pausada => widget.orden.estado == 'PAUSADA';

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  @override
  void didUpdateWidget(OrdenEnCursoTile old) {
    super.didUpdateWidget(old);
    if (old.orden != widget.orden) _reiniciar();
  }

  void _reiniciar() {
    _base = DateTime.now();
    _tick?.cancel();
    _tick = _pausada
        ? null
        : Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() {});
          });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orden = widget.orden;
    final pausada = _pausada;
    final color = pausada ? AppColors.waTx : const Color(0xFF16A34A);
    final bg = pausada ? AppColors.waBg : AppColors.okBg;
    final segundos = orden.tiempoTranscurridoSegundos + (pausada ? 0 : DateTime.now().difference(_base).inSeconds);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/produccion/taller/${orden.idOrden}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bg, width: 1.4),
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
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(
                  pausada ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  color: color,
                  size: 22,
                ),
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
                      '${orden.codigo} · ${pausada ? 'Pausada' : 'En curso'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _fmtReloj(segundos),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
