import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Tarjeta que agrupa filas relacionadas con un solo contorno + divisores
/// internos (estilo "ajustes" moderno) en vez de tiles sueltos separados
/// por espacio — usada por Perfil y Configuración para que ambas pantallas
/// compartan el mismo lenguaje visual.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: AppColors.border, indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
      ),
    );
  }
}

/// Fila navegable/accionable dentro de un [SettingsGroup]: icono con fondo
/// suave, título (+ subtítulo opcional) y chevron o [trailing] a la derecha.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.onTap,
    this.destructivo = false,
    this.trailing,
  });

  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final VoidCallback? onTap;
  final bool destructivo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = destructivo ? AppColors.erTx : AppColors.text;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: destructivo ? AppColors.erBg : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icono, size: 17, color: destructivo ? AppColors.erTx : AppColors.accentDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: color),
                    ),
                    if (subtitulo != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitulo!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
