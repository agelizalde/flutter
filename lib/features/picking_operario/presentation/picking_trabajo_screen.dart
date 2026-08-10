import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/picking_providers.dart';
import '../domain/picking_models.dart';
import 'cajon_selector_screen.dart';
import 'widgets/tarea_picking_tile.dart';

String _fmtDuracion(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Pantalla de trabajo: cronómetro (solo visual, el servidor decide el
/// cierre), cajón activo y las tareas pendientes/completadas de la zona en
/// curso. No recibe la sesión por parámetro — siempre la lee de
/// `misTareasProvider` para no desincronizarse de la fuente de verdad.
class PickingTrabajoScreen extends ConsumerStatefulWidget {
  const PickingTrabajoScreen({super.key});

  @override
  ConsumerState<PickingTrabajoScreen> createState() => _PickingTrabajoScreenState();
}

class _PickingTrabajoScreenState extends ConsumerState<PickingTrabajoScreen> {
  Timer? _tick;
  bool _terminando = false;
  bool _cambiandoCajon = false;
  bool _cerroPorSesionPerdida = false;

  /// Última sesión activa vista — se sigue necesitando después de que
  /// `sesionActiva` pasa a `null` (para saber en qué zona/subpedido estaba
  /// trabajando y decidir si mostrar el cartel de "picking completo" o el
  /// aviso de sesión cerrada por inactividad).
  SesionZona? _ultimaSesion;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _terminar(int idSesion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar picking'),
        content: const Text('¿Confirmás que terminaste de trabajar esta zona?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Terminar')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _terminando = true);
    try {
      await ref.read(pickingRepositoryProvider).terminarSesion(idSesion);
      ref.invalidate(misTareasProvider);
      if (!mounted) return;
      context.go('/picking-operario');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _terminando = false);
    }
  }

  Future<void> _cambiarCajon(int idSesion, int idPedidoSubpedido) async {
    final resultado = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => CajonSelectorScreen(idPedidoSubpedido: idPedidoSubpedido),
      ),
    );
    if (!mounted) return;

    int? idContenedor;
    if (resultado is ContenedorPicking) {
      idContenedor = resultado.idContenedor;
    } else if (resultado is SinCajonSeleccionado) {
      idContenedor = null;
    } else {
      return; // cancelado (null) — sin cambios
    }

    setState(() => _cambiandoCajon = true);
    try {
      await ref.read(pickingRepositoryProvider).seleccionarCajon(idSesion: idSesion, idContenedor: idContenedor);
      ref.invalidate(misTareasProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cambiandoCajon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(misTareasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Picking')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
        data: (data) {
          final sesion = data.sesionActiva;
          if (sesion != null) _ultimaSesion = sesion;

          if (sesion == null) {
            final ultima = _ultimaSesion;
            List<TareaPicking> tareasDeLaUltimaZona = const [];
            if (ultima != null) {
              for (final sp in data.subpedidos) {
                if (sp.idPedidoSubpedido == ultima.idPedidoSubpedido) {
                  tareasDeLaUltimaZona = sp.tareas.where((t) => t.idZona == ultima.idZona).toList();
                  break;
                }
              }
            }
            final zonaCompleta = tareasDeLaUltimaZona.isNotEmpty &&
                tareasDeLaUltimaZona.every((t) => t.completada);

            if (zonaCompleta) {
              return _PickingCompletoCartel(ubicacionArmado: ultima);
            }

            if (!_cerroPorSesionPerdida) {
              _cerroPorSesionPerdida = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sesión finalizada'),
                    content: const Text(
                      'Tu sesión de picking se cerró por inactividad. Volvé a elegir una zona para seguir.',
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                    ],
                  ),
                );
                if (!context.mounted) return;
                context.go('/picking-operario');
              });
            }
            return const Center(child: CircularProgressIndicator());
          }

          final subpedido = data.subpedidos.firstWhere(
            (sp) => sp.idPedidoSubpedido == sesion.idPedidoSubpedido,
            orElse: () => SubpedidoPicking(idPedidoSubpedido: sesion.idPedidoSubpedido, total: 0, completadas: 0, tareas: []),
          );
          final tareasZona = subpedido.tareas.where((t) => t.idZona == sesion.idZona).toList();
          final pendientes = tareasZona.where((t) => t.pendiente).toList();
          final completadas = tareasZona.where((t) => t.completada).toList();
          final elapsed = DateTime.now().difference(sesion.iniciadoEn);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subpedido.codigoPedido ?? 'Subpedido #${subpedido.idPedidoSubpedido}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tareasZona.isNotEmpty ? tareasZona.first.zonaNombre : '',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: tareasZona.isEmpty ? 0 : completadas.length / tareasZona.length,
                        minHeight: 6,
                        backgroundColor: AppColors.soft,
                        color: pendientes.isEmpty ? const Color(0xFF22C55E) : AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 18, color: AppColors.sub),
                        const SizedBox(width: 6),
                        Text(
                          _fmtDuracion(elapsed),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.sub),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _terminando ? null : () => _terminar(sesion.idSesion),
                          child: Text(_terminando ? 'Terminando...' : 'Terminar picking'),
                        ),
                      ],
                    ),
                    if (pendientes.isEmpty && tareasZona.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: AppColors.okBg, borderRadius: BorderRadius.circular(10)),
                        child: const Text(
                          '✅ Zona completa',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.okTx, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: sesion.idContenedorActivo != null ? AppColors.okBg : AppColors.soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inbox_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sesion.idContenedorActivo != null
                            ? 'Cajón activo: ${sesion.contenedorIdentificador ?? sesion.idContenedorActivo}'
                            : 'Picking sin cajón',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text),
                      ),
                    ),
                    TextButton(
                      onPressed: _cambiandoCajon
                          ? null
                          : () => _cambiarCajon(sesion.idSesion, sesion.idPedidoSubpedido),
                      child: Text(sesion.idContenedorActivo != null ? 'Cambiar' : 'Seleccionar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (pendientes.isNotEmpty) ...[
                const Text('PENDIENTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1)),
                const SizedBox(height: 8),
                ...pendientes.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TareaPickingTile(tarea: t, idSesion: sesion.idSesion),
                    )),
                const SizedBox(height: 16),
              ],
              if (completadas.isNotEmpty) ...[
                const Text('COMPLETADAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1)),
                const SizedBox(height: 8),
                ...completadas.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TareaPickingTile(tarea: t, idSesion: sesion.idSesion),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Cartel de cierre cuando la zona se completó (todas las tareas quedaron
/// `COMPLETADO` y el backend cerró la sesión con `motivo_fin=AUTO_COMPLETADO`)
/// — a diferencia del aviso de inactividad, este es pantalla completa (no un
/// diálogo transitorio) porque es la confirmación de que el trabajo terminó
/// bien y el operario necesita la instrucción de dónde dejar los cajones.
class _PickingCompletoCartel extends StatelessWidget {
  const _PickingCompletoCartel({required this.ubicacionArmado});

  final SesionZona? ubicacionArmado;

  @override
  Widget build(BuildContext context) {
    final ubicacion = ubicacionArmado?.ubicacionArmadoCodigo ?? ubicacionArmado?.ubicacionArmadoNombre;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/images/logo.jpg', width: 96, height: 96, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Picking completo!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(height: 12),
            Text(
              ubicacion != null
                  ? 'Depositá los cajones en la ubicación de armado "$ubicacion".'
                  : 'Depositá los cajones en la ubicación de armado del pedido.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.sub, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/picking-operario'),
              child: const Text('Volver a mis tareas'),
            ),
          ],
        ),
      ),
    );
  }
}
