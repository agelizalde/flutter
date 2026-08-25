import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../features/escaner/application/escaner_providers.dart';
import '../../features/escaner/presentation/resolver_navegacion.dart';
import '../../features/notificaciones/application/notificaciones_providers.dart';
import '../errors/app_exception.dart';
import 'barcode_scanner_screen.dart';

/// Shell de navegación global: 4 tabs con estado propio (Inicio/Pedidos/
/// Notificaciones/Perfil, uno por cada `StatefulShellBranch` del router)
/// más el botón "Escanear" en el medio — no es un tab, es la acción
/// central de toda la app (spec: "el escaneo es el centro de toda la
/// aplicación"), así que abre la cámara directo en vez de navegar a una
/// pantalla con estado.
class WherehouseShell extends ConsumerWidget {
  const WherehouseShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noLeidas =
        ref
            .watch(misNotificacionesProvider)
            .value
            ?.where((n) => !n.leida)
            .length ??
        0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onTabSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        onEscanear: () => _escanear(context, ref),
        notificacionesBadge: noLeidas > 0,
      ),
    );
  }

  Future<void> _escanear(BuildContext context, WidgetRef ref) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resultado = await ref
          .read(escanerRepositoryProvider)
          .resolver(codigo);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await resolverYNavegar(
        context,
        ref,
        resultado,
        codigoNoEncontrado: codigo,
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}

/// 5 columnas iguales — Inicio / Pedidos / Escanear / Notificaciones /
/// Perfil — cada una en su propio `Expanded`, así el botón de Escanear
/// (elevado) tiene su propio espacio y no queda tapando al ícono de al
/// lado (bug anterior: se centraba sobre toda la barra, no sobre su
/// columna).
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onTabSelected,
    required this.onEscanear,
    required this.notificacionesBadge,
  });

  /// Índice de branch del router: 0=Inicio, 1=Pedidos, 2=Notificaciones,
  /// 3=Perfil (Escanear no es un branch).
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onEscanear;
  final bool notificacionesBadge;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 14,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icono: Icons.home_outlined,
                      iconoActivo: Icons.home,
                      label: 'Inicio',
                      selected: currentIndex == 0,
                      onTap: () => onTabSelected(0),
                    ),
                    _NavItem(
                      icono: Icons.receipt_long_outlined,
                      iconoActivo: Icons.receipt_long,
                      label: 'Pedidos',
                      selected: currentIndex == 1,
                      onTap: () => onTabSelected(1),
                    ),
                    Expanded(
                      child: Center(
                        child: Transform.translate(
                          offset: const Offset(0, -14),
                          child: _EscanearButton(onTap: onEscanear),
                        ),
                      ),
                    ),
                    _NavItem(
                      icono: Icons.notifications_outlined,
                      iconoActivo: Icons.notifications,
                      label: 'Notificaciones',
                      selected: currentIndex == 2,
                      showDot: notificacionesBadge,
                      onTap: () => onTabSelected(2),
                    ),
                    _NavItem(
                      icono: Icons.person_outline,
                      iconoActivo: Icons.person,
                      label: 'Perfil',
                      selected: currentIndex == 3,
                      onTap: () => onTabSelected(3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón central elevado — acción principal de toda la app, pensado para
/// tocarse con guantes/una mano (64dp, bien por encima del resto de la
/// barra).
class _EscanearButton extends StatelessWidget {
  const _EscanearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402563EB),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const Icon(
            Icons.qr_code_scanner,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icono;
  final IconData iconoActivo;
  final String label;
  final bool selected;
  final bool showDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(selected ? iconoActivo : icono, color: color, size: 24),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.prioridadUrgente,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
