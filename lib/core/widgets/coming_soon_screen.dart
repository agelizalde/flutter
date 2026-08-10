import 'package:flutter/material.dart';

/// Placeholder para módulos cuya pantalla todavía no se construyó
/// (ver roadmap de fases en CONTEXTO_WHEREHOUSE.md §12).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'Módulo "$titulo" todavía no implementado.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
