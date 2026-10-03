import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../application/picking_providers.dart';
import '../domain/picking_models.dart';
import 'cajon_selector_screen.dart';

typedef _ZonaPendiente = ({int idZona, String nombre, String codigo, int pendientes});

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
///
/// Si `PickingConfig.escaneoZonaObligatorio` está prendido (Ajustes ->
/// Operaciones -> Picking -> "Obligatorio escanear zona"), la lista de
/// zonas pendientes deja de ser tocable: hay que escanear (o tipear) el
/// código de la zona para elegirla — ver `_ZonaSelectorScreenState.build`.
class ZonaSelectorScreen extends ConsumerStatefulWidget {
  const ZonaSelectorScreen({super.key, required this.idPedidoSubpedido});

  final int idPedidoSubpedido;

  @override
  ConsumerState<ZonaSelectorScreen> createState() => _ZonaSelectorScreenState();
}

class _ZonaSelectorScreenState extends ConsumerState<ZonaSelectorScreen> {
  bool _iniciando = false;
  String? _error;
  final _codigoController = TextEditingController();

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

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
        final config = await repo.config(idPedidoSubpedido: widget.idPedidoSubpedido);
        if (!mounted) return;

        // Si este almacén no pickea con contenedor (Ajustes -> Operaciones ->
        // Picking -> "Pickea con contenedor"), ni se le pregunta al operario:
        // la sesión sigue sin cajón activo (el estado "sin cajón" de
        // siempre) y se pasa directo a la pantalla de trabajo.
        if (config.usaContenedor) {
          final resultado = await Navigator.of(context).push<Object>(
            MaterialPageRoute(
              builder: (_) => CajonSelectorScreen(
                idPedidoSubpedido: widget.idPedidoSubpedido,
                cajonObligatorio: config.cajonObligatorio,
              ),
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

  /// Resuelve un código escaneado/tipeado contra las zonas PENDIENTES de
  /// este subpedido (no contra todas las zonas del almacén — un código de
  /// una zona sin tareas acá no tiene que arrancar nada) y, si matchea,
  /// arranca `_iniciar`. Comparación case-insensitive/trim porque el
  /// escáner puede devolver el código con mayúsculas distintas al impreso.
  void _confirmarCodigo(String codigoCrudo, List<_ZonaPendiente> zonas) {
    final codigo = codigoCrudo.trim();
    if (codigo.isEmpty) return;
    final normalizado = codigo.toLowerCase();
    final match = zonas.where((z) => z.codigo.trim().toLowerCase() == normalizado);
    if (match.isEmpty) {
      setState(() => _error = 'Ese código no corresponde a ninguna zona pendiente de este subpedido.');
      return;
    }
    setState(() => _error = null);
    _iniciar(match.first.idZona);
  }

  Future<void> _escanear(List<_ZonaPendiente> zonas) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;
    _confirmarCodigo(codigo, zonas);
  }

  void _buscarPorTexto(List<_ZonaPendiente> zonas) {
    _confirmarCodigo(_codigoController.text, zonas);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(misTareasProvider);
    // Fallback `false` mientras la config todavía no llegó (o si el
    // almacén no tiene fila propia) — mismo criterio que el resto de la
    // app (ver `config?.cajonObligatorio ?? false` en picking_trabajo_screen.dart).
    final requiereEscaneo =
        ref.watch(pickingConfigProvider(widget.idPedidoSubpedido)).value?.escaneoZonaObligatorio ?? false;

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
                Text(
                  requiereEscaneo
                      ? 'Escaneá o buscá el código de la zona en la que vas a pickear. Se inicia el cronómetro al confirmar.'
                      : 'Elegí la zona en la que vas a pickear. Se inicia el cronómetro al confirmar.',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
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
                if (requiereEscaneo) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Escaneá o buscá el código de zona',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Este almacén exige escanear la zona antes de empezar a pickear.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.sub),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codigoController,
                                textInputAction: TextInputAction.search,
                                enabled: !_iniciando,
                                onSubmitted: (_) => _buscarPorTexto(zonas),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  hintText: 'Código de la zona',
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                                    tooltip: 'Escanear',
                                    onPressed: _iniciando ? null : () => _escanear(zonas),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _iniciando ? null : () => _buscarPorTexto(zonas),
                              child: const Text('Buscar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'ZONAS PENDIENTES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
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
                        final tile = Padding(
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
                        );

                        // Con escaneo obligatorio, la lista es solo de
                        // referencia (qué zonas quedan y cuántas tareas
                        // tienen) — no se puede tocar para elegir, hay que
                        // escanear/tipear el código arriba.
                        return Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: requiereEscaneo
                              ? tile
                              : InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _iniciando ? null : () => _iniciar(z.idZona),
                                  child: tile,
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
