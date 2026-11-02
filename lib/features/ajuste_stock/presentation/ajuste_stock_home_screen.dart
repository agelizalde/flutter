import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../auth/application/auth_controller.dart';
import 'ajuste_stock_ayuda.dart';

/// Pantalla de inicio del módulo: solo accesos, sin listar ajustes
/// previos (a pedido del usuario — el historial completo vive en su
/// propia pantalla). "Nuevo ajuste" abre un selector con 3 opciones:
/// Control por ubicación (`NuevoAjusteScreen`), Control por producto
/// (`ControlPorProductoScreen`) y Mermar producto (`MermaRapidaScreen`).
class AjusteStockHomeScreen extends ConsumerWidget {
  const AjusteStockHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final puedeCrear = usuario?.tienePermiso('ajuste_stock.crear') ?? false;
    final puedeAsignar = usuario?.tienePermiso('ajuste_stock.asignar') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajuste de stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '¿Cómo funciona?',
            onPressed: () => abrirAyudaAjusteStock(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NuevoAjusteCta(
              habilitado: puedeCrear,
              onTap: () => _elegirTipoAjuste(context),
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

/// Selector de "Nuevo ajuste": las 3 formas de ajustar stock.
void _elegirTipoAjuste(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      void ir(String ruta) {
        Navigator.of(sheetContext).pop();
        context.push(ruta);
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Qué querés hacer?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 14),
              _OpcionAjuste(
                icono: Icons.location_on_outlined,
                color: AppColors.accent,
                titulo: 'Control por ubicación',
                descripcion: 'Escaneá una ubicación y contá todo lo que hay',
                onTap: () => ir('/ajuste-stock/nuevo'),
              ),
              const SizedBox(height: 10),
              _OpcionAjuste(
                icono: Icons.inventory_2_outlined,
                color: AppColors.accentDark,
                titulo: 'Control por producto',
                descripcion: 'Elegí un producto y contalo en cada ubicación',
                onTap: () => ir('/ajuste-stock/por-producto'),
              ),
              const SizedBox(height: 10),
              _OpcionAjuste(
                icono: Icons.recycling_outlined,
                color: AppColors.waTx,
                titulo: 'Mermar producto',
                descripcion: 'Rotura, consumo interno, vencimiento…',
                onTap: () => ir('/ajuste-stock/merma-rapida'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _OpcionAjuste extends StatelessWidget {
  const _OpcionAjuste({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.descripcion,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(descripcion, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
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
                      'Contar por ubicación, por producto o mermar',
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
