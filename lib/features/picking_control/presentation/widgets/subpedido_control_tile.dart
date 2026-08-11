import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/picking_control_models.dart';

/// Tile de un subpedido disponible para controlar, para
/// `PickingControlHomeScreen` — mismo lenguaje visual que
/// `SubpedidoPickingTile` de Picking Operario.
class SubpedidoControlTile extends StatelessWidget {
  const SubpedidoControlTile({super.key, required this.subpedido, required this.onTap, this.miIdUsuario});

  final SubpedidoControl subpedido;
  final VoidCallback onTap;

  /// Usuario logueado, para distinguir "asignado a vos" de "asignado a otro"
  /// en el badge -- `null` si todavía no cargó.
  final int? miIdUsuario;

  @override
  Widget build(BuildContext context) {
    final activo = subpedido.controlActivo;
    final asignacion = subpedido.asignacion;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subpedido.tituloDisplay,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${subpedido.totalItems} ítem${subpedido.totalItems != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                    ),
                  ),
                ],
              ),
              if (subpedido.codigoPedido != null) ...[
                const SizedBox(height: 3),
                Text(
                  subpedido.codigoPedido!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
              if (activo != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.visibility_outlined, size: 14, color: AppColors.waTx),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'En control por ${activo.controladorNombre ?? 'otro usuario'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.waTx),
                      ),
                    ),
                  ],
                ),
              ] else if (asignacion != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.person_pin_circle_outlined,
                      size: 14,
                      color: asignacion.idUsuarioAsignado == miIdUsuario ? AppColors.okTx : AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        asignacion.idUsuarioAsignado == miIdUsuario
                            ? 'Asignado a vos · ${asignacion.modoControl.toLowerCase()}'
                            : 'Asignado a ${asignacion.nombreAsignado ?? 'otro usuario'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: asignacion.idUsuarioAsignado == miIdUsuario ? AppColors.okTx : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
