import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// Pantalla completa de bloqueo administrativo (espejo visual de
/// `BlockedScreen.jsx` en la web, ver CONTEXTO_WHEREHOUSE.md). Se muestra
/// cuando `UsuarioActual.bloqueadoErp == true` — el usuario sigue
/// autenticado (puede cerrar sesión) pero no puede usar el resto de la app.
class BlockedUserScreen extends ConsumerWidget {
  const BlockedUserScreen({super.key});

  static const _gradientStart = Color(0xFFF97316);
  static const _gradientEnd = Color(0xFFC2410C);
  static const _iconBg = Color(0xFFFFF7ED);
  static const _iconBorder = Color(0xFFF97316);
  static const _iconColor = Color(0xFFEA580C);
  static const _titleColor = Color(0xFF7C2D12);
  static const _messageBoxBg = Color(0xFFFFF7ED);
  static const _messageBoxBorder = Color(0xFFFED7AA);
  static const _subtleColor = Color(0xFF9A3412);
  static const _buttonBg = Color(0xFF7C2D12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final mensaje = usuario?.bloqueoMensaje ?? 'Tu cuenta fue bloqueada por un administrador.';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientStart, _gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.97),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C2D12).withValues(alpha: 0.35),
                        blurRadius: 60,
                        offset: const Offset(0, 24),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: _iconBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: _iconBorder, width: 3),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 48,
                          color: _iconColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Acceso bloqueado',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _titleColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usuario?.nombreMostrar ?? usuario?.email ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _subtleColor,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 20),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: _messageBoxBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _messageBoxBorder),
                        ),
                        child: Text(
                          mensaje,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _titleColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const Text(
                        'Comunicate con un administrador del sistema para resolver esta situación.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: _subtleColor),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _buttonBg,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                          ),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
