import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Rótulo de sección uppercase + ícono muted — mismo look en todas las
/// pantallas del flujo de Producción (Home, Nueva) para que se sientan
/// parte de la misma pantalla aunque estén en archivos distintos.
class SeccionLabel extends StatelessWidget {
  const SeccionLabel({super.key, required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 15, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted)),
      ],
    );
  }
}
