import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/picking_providers.dart';
import '../domain/picking_models.dart';
import 'cajon_selector_screen.dart';

/// Elegir en qué zona pickear dentro de un subpedido — arranca el
/// cronómetro server-side (`POST .../zona/iniciar`) y, si la sesión queda
/// sin cajón activo, fuerza a elegir uno antes de pasar a
/// `PickingTrabajoScreen`.
///
/// Recibe solo el `idPedidoSubpedido` (path param) y busca los datos del
/// subpedido en `misTareasProvider` — a propósito, NO recibe el
/// `SubpedidoPicking` completo por `state.extra`: `extra` no sobrevive
/// cuando go_router re-evalúa la ruta actual sin una navegación explícita
/// (ej. cada 15s, cuando `AuthController` refresca la sesión en segundo
/// plano y dispara `_AuthRefreshListenable`), lo que rompía esta pantalla
/// con un `TypeError` si el operario se quedaba parado acá más de ~15s.
class ZonaSelectorScreen extends ConsumerStatefulWidget {
  const ZonaSelectorScreen({super.key, required this.idPedidoSubpedido});

  final int idPedidoSubpedido;

  @override
  ConsumerState<ZonaSelectorScreen> createState() => _ZonaSelectorScreenState();
}

class _ZonaSelectorScreenState extends ConsumerState<ZonaSelectorScreen> {
  bool _iniciando = false;
  String? _error;

  Future<void> _iniciar(int idZona) async {
    setState(() {
      _iniciando = true;
      _error = null;
    });
    try {
      final repo = ref.read(pickingRepositoryProvider);
      await repo.iniciarZona(idPedidoSubpedido: widget.idPedidoSubpedido, idZona: idZona);
      final sesion = await repo.sesionActiva();
      if (!mounted) return;

      if (sesion != null && sesion.idContenedorActivo == null) {
        final resultado = await Navigator.of(context).push<Object>(
          MaterialPageRoute(
            builder: (_) => CajonSelectorScreen(idPedidoSubpedido: widget.idPedidoSubpedido),
          ),
        );
        if (!mounted) return;
        if (resultado == null) {
          // Canceló (ej. flecha atrás) sin elegir cajón ni confirmar
          // explícitamente "Picking sin cajón" — no tiene que arrancar el
          // picking igual. Se cierra la sesión recién iniciada/retomada (que
          // todavía no tiene tareas completadas, porque nunca llegó a la
          // pantalla de trabajo) y se queda en la selección de zona.
          await repo.terminarSesion(sesion.idSesion);
          ref.invalidate(misTareasProvider);
          return;
        }
        // ContenedorPicking (eligió uno) o SinCajonSeleccionado (decisión
        // explícita de pickear sin cajón) — en ambos casos se continúa.
        if (resultado is ContenedorPicking) {
          await repo.seleccionarCajon(idSesion: sesion.idSesion, idContenedor: resultado.idContenedor);
        }
      }

      // Se espera el refetch (no solo `invalidate`) antes de navegar: si
      // `PickingTrabajoScreen` arranca a mirar `misTareasProvider` mientras
      // el fetch todavía está en vuelo, Riverpod le sirve el valor anterior
      // (`sesionActiva == null`, de antes de iniciar esta zona) porque
      // `AsyncValue.when` no distingue "sin sesión" de "todavía no llegó la
      // sesión nueva" — eso disparaba el diálogo de "Sesión finalizada" en
      // el primer build, con cajón o sin él.
      ref.invalidate(misTareasProvider);
      await ref.read(misTareasProvider.future);
      if (!mounted) return;
      context.pushReplacement('/picking-operario/trabajo');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(misTareasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Elegir zona')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
        data: (data) {
          SubpedidoPicking? subpedido;
          for (final sp in data.subpedidos) {
            if (sp.idPedidoSubpedido == widget.idPedidoSubpedido) {
              subpedido = sp;
              break;
            }
          }
          if (subpedido == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Este subpedido ya no está disponible (puede que se haya completado o reasignado).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }

          final zonas = subpedido.zonasPendientes;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subpedido.codigoPedido ?? 'Subpedido #${subpedido.idPedidoSubpedido}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elegí la zona en la que vas a pickear. Se inicia el cronómetro al confirmar.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
                  ),
                  const SizedBox(height: 14),
                ],
                if (zonas.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No hay tareas pendientes en ninguna zona de este subpedido.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: zonas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final z = zonas[i];
                        return Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _iniciando ? null : () => _iniciar(z.idZona),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          z.nombre,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                                        ),
                                        if (z.codigo.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(z.codigo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(999)),
                                    child: Text(
                                      '${z.pendientes} pendiente${z.pendientes != 1 ? 's' : ''}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.waTx),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_iniciando) ...[
                  const SizedBox(height: 14),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
