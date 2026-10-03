import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../application/picking_providers.dart';
import '../domain/picking_models.dart';
import 'cajon_items_screen.dart';
import 'cajon_selector_screen.dart';
import 'widgets/tarea_picking_tile.dart';

String _fmtDuracion(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

typedef _UbicacionPendiente = ({int idUbicacion, String codigo, String nombre, int pendientes});

/// Ubicaciones distintas con al menos una tarea pendiente, en orden de
/// código — lo que se ofrece elegir cuando `ubicacionProductoHabilitada`
/// está prendido (ver doc de `PickingTrabajoScreen`). Mismo criterio que
/// `SubpedidoPicking.zonasPendientes`, un nivel más abajo (ubicación en vez
/// de zona).
List<_UbicacionPendiente> _calcularUbicacionesPendientes(List<TareaPicking> pendientes) {
  final mapa = <int, _UbicacionPendiente>{};
  for (final t in pendientes) {
    final actual = mapa[t.idUbicacion];
    mapa[t.idUbicacion] = (
      idUbicacion: t.idUbicacion,
      codigo: t.ubicacionCodigo,
      nombre: t.ubicacionNombre,
      pendientes: (actual?.pendientes ?? 0) + 1,
    );
  }
  final lista = mapa.values.toList();
  lista.sort((a, b) => a.codigo.compareTo(b.codigo));
  return lista;
}

/// Pantalla de trabajo — rediseño 2026-09:
/// a) Header: "Cliente - Sucursal" + cronómetro arriba, zona en curso abajo.
/// b) Sección simple del cajón activo (si `usaContenedor`) + cambiarlo.
/// c) Lista de tareas pendientes/completadas de la zona.
/// d) Devolver un ítem ya pickeado — vive directo en cada tarea completada
///    (`TareaPickingTile`), no depende de tocar el cajón (ver `puedeDevolver`
///    en el modelo — antes era la única vía y no funcionaba con
///    `usa_contenedor=0`).
/// e) "Terminar picking" al pie de la lista; una vez que la zona queda
///    completa (sin pendientes), el mismo botón pasa a flotar como FAB.
///
/// **Completar la última tarea NO salta solo al cartel de cierre**: el
/// backend cierra la sesión sola en cuanto se completa la última tarea de
/// la zona (`motivo_fin=AUTO_COMPLETADO`, ver `_PickingCompletoCartel` más
/// abajo) — pero acá se sigue mostrando la MISMA pantalla de trabajo (lista
/// con todo en COMPLETADAS + el FAB "Terminar picking" flotando) hasta que
/// el operario lo toca a propósito. Recién ahí se muestra el cartel de
/// cierre. Por eso `build` no corta apenas `sesionActiva` da `null`: sigue
/// tratando la última sesión conocida (`_ultimaSesion`) como "en pantalla"
/// mientras su zona esté completa y todavía no se haya confirmado
/// (`_idSesionConfirmada`) — ver `_pantallaTrabajo`, que arma la misma UI
/// tanto si la sesión sigue realmente activa como si ya se cerró sola.
///
/// Cronómetro solo visual (el servidor decide el cierre real). No recibe la
/// sesión por parámetro — siempre la lee de `misTareasProvider` para no
/// desincronizarse de la fuente de verdad.
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

  /// `idSesion` que el operario ya confirmó tocando "Terminar picking"
  /// DESPUÉS de que el backend la cerró sola por completar la última tarea
  /// — recién ahí se muestra `_PickingCompletoCartel` para esa sesión. Se
  /// compara por id, no hace falta resetearlo a mano: en cuanto arranca una
  /// zona nueva, `_ultimaSesion` pasa a tener OTRO id y la comparación deja
  /// de dar igual sola.
  int? _idSesionConfirmada;

  /// Ubicación elegida dentro de la zona en curso (Ajustes -> Operaciones ->
  /// Picking -> APP - Picking -> "Ubicación de producto") — filtra qué
  /// tareas se muestran. `null` mientras no se eligió ninguna, o cuando esa
  /// config está apagada (no se usa en ese caso). No hace falta resetearlo
  /// a mano al cambiar de zona: `_pantallaTrabajo` solo lo respeta si
  /// TODAVÍA tiene tareas pendientes en la zona actual (ver
  /// `sigueTeniendoPendientes` más abajo) — una zona nueva nunca va a tener
  /// ese id entre sus ubicaciones.
  int? _idUbicacionElegida;
  final _codigoUbicacionController = TextEditingController();
  String? _errorUbicacion;

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
    _codigoUbicacionController.dispose();
    super.dispose();
  }

  void _elegirUbicacion(int idUbicacion) {
    setState(() {
      _idUbicacionElegida = idUbicacion;
      _errorUbicacion = null;
      _codigoUbicacionController.clear();
    });
  }

  /// Resuelve un código escaneado/tipeado contra las ubicaciones PENDIENTES
  /// de la zona en curso — mismo criterio que
  /// `ZonaSelectorScreen._confirmarCodigo` un nivel más arriba.
  void _confirmarCodigoUbicacion(String codigoCrudo, List<_UbicacionPendiente> ubicaciones) {
    final codigo = codigoCrudo.trim();
    if (codigo.isEmpty) return;
    final normalizado = codigo.toLowerCase();
    final match = ubicaciones.where((u) => u.codigo.trim().toLowerCase() == normalizado);
    if (match.isEmpty) {
      setState(() => _errorUbicacion = 'Ese código no corresponde a ninguna ubicación pendiente de esta zona.');
      return;
    }
    _elegirUbicacion(match.first.idUbicacion);
  }

  Future<void> _escanearUbicacion(List<_UbicacionPendiente> ubicaciones) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;
    _confirmarCodigoUbicacion(codigo, ubicaciones);
  }

  /// Sesión REALMENTE activa (`sesionActiva=true`): confirma con diálogo,
  /// llama al backend a terminarla y recién ahí navega afuera.
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

  /// Sesión que el backend YA cerró solo (AUTO_COMPLETADO): acá "Terminar
  /// picking" no tiene nada que terminar en el servidor (la sesión ya no
  /// está ACTIVA, llamar a terminarSesion tiraría 400) — solo confirma que
  /// el operario vio la zona completa, para recién ahí mostrar el cartel de
  /// cierre con la instrucción de dónde dejar los cajones.
  void _confirmarCompleto(int idSesion) {
    setState(() => _idSesionConfirmada = idSesion);
  }

  Future<void> _cambiarCajon(int idSesion, int idPedidoSubpedido, bool cajonObligatorio) async {
    final resultado = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => CajonSelectorScreen(
          idPedidoSubpedido: idPedidoSubpedido,
          cajonObligatorio: cajonObligatorio,
        ),
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

    return async.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Picking')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Picking')),
        body: Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
      ),
      data: (data) {
        final sesionServidor = data.sesionActiva;
        if (sesionServidor != null) _ultimaSesion = sesionServidor;
        final ultima = _ultimaSesion;

        if (sesionServidor != null) {
          return _pantallaTrabajo(context, data: data, sesion: sesionServidor, sesionActiva: true);
        }

        // Sin sesión activa en el servidor — puede ser que se cerró sola al
        // completar la última tarea (AUTO_COMPLETADO) O por inactividad.
        // Se distinguen mirando si la última zona conocida quedó completa.
        List<TareaPicking> tareasUltimaZona = const [];
        if (ultima != null) {
          for (final sp in data.subpedidos) {
            if (sp.idPedidoSubpedido == ultima.idPedidoSubpedido) {
              tareasUltimaZona = sp.tareas.where((t) => t.idZona == ultima.idZona).toList();
              break;
            }
          }
        }
        final ultimaZonaCompleta = tareasUltimaZona.isNotEmpty && tareasUltimaZona.every((t) => t.completada);

        if (ultima != null && ultimaZonaCompleta) {
          if (_idSesionConfirmada == ultima.idSesion) {
            return Scaffold(
              appBar: AppBar(title: const Text('Picking')),
              body: _PickingCompletoCartel(ubicacionArmado: ultima),
            );
          }
          // Todavía no tocó "Terminar picking" — se ve exactamente la misma
          // pantalla de trabajo, con todo en COMPLETADAS y el FAB flotando.
          return _pantallaTrabajo(context, data: data, sesion: ultima, sesionActiva: false);
        }

        // Cerrada por inactividad (o cualquier otro motivo) sin zona
        // completa pendiente de confirmar: aviso + vuelta a elegir zona.
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
        return Scaffold(
          appBar: AppBar(title: const Text('Picking')),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  /// Arma la pantalla de trabajo completa (header, cajón, listas, botón/FAB
  /// de terminar) — se usa tanto con la sesión REALMENTE activa como con la
  /// última sesión conocida ya cerrada sola por completar la zona
  /// (`sesionActiva: false`, ver doc de la clase). En ese segundo caso se
  /// oculta la sección de cajón (no hay sesión viva a la que atarle un
  /// cambio) y "Terminar picking" ya no llama al backend — solo confirma
  /// que el operario vio la zona completa (`_confirmarCompleto`).
  Widget _pantallaTrabajo(
    BuildContext context, {
    required MisTareasResponse data,
    required SesionZona sesion,
    required bool sesionActiva,
  }) {
    final subpedido = data.subpedidos.firstWhere(
      (sp) => sp.idPedidoSubpedido == sesion.idPedidoSubpedido,
      orElse: () => SubpedidoPicking(idPedidoSubpedido: sesion.idPedidoSubpedido, total: 0, completadas: 0, tareas: []),
    );
    final tareasZona = subpedido.tareas.where((t) => t.idZona == sesion.idZona).toList();
    final pendientes = tareasZona.where((t) => t.pendiente).toList();
    final completadas = tareasZona.where((t) => t.completada).toList();
    final zonaCompleta = tareasZona.isNotEmpty && pendientes.isEmpty;
    final elapsed = DateTime.now().difference(sesion.iniciadoEn);
    final config = ref.watch(pickingConfigProvider(sesion.idPedidoSubpedido)).value;
    final usaContenedor = config?.usaContenedor ?? true;

    // "Ubicación de producto": si está prendido, hay que elegir (tocar o
    // escanear) una ubicación de las que todavía tienen pendientes ANTES de
    // ver qué pickear — recién ahí se filtran pendientes/completadas a esa
    // ubicación. Al agotarla, `_idUbicacionElegida` deja de estar entre
    // `ubicacionesPendientes` y vuelve a pedir elegir otra, hasta que no
    // quede ninguna (ahí `zonaCompleta`, más arriba, ya da `true` con las
    // listas SIN filtrar y se cae al flujo normal de cierre).
    final habilitaUbicacion = config?.ubicacionProductoHabilitada ?? false;
    var pendientesVista = pendientes;
    var completadasVista = completadas;
    var ubicacionesPendientes = const <_UbicacionPendiente>[];
    var debeElegirUbicacion = false;
    if (habilitaUbicacion) {
      ubicacionesPendientes = _calcularUbicacionesPendientes(pendientes);
      final idElegida = _idUbicacionElegida;
      final sigueTeniendoPendientes = idElegida != null && ubicacionesPendientes.any((u) => u.idUbicacion == idElegida);
      if (sigueTeniendoPendientes) {
        pendientesVista = pendientes.where((t) => t.idUbicacion == idElegida).toList();
        completadasVista = completadas.where((t) => t.idUbicacion == idElegida).toList();
      } else if (ubicacionesPendientes.isNotEmpty) {
        debeElegirUbicacion = true;
      }
    }
    final ubicacionActual = habilitaUbicacion && !debeElegirUbicacion && pendientesVista.isNotEmpty
        ? pendientesVista.first.ubicacionNombre
        : null;

    void onTerminarPresionado() {
      if (sesionActiva) {
        _terminar(sesion.idSesion);
      } else {
        _confirmarCompleto(sesion.idSesion);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Picking')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, zonaCompleta ? 96 : 20),
        children: [
          // ===== a) Header: Cliente - Sucursal + tiempo, zona abajo =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        subpedido.clienteSucursalDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: AppColors.sub),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDuracion(elapsed),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.sub),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.pin_drop_outlined, size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        tareasZona.isNotEmpty ? tareasZona.first.zonaNombre : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (ubicacionActual != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Ubicación: $ubicacionActual',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: tareasZona.isEmpty ? 0 : completadas.length / tareasZona.length,
                    minHeight: 6,
                    backgroundColor: AppColors.soft,
                    color: zonaCompleta ? const Color(0xFF22C55E) : AppColors.accent,
                  ),
                ),
              ],
            ),
          ),

          // ===== b) Sección simple del cajón — solo con sesión viva =====
          if (usaContenedor && sesionActiva) ...[
            const SizedBox(height: 14),
            Material(
              color: sesion.idContenedorActivo != null ? AppColors.okBg : AppColors.soft,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: sesion.idContenedorActivo == null
                    ? null
                    : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => CajonItemsScreen(
                              idContenedor: sesion.idContenedorActivo!,
                              permiteDevolverItem: config?.permiteDevolverItem ?? true,
                            ),
                          ),
                        ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            : () => _cambiarCajon(
                                  sesion.idSesion,
                                  sesion.idPedidoSubpedido,
                                  config?.cajonObligatorio ?? false,
                                ),
                        child: Text(sesion.idContenedorActivo != null ? 'Cambiar' : 'Seleccionar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ===== c) Elegir ubicación (si aplica) o lista de tareas =====
          const SizedBox(height: 20),
          if (debeElegirUbicacion) ...[
            const Text('ELEGÍ UNA UBICACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(
              (config?.escaneoUbicacionObligatorio ?? false)
                  ? 'Escaneá o buscá el código de la ubicación en la que vas a pickear.'
                  : 'Elegí la ubicación en la que vas a pickear.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            if (_errorUbicacion != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
                child: Text(_errorUbicacion!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
              ),
              const SizedBox(height: 12),
            ],
            if (config?.escaneoUbicacionObligatorio ?? false) ...[
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
                      'Escaneá o buscá el código de ubicación',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codigoUbicacionController,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _confirmarCodigoUbicacion(_codigoUbicacionController.text, ubicacionesPendientes),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surface,
                              hintText: 'Código de la ubicación',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                                tooltip: 'Escanear',
                                onPressed: () => _escanearUbicacion(ubicacionesPendientes),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: () => _confirmarCodigoUbicacion(_codigoUbicacionController.text, ubicacionesPendientes),
                          child: const Text('Buscar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            ...ubicacionesPendientes.map((u) {
              final tile = Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                          if (u.codigo.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(u.codigo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        '${u.pendientes} pendiente${u.pendientes != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.waTx),
                      ),
                    ),
                  ],
                ),
              );
              final escaneoObligatorio = config?.escaneoUbicacionObligatorio ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  child: escaneoObligatorio
                      ? tile
                      : InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _elegirUbicacion(u.idUbicacion),
                          child: tile,
                        ),
                ),
              );
            }),
          ] else ...[
            if (pendientesVista.isNotEmpty) ...[
              const Text('PENDIENTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1)),
              const SizedBox(height: 8),
              ...pendientesVista.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TareaPickingTile(
                      tarea: t,
                      idSesion: sesion.idSesion,
                      idPedidoSubpedido: sesion.idPedidoSubpedido,
                    ),
                  )),
              const SizedBox(height: 16),
            ],
            if (completadasVista.isNotEmpty) ...[
              const Text('COMPLETADAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1)),
              const SizedBox(height: 8),
              // d) "Devolver" vive en cada tile completado (ver
              // TareaPickingTile) — no depende del cajón ni de la sesión.
              ...completadasVista.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TareaPickingTile(
                      tarea: t,
                      idSesion: sesion.idSesion,
                      idPedidoSubpedido: sesion.idPedidoSubpedido,
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ],

          // ===== e) Terminar picking — al pie de la lista mientras hay
          // pendientes; una vez completa la zona, el mismo botón pasa a
          // ser el FloatingActionButton de acá abajo.
          if (!zonaCompleta) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _terminando ? null : onTerminarPresionado,
                child: Text(_terminando ? 'Terminando...' : 'Terminar picking'),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: zonaCompleta
          ? FloatingActionButton.extended(
              onPressed: _terminando ? null : onTerminarPresionado,
              backgroundColor: const Color(0xFF22C55E),
              icon: _terminando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _terminando ? 'Terminando...' : 'Terminar picking',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// Cartel de cierre — se muestra recién después de que el operario confirma
/// tocando "Terminar picking" sobre una zona ya completa (ver doc de
/// `PickingTrabajoScreen`; antes aparecía apenas el backend cerraba la
/// sesión sola con `motivo_fin=AUTO_COMPLETADO`, sin que el operario hiciera
/// nada). Pantalla completa (no un diálogo transitorio) porque es la
/// confirmación de que el trabajo terminó bien y el operario necesita la
/// instrucción de dónde dejar los cajones.
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
