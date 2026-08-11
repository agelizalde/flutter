import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../application/picking_control_providers.dart';
import '../domain/picking_control_models.dart';
import 'control_cajon_screen.dart';
import 'control_lista_screen.dart';
import 'control_producto_screen.dart';

/// Busca, entre los grupos ya cargados del subpedido, el cajón cuyo
/// identificador o código de barras coincide con lo escaneado (sin
/// distinguir mayúsculas/espacios). El pseudo-cajón "SIN CAJÓN" nunca
/// matchea — no tiene código físico que escanear.
GrupoCajonControl? _matchCajonEscaneado(List<GrupoCajonControl> grupos, String codigoRaw) {
  final codigo = codigoRaw.trim().toLowerCase();
  for (final g in grupos) {
    if (g.idContenedor == null || g.items.isEmpty) continue;
    final item = g.items.first;
    final ident = item.contenedorIdentificador?.trim().toLowerCase();
    final barras = item.contenedorCodigoBarras?.trim().toLowerCase();
    if (codigo == ident || codigo == barras) return g;
  }
  return null;
}

String _modoLabel(String modo) {
  switch (modo) {
    case 'CAJON':
      return 'cajón';
    case 'PRODUCTO':
      return 'producto';
    default:
      return 'lista';
  }
}

/// Detalle de un subpedido en control: agrupa los ítems listos por cajón
/// físico (más el pseudo-cajón "SIN CAJÓN") y deja iniciar/retomar la sesión
/// de control y confirmarla cuando no queden pendientes.
class PickingControlDetalleScreen extends ConsumerStatefulWidget {
  const PickingControlDetalleScreen({super.key, required this.idPedidoSubpedido});

  final int idPedidoSubpedido;

  @override
  ConsumerState<PickingControlDetalleScreen> createState() => _PickingControlDetalleScreenState();
}

class _PickingControlDetalleScreenState extends ConsumerState<PickingControlDetalleScreen> {
  bool _procesando = false;
  String? _error;

