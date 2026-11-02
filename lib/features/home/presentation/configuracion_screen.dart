import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/config/modo_grafico.dart';
import '../../../core/widgets/settings_group.dart';
import '../../actualizacion/application/actualizacion_providers.dart';
import '../../actualizacion/presentation/actualizacion_dialog.dart';

/// Modo gráfico guardado en el teléfono (solo Android) — ver
/// `ModoGraficoStore` y `MainActivity.kt`.
final modoGraficoProvider = FutureProvider<EstadoModoGrafico?>((ref) => ModoGraficoStore.estado());

/// Se llega desde el botón "Configuración" del tab Perfil. Agrupa acciones
/// de cuenta/app que antes vivían sueltas como tiles del propio Perfil —
/// separarlas acá deja Perfil enfocado en identidad, no en acciones.
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider).value;
    final versionTexto = info != null ? 'Versión ${info.version} (build ${info.buildNumber})' : null;
    final modoGrafico = ref.watch(modoGraficoProvider).value;

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
                SettingsTile(
                  icono: Icons.notifications_active_outlined,
                  titulo: 'Notificaciones push',
                  subtitulo: 'Qué módulos te avisan al teléfono',
                  onTap: () => context.push('/configuracion/notificaciones-push'),
                ),
                SettingsTile(
                  icono: Icons.dns_outlined,
                  titulo: 'Servidor y conexión',
                  subtitulo: Env.fijoEnErp ? 'Fijo en red de la empresa' : 'Automático (erp. / public.)',
                  onTap: () => context.push('/configurar-servidor'),
                ),
                if (modoGrafico != null)
                  SettingsTile(
                    icono: Icons.memory_outlined,
                    titulo: 'Modo gráfico',
                    subtitulo: _subtituloModoGrafico(modoGrafico),
                    onTap: () => _elegirModoGrafico(context, ref, modoGrafico),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtituloModoGrafico(EstadoModoGrafico e) {
    final enUso = e.compatibilidadActiva ? 'compatibilidad' : 'moderno';
    return e.modo == ModoGrafico.auto ? 'Automático (usando $enUso)' : e.modo.etiqueta;
  }

  /// Para terminales con Android viejo que se ven en negro o se cierran:
  /// elegir "Compatibilidad" y la app se reinicia con el motor anterior. Se
  /// guarda en el teléfono, así que sobrevive a las actualizaciones.
  Future<void> _elegirModoGrafico(BuildContext context, WidgetRef ref, EstadoModoGrafico actual) async {
    final elegido = await showModalBottomSheet<ModoGrafico>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Modo gráfico', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                'Si la app se ve en negro o se cierra en este equipo, usá "Compatibilidad".',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (final modo in ModoGrafico.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    modo == actual.modo ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: modo == actual.modo ? AppColors.accent : AppColors.faint,
                  ),
                  title: Text(modo.etiqueta, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(switch (modo) {
                    ModoGrafico.auto =>
                      'Elige solo según el equipo (en este: ${actual.compatibilidadAuto ? 'compatibilidad' : 'moderno'}).',
                    ModoGrafico.compat => 'Motor anterior. Para Android viejos.',
                    ModoGrafico.moderno => 'Motor nuevo, más fluido en equipos actuales.',
                  }),
                  onTap: () => Navigator.of(context).pop(modo),
                ),
            ],
          ),
        ),
      ),
    );
    if (elegido == null || elegido == actual.modo || !context.mounted) return;

    await ModoGraficoStore.guardar(elegido);
    ref.invalidate(modoGraficoProvider);
    if (!context.mounted) return;

    final reiniciar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reiniciar la app'),
        content: const Text('El modo gráfico se aplica al volver a abrir la app. ¿Reiniciar ahora?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Después')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reiniciar')),
        ],
      ),
    );
    if (reiniciar == true) await ModoGraficoStore.reiniciar();
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
