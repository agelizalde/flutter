import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/settings_group.dart';
import '../application/notificaciones_providers.dart';

/// Configuración → Notificaciones push: qué módulos avisan al teléfono con
/// una notificación del sistema aunque la app esté cerrada (ver
/// `PushNotificationsService`). Independiente de si el módulo está
/// INSTANTANEO/PROGRAMADO en `/ajustes/notificaciones` (eso ya se resolvió
/// server-side antes de intentar el push) — acá cada usuario elige, para sí
/// mismo, cuáles quiere como notificación nativa.
class PushPreferenciasScreen extends ConsumerWidget {
  const PushPreferenciasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferencias = ref.watch(pushPreferenciasProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: const Text('Notificaciones push')),
      body: SafeArea(
        child: preferencias.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo cargar la configuración.\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ),
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              const Text(
                'Elegí qué módulos te avisan al teléfono como notificación, '
                'aunque la app esté cerrada.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: Text('No hay módulos configurados todavía', style: TextStyle(color: AppColors.muted))),
                )
              else
                SettingsGroup(
                  children: [
                    for (final item in items)
                      SettingsTile(
                        icono: Icons.notifications_active_outlined,
                        titulo: item.nombre,
                        trailing: Switch(
                          value: item.habilitado,
                          onChanged: (habilitado) => _cambiar(ref, item.codigo, habilitado),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cambiar(WidgetRef ref, String codigo, bool habilitado) async {
    // Invalida después de que el PATCH confirme — la lista es chica, no
    // amerita un update optimista con rollback si falla.
    await ref.read(notificacionesRepositoryProvider).actualizarPushPreferencia(codigo, habilitado);
    ref.invalidate(pushPreferenciasProvider);
  }
}
