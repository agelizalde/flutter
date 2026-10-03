import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/settings_group.dart';
import '../../actualizacion/application/actualizacion_providers.dart';
import '../../actualizacion/presentation/actualizacion_dialog.dart';

/// Se llega desde el botón "Configuración" del tab Perfil. Agrupa acciones
/// de cuenta/app que antes vivían sueltas como tiles del propio Perfil —
/// separarlas acá deja Perfil enfocado en identidad, no en acciones.
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    final versionTexto = info != null ? 'Versión ${info.version} (build ${info.buildNumber})' : null;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: const Text('Configuración')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            const SettingsSectionTitle('CUENTA'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icono: Icons.lock_outline,
                  titulo: 'Actualizar contraseña',
                  onTap: () => context.push('/cambiar-password'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SettingsSectionTitle('APLICACIÓN'),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                SettingsTile(
                  icono: Icons.system_update_alt_outlined,
                  titulo: 'Buscar actualizaciones',
                  subtitulo: versionTexto,
                  onTap: () => _buscarActualizaciones(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Fuerza un recheck manual (el automático solo corre una vez por sesión,
  /// desde `WherehouseShell`) — útil para probar sin reabrir la app, o para
  /// que el usuario confirme que ya está al día.
  Future<void> _buscarActualizaciones(BuildContext context, WidgetRef ref) async {
    ref.invalidate(actualizacionDisponibleProvider);
    final version = await ref.read(actualizacionDisponibleProvider.future);
    if (!context.mounted) return;

    if (version != null) {
      await mostrarDialogoActualizacion(context, version);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ya tenés la última versión instalada')),
      );
    }
  }
}