  Future<void> _iniciarControl() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      await ref.read(pickingControlRepositoryProvider).iniciarControl(widget.idPedidoSubpedido);
      ref.invalidate(detalleControlProvider(widget.idPedidoSubpedido));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _abrirCajon(int idPickingControl, GrupoCajonControl grupo) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ControlCajonScreen(idPickingControl: idPickingControl, grupo: grupo),
      ),
    );
    ref.invalidate(detalleControlProvider(widget.idPedidoSubpedido));
  }

  Future<void> _abrirLista(int idPickingControl, List<ItemControl> items) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ControlListaScreen(idPickingControl: idPickingControl, items: items),
      ),
    );
    ref.invalidate(detalleControlProvider(widget.idPedidoSubpedido));
  }

  Future<void> _abrirPorProducto(int idPickingControl, List<ItemControl> items) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ControlProductoScreen(idPickingControl: idPickingControl, items: items),
      ),
    );
    ref.invalidate(detalleControlProvider(widget.idPedidoSubpedido));
  }

  Future<void> _escanearCajon(int idPickingControl, List<GrupoCajonControl> grupos) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    final grupo = _matchCajonEscaneado(grupos, codigo);
    if (grupo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese cajón no pertenece a este subpedido o todavía no está listo para controlar.'),
        ),
      );
      return;
    }
    await _abrirCajon(idPickingControl, grupo);
  }

  Future<void> _confirmarControl(int idPickingControl) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      await ref.read(pickingControlRepositoryProvider).confirmarControl(idPickingControl);
      if (!mounted) return;
      ref.invalidate(detalleControlProvider(widget.idPedidoSubpedido));
      ref.invalidate(subpedidosControlProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(detalleControlProvider(widget.idPedidoSubpedido));
    final miIdUsuario = ref.watch(authControllerProvider).value?.idUsuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Control de subpedido')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
        data: (detalle) {
          final activo = detalle.controlActivo;
          final grupos = detalle.gruposPorCajon;
          final resumen = detalle.resumen;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      detalle.subpedido.tituloDisplay,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                    ),
                    if (detalle.subpedido.codigoPedido != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detalle.subpedido.codigoPedido!,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (activo == null) ...[
                      Builder(builder: (context) {
                        final asignacion = detalle.asignacion;
                        // Asignación exclusiva: si hay alguien asignado y no soy yo,
                        // no puedo iniciar (el backend también lo bloquea con 403).
                        final asignadoAOtro = asignacion != null && asignacion.idUsuarioAsignado != miIdUsuario;

                        if (asignadoAOtro) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                            child: Text(
                              'Asignado a ${asignacion.nombreAsignado ?? "otro usuario"} — esperando que inicie el control.',
                              style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600),
                            ),
                          );
                        }
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asignacion != null
                                    ? 'Te asignaron este control (modo ${_modoLabel(asignacion.modoControl)}). Todavía no lo iniciaste.'
                                    : 'Todavía no iniciaste el control de este subpedido.',
                                style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _procesando ? null : _iniciarControl,
                                child: _procesando
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Iniciar control'),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: resumen.total > 0 ? (resumen.aprobados + resumen.rechazados) / resumen.total : 0,
                                minHeight: 8,
                                backgroundColor: AppColors.soft,
                                color: AppColors.accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${resumen.pendientes} pend.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (activo.modoControl == 'LISTA') ...[
                        _ModoEntryCard(
                          icono: Icons.list_alt,
                          titulo: 'Lista completa',
                          subtitulo: '${resumen.pendientes} de ${resumen.total} ítem(s) pendientes',
                          boton: 'Ver lista',
                          onTap: () => _abrirLista(activo.idPickingControl, detalle.items),
                        ),
                      ] else if (activo.modoControl == 'PRODUCTO') ...[
                        _ModoEntryCard(
                          icono: Icons.inventory_2_outlined,
                          titulo: 'Por producto',
                          subtitulo: '${detalle.gruposPorProducto.length} producto(s) · ${resumen.pendientes} pendiente(s)',
                          boton: 'Ver por producto',
                          onTap: () => _abrirPorProducto(activo.idPickingControl, detalle.items),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'CAJONES',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _escanearCajon(activo.idPickingControl, grupos),
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('Escanear'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...grupos.map((g) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _GrupoCajonTile(
                                grupo: g,
                                onTap: () => _abrirCajon(activo.idPickingControl, g),
                              ),
                            )),
                      ],
                    ],
                  ],
                ),
              ),
              if (activo != null)
                SafeArea(
                  minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ElevatedButton(
                    onPressed: (_procesando || resumen.pendientes > 0)
                        ? null
                        : () => _confirmarControl(activo.idPickingControl),
                    child: _procesando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            resumen.pendientes > 0
                                ? 'Confirmá los ${resumen.pendientes} ítem(s) pendientes'
                                : 'Confirmar control',
                          ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta de entrada única para los modos Lista/Producto -- a diferencia
/// de Cajón (que muestra la grilla de cajones acá mismo), estos dos abren
/// una pantalla propia porque no tiene sentido navegarlos "de a uno" desde
/// el detalle.
class _ModoEntryCard extends StatelessWidget {
  const _ModoEntryCard({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.boton,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String boton;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accentSoft),
                child: Icon(icono, size: 20, color: AppColors.accentDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
                    const SizedBox(height: 2),
                    Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              TextButton(onPressed: onTap, child: Text(boton)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrupoCajonTile extends StatelessWidget {
  const _GrupoCajonTile({required this.grupo, required this.onTap});

  final GrupoCajonControl grupo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final listo = grupo.pendientes == 0;

    return Material(
      color: listo ? AppColors.okBg : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listo ? const Color(0xFF22C55E) : AppColors.accentSoft,
                ),
                child: Icon(
                  grupo.idContenedor == null ? Icons.inventory_2_outlined : Icons.all_inbox_outlined,
                  size: 18,
                  color: listo ? Colors.white : AppColors.accentDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grupo.etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${grupo.total} ítem${grupo.total != 1 ? 's' : ''}'
                      '${grupo.rechazados > 0 ? ' · ${grupo.rechazados} con error' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: grupo.rechazados > 0 ? AppColors.erTx : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: listo ? AppColors.okBg : AppColors.waBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  listo ? 'Listo' : '${grupo.pendientes} pend.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: listo ? AppColors.okTx : AppColors.waTx,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
