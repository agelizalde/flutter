import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../auth/application/auth_controller.dart';

/// Pantalla de inicio del módulo: solo accesos, sin listar ajustes
/// previos (a pedido del usuario — el historial completo vive en su
/// propia pantalla). "Nuevo ajuste" cubre los 8 motivos con conteo por
/// ubicación; "Merma" es un atajo de un solo paso (producto + cantidad +
/// causa, sin elegir ubicación ni pasar por BORRADOR/CONFIRMADO) que
/// aplica directo — ver `MermaRapidaScreen`.
class AjusteStockHomeScreen extends ConsumerWidget {
  const AjusteStockHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final puedeCrear = usuario?.tienePermiso('ajuste_stock.crear') ?? false;
    final puedeAsignar = usuario?.tienePermiso('ajuste_stock.asignar') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajuste de stock')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NuevoAjusteCta(
              habilitado: puedeCrear,
              onTap: () => context.push('/ajuste-stock/nuevo'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _AccionTile(
                    icono: Icons.history,
                    color: AppColors.accent,
                    etiqueta: 'Historial',
                    onTap: () => context.push('/ajuste-stock/historial'),
                  ),
                ),
                if (puedeCrear) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AccionTile(
                      icono: Icons.recycling_outlined,
                      color: AppColors.waTx,
                      etiqueta: 'Merma',
                      onTap: () => context.push('/ajuste-stock/merma-rapida'),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: _AccionTile(
                    icono: Icons.fact_check_outlined,
                    color: AppColors.accentDark,
                    etiqueta: 'Mis solicitudes',
                    onTap: () => context.push('/ajuste-stock/mis-solicitudes'),
                  ),
                ),
              ],
            ),
            if (puedeAsignar) ...[
              const SizedBox(height: 10),
              _AccionTile(
                icono: Icons.person_add_alt_1_outlined,
                color: AppColors.accent,
                etiqueta: 'Solicitar control a otro usuario',
                onTap: () => context.push('/ajuste-stock/solicitar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NuevoAjusteCta extends StatelessWidget {
  const _NuevoAjusteCta({required this.habilitado, required this.onTap});

  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: habilitado ? AppColors.accent : AppColors.soft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: habilitado
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No tenés permiso para crear ajustes de stock')),
                ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: habilitado ? Colors.white.withValues(alpha: 0.18) : AppColors.borderStrong.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.add,
                  color: habilitado ? Colors.white : AppColors.muted,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nuevo ajuste',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: habilitado ? Colors.white : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Contar stock real y registrar diferencias',
                      style: TextStyle(fontSize: 13, color: habilitado ? Colors.white70 : AppColors.faint),
                    ),
                  ],
                ),
              ),
              if (habilitado) const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccionTile extends StatelessWidget {
  const _AccionTile({required this.icono, required this.color, required this.etiqueta, required this.onTap});

  final IconData icono;
  final Color color;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(icono, color: color, size: 24),
                const SizedBox(height: 8),
                Text(
                  etiqueta,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
