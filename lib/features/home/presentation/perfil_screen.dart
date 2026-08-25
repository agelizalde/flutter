import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../recepcion/application/recepcion_providers.dart';

/// Tab "Perfil" del bottom nav — mismo lenguaje visual que el Home (hero
/// con gradiente + cards con sombra suave, ver `home_screen.dart`). Muestra
/// los datos que ya trae `/auth/me` (nada nuevo al backend): identidad,
/// almacén asignado y roles. Sigue siendo dueña de cerrar sesión (antes
/// vivía en el menú de `WherehouseAppBar`, que se sacó al rediseñar Home).
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final almacenes = ref.watch(almacenesProvider).value ?? const [];
    String? almacenNombre;
    if (usuario != null) {
      for (final a in almacenes) {
        if (a.idAlmacen == usuario.idAlmacenSeleccionado) {
          almacenNombre = a.nombre;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _PerfilHero(nombre: usuario?.nombreMostrar, almacenNombre: almacenNombre),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(child: _SeccionTitulo('MI CUENTA')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: _Card(
                child: Column(
                  children: [
                    _FilaDato(icono: Icons.mail_outline, etiqueta: 'Email', valor: usuario?.email ?? '—'),
                    if (usuario?.username != null && usuario!.username != usuario.email) ...[
                      const Divider(height: 20, color: AppColors.border),
                      _FilaDato(icono: Icons.badge_outlined, etiqueta: 'Usuario', valor: usuario.username!),
                    ],
                    const Divider(height: 20, color: AppColors.border),
                    _FilaDato(
                      icono: Icons.store_outlined,
                      etiqueta: 'Almacén asignado',
                      valor: almacenNombre ?? 'Sin asignar',
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (usuario != null && usuario.roles.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(child: _SeccionTitulo('ROLES')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _Card(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final rol in usuario.roles)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            rol,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  if (usuario?.tienePermiso('firmas.ver') ?? false) ...[
                    _MenuTile(
                      icono: Icons.draw_outlined,
                      titulo: 'Firmas pendientes',
                      onTap: () => context.push('/firmas'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _MenuTile(
                    icono: Icons.lock_outline,
                    titulo: 'Actualizar contraseña',
                    onTap: () => context.push('/cambiar-password'),
                  ),
                  const SizedBox(height: 10),
                  _MenuTile(
                    icono: Icons.logout,
                    titulo: 'Cerrar sesión',
                    destructivo: true,
                    onTap: () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mismas iniciales que un avatar típico: primera letra de las dos primeras
/// palabras del nombre — evita depender de una foto de perfil que esta app
/// no maneja.
String _iniciales(String? nombre) {
  if (nombre == null || nombre.trim().isEmpty) return '?';
  final partes = nombre.trim().split(RegExp(r'\s+'));
  final primera = partes.first[0];
  final segunda = partes.length > 1 && partes[1].isNotEmpty ? partes[1][0] : '';
  return (primera + segunda).toUpperCase();
}

class _PerfilHero extends StatelessWidget {
  const _PerfilHero({required this.nombre, required this.almacenNombre});

  final String? nombre;
  final String? almacenNombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                _iniciales(nombre),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              nombre ?? 'Usuario',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
              textAlign: TextAlign.center,
            ),
            if (almacenNombre != null) ...[
              const SizedBox(height: 4),
              Text(almacenNombre!, style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1))),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.icono, required this.etiqueta, required this.valor});

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(10)),
          child: Icon(icono, size: 17, color: AppColors.muted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 1),
              Text(
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.destructivo = false,
  });

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;
  final bool destructivo;

  @override
  Widget build(BuildContext context) {
    final color = destructivo ? AppColors.erTx : AppColors.text;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icono, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(titulo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              ),
              Icon(Icons.chevron_right, color: destructivo ? AppColors.erTx : AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
