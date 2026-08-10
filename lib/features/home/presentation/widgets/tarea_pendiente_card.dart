import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../application/home_providers.dart';

/// Fila de "Pendientes para vos" / "Notificaciones" — ícono en círculo de
/// color de prioridad + título + descripción, estilo lista plana (no
/// tarjeta con sombra pesada). Compartida entre `HomeScreen` (tope de 4) y
/// `NotificacionesScreen` (lista completa).
class TareaPendienteCard extends StatelessWidget {
  const TareaPendienteCard({super.key, required this.tarea});

  final TareaPendiente tarea;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(tarea.ruta),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: tarea.colorPrioridad, shape: BoxShape.circle),
                child: Icon(tarea.icono, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarea.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tarea.descripcion,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
