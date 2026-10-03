import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/auth/usuario_actual.dart' show UsuarioActual;
import '../application/config_apariencia_providers.dart';

/// Prefijo del contenido del QR — no hay todavía nada en el sistema que
/// escanee credenciales de usuario (ver CONTEXTO_WHEREHOUSE.md), así que
/// este formato es nuevo. Un `id_usuario` plano identifica sin ambigüedad
/// y es estable de por vida (a diferencia de `email`/`username`, editables).
const _prefijoQrUsuario = 'WHUSR';

/// Se abre tocando el avatar/iniciales del hero de `PerfilScreen` — una
/// credencial digital con el logo/nombre de empresa configurados en la web
/// (Ajustes > Generales > Sistema > Apariencia) más un QR que identifica al
/// usuario, pensada para mostrar en pantalla (portería, control de acceso,
/// etc.) sin depender de una tarjeta física.
Future<void> mostrarTarjetaVirtual(BuildContext context, UsuarioActual usuario) {
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'Tarjeta virtual',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) => _TarjetaVirtualDialog(usuario: usuario),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _TarjetaVirtualDialog extends StatelessWidget {
  const _TarjetaVirtualDialog({required this.usuario});

  final UsuarioActual usuario;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          _TarjetaVirtualCard(usuario: usuario),
          Positioned(
            top: -14,
            right: -14,
            child: _BotonCerrar(onTap: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }
}

class _BotonCerrar extends StatelessWidget {
  const _BotonCerrar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.close, size: 18, color: AppColors.text),
        ),
      ),
    );
  }
}

class _TarjetaVirtualCard extends ConsumerWidget {
  const _TarjetaVirtualCard({required this.usuario});

  final UsuarioActual usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configAparienciaProvider).value;

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 28, offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                child: _Logo(logoUrl: config?.logoUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config?.nombreSistema ?? 'ERP',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const Text(
                      'Credencial digital',
                      style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: Color(0x33FFFFFF)),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              _iniciales(usuario.nombreMostrar),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            usuario.nombreMostrar,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.2),
          ),
          const SizedBox(height: 3),
          Text(
            'N° de usuario ${usuario.idUsuario}',
            style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: bw.BarcodeWidget(
              barcode: bw.Barcode.qrCode(),
              data: '$_prefijoQrUsuario-${usuario.idUsuario}',
              width: 168,
              height: 168,
              drawText: false,
              color: AppColors.ink,
              errorBuilder: (context, error) => const SizedBox(
                width: 168,
                height: 168,
                child: Center(child: Icon(Icons.qr_code_2, size: 48, color: AppColors.faint)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Identificación interna — no válido como documento oficial',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    const fallback = Image(image: AssetImage('assets/images/logo.jpg'), fit: BoxFit.contain);
    if (logoUrl == null || logoUrl!.isEmpty) return fallback;

    return Image.network(
      Env.resolveStorageUrl(logoUrl!),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

/// Mismo criterio que `_iniciales` de `PerfilHero` — primera letra de las
/// dos primeras palabras del nombre.
String _iniciales(String nombre) {
  if (nombre.trim().isEmpty) return '?';
  final partes = nombre.trim().split(RegExp(r'\s+'));
  final primera = partes.first[0];
  final segunda = partes.length > 1 && partes[1].isNotEmpty ? partes[1][0] : '';
  return (primera + segunda).toUpperCase();
}
