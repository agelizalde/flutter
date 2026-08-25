import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Etiqueta discreta en la esquina de cada pantalla con su nombre interno,
/// para que el usuario pueda decir "en la pantalla que dice X..." al pedir
/// cambios puntuales. Solo aparece en debug (`kDebugMode`) — desaparece
/// sola en una build de release, no hace falta sacarla a mano.
class DebugScreenTag extends StatelessWidget {
  const DebugScreenTag({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;

    return Stack(
      children: [
        child,
        Positioned(
          left: 8,
          bottom: 8,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
