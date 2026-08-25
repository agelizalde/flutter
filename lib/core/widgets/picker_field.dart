import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Botón con forma de input que abre un [showSelectorSheet] — mismo rol
/// visual que un `DropdownButtonFormField` pero para listas que necesitan
/// búsqueda (marca, categoría, unidad, IVA, proveedor, zona, ubicación
/// padre, cliente, sucursal, lugar de entrega, vehículo...). Nació en el
/// módulo Creador y hoy lo comparten también los formularios de Pedidos,
/// de ahí que viva en `core/widgets` y no en una sola feature.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.placeholder = 'Seleccionar...',
    this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool enabled;
  final String placeholder;

  /// Si no es nulo, se muestra una "x" junto a la flecha cuando hay un
  /// valor elegido — para campos opcionales donde volver a "sin elegir" no
  /// tiene otra forma más corta que reabrir el picker y buscar la opción
  /// vacía (ej. ETA en `NuevoPedidoSheet`).
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Material(
          color: AppColors.soft,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value ?? placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: value != null ? AppColors.text : AppColors.faint,
                        fontWeight: value != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (onClear != null && value != null) ...[
                    InkWell(
                      onTap: onClear,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.close,
                          color: AppColors.muted,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(
                    Icons.expand_more,
                    color: enabled ? AppColors.muted : AppColors.faint,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
