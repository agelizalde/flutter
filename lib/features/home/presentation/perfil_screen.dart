import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/auth/usuario_actual.dart';
import '../../../core/widgets/settings_group.dart';
import '../../auth/application/auth_controller.dart';
import '../../firmas/application/firmas_providers.dart';
import '../../recepcion/application/recepcion_providers.dart';
import 'tarjeta_virtual_usuario.dart';

/// Tab "Perfil" del bottom nav — mismo lenguaje visual que el Home (hero
/// con gradiente + cards con sombra suave, ver `home_screen.dart`). Muestra
/// los datos que ya trae `/auth/me` (nada nuevo al backend): identidad y
/// almacén asignado. Los roles no se muestran (no le aportan nada al
/// usuario final) y las acciones de cuenta/app viven en `/configuracion`,
/// no acá — este tab queda enfocado solo en identidad.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final almacenes = ref.watch(almacenesProvider).value ?? const [];
    final tieneFirmasVer = usuario?.tienePermiso('firmas.ver') ?? false;
    final firmasPendientesCount = tieneFirmasVer
        ? (ref.watch(firmasPendientesProvider).value?.where((s) => s.puedeFirmarYo).length ?? 0)
        : 0;
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
            child: _PerfilHero(usuario: usuario, almacenNombre: almacenNombre),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(child: const SettingsSectionTitle('MI CUENTA')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverToBoxAdapter(
              child: SettingsGroup(
                children: [
                  _FilaDato(icono: Icons.mail_outline, etiqueta: 'Email', valor: usuario?.email ?? '—'),
                  if (usuario?.username != null && usuario!.username != usuario.email)
                    _FilaDato(icono: Icons.badge_outlined, etiqueta: 'Usuario', valor: usuario.username!),
                  _FilaDato(
                    icono: Icons.store_outlined,
                    etiqueta: 'Almacén asignado',
                    valor: almacenNombre ?? 'Sin asignar',
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: SettingsGroup(
                children: [
                  if (tieneFirmasVer)
                    SettingsTile(
                      icono: Icons.draw_outlined,
                      titulo: 'Firmas pendientes',
                      onTap: () => context.push('/firmas'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (firmasPendientesCount > 0) ...[
                            _ContadorBadge(cantidad: firmasPendientesCount),
                            const SizedBox(width: 8),
                          ],
                          const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
                        ],
                      ),
                    ),
                  SettingsTile(
                    icono: Icons.settings_outlined,
                    titulo: 'Configuración',
                    onTap: () => context.push('/configuracion'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            sliver: SliverToBoxAdapter(
              child: _CerrarSesionButton(onTap: () => ref.read(authControllerProvider.notifier).logout()),
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
  const _PerfilHero({required this.usuario, required this.almacenNombre});

  final UsuarioActual? usuario;
  final String? almacenNombre;

  @override
  Widget build(BuildContext context) {
    final nombre = usuario?.nombreMostrar;
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
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: usuario == null ? null : () => mostrarTarjetaVirtual(context, usuario!),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _iniciales(nombre),
                        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    if (usuario != null)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.heroEnd, width: 2),
                          ),
                          child: const Icon(Icons.qr_code_2, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              nombre ?? 'Usuario',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
              textAlign: TextAlign.center,
            ),
            if (almacenNombre != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.store_outlined, size: 13, color: Color(0xFFCBD5E1)),
                    const SizedBox(width: 6),
                    Text(almacenNombre!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFE2E8F0))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Círculo rojo con la cantidad de firmas pendientes que le tocan al usuario
/// (`puedeFirmarYo`, ver `firmasPendientesProvider`) — 99+ para no romper el
/// layout si se acumulan muchas.
class _ContadorBadge extends StatelessWidget {
  const _ContadorBadge({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: const BoxDecoration(color: AppColors.prioridadUrgente, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        cantidad > 99 ? '99+' : '$cantidad',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icono, size: 16, color: AppColors.muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
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
      ),
    );
  }
}

class _CerrarSesionButton extends StatelessWidget {
  const _CerrarSesionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.erBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.erTx),
              SizedBox(width: 8),
              Text('Cerrar sesión', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.erTx)),
            ],
          ),
        ),
      ),
    );
  }
}
