import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../application/expedicion_providers.dart';
import '../domain/expedicion_models.dart';
import 'widgets/devolucion_carga_tile.dart';

/// Checklist de carga de un subpedido `EN_CARGA`: en modo ESCANEO, escanear
/// un cajón (o el código de barra de un producto suelto) descuenta stock al
/// toque; en modo CONTEO, cada línea se cuenta a mano con +/- y el stock se
/// descuenta todo junto recién al "Finalizar carga" (ver
/// `subpedido_expedicion_service.py::completar_carga`).
class ExpedicionDetalleScreen extends ConsumerStatefulWidget {
  const ExpedicionDetalleScreen({super.key, required this.idPedidoSubpedido});

  final int idPedidoSubpedido;

  @override
  ConsumerState<ExpedicionDetalleScreen> createState() => _ExpedicionDetalleScreenState();
}

class _ExpedicionDetalleScreenState extends ConsumerState<ExpedicionDetalleScreen> {
  bool _procesando = false;
  String? _error;

  Future<void> _escanear(DetalleCarga detalle) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    final linea = detalle.matchEscaneo(codigo);
    if (linea == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese código no corresponde a ningún cajón/producto pendiente de este subpedido.')),
      );
      return;
    }
    await _procesar(() => ref.read(expedicionRepositoryProvider).escanearLinea(widget.idPedidoSubpedido, linea.idLinea));
  }

  Future<void> _contar(LineaCarga linea, int delta) async {
    await _procesar(() => ref.read(expedicionRepositoryProvider).contarLinea(widget.idPedidoSubpedido, linea.idLinea, delta));
  }

  Future<void> _procesar(Future<void> Function() accion) async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      await accion();
      ref.invalidate(detalleCargaProvider(widget.idPedidoSubpedido));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _finalizarCarga() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      await ref.read(expedicionRepositoryProvider).completarCarga(widget.idPedidoSubpedido);
      if (!mounted) return;
      ref.invalidate(subpedidosEnCargaProvider);
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
    final async = ref.watch(detalleCargaProvider(widget.idPedidoSubpedido));
    final devoluciones = ref.watch(devolucionesCargaProvider(widget.idPedidoSubpedido)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Carga de camión')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
        data: (detalle) {
          final resumen = detalle.resumen;
          final esEscaneo = detalle.carga.modoCarga == 'ESCANEO';

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
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: resumen.total > 0 ? resumen.cargados / resumen.total : 0,
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
                    if (devoluciones.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const Text(
                        'DEVOLUCIONES PENDIENTES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ventas modificó el pedido — retirá esto del camión y confirmá.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      ...devoluciones.map((d) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DevolucionCargaTile(idPedidoSubpedido: widget.idPedidoSubpedido, devolucion: d),
                          )),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            esEscaneo ? 'CAJONES / PRODUCTOS (ESCANEO)' : 'CAJONES / PRODUCTOS (CONTEO)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                          ),
                        ),
                        if (esEscaneo)
                          TextButton.icon(
                            onPressed: _procesando ? null : () => _escanear(detalle),
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text('Escanear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...detalle.lineas.map((l) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _LineaCargaTile(
                            linea: l,
                            modoConteo: !esEscaneo,
                            procesando: _procesando,
                            onIncrementar: () => _contar(l, 1),
                            onDecrementar: () => _contar(l, -1),
                          ),
                        )),
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  onPressed: (_procesando || resumen.pendientes > 0) ? null : _finalizarCarga,
                  child: _procesando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          resumen.pendientes > 0
                              ? 'Faltan ${resumen.pendientes} línea(s) por cargar'
                              : 'Finalizar carga',
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

class _LineaCargaTile extends StatelessWidget {
  const _LineaCargaTile({
    required this.linea,
    required this.modoConteo,
    required this.procesando,
    required this.onIncrementar,
    required this.onDecrementar,
  });

  final LineaCarga linea;
  final bool modoConteo;
  final bool procesando;
  final VoidCallback onIncrementar;
  final VoidCallback onDecrementar;

  @override
  Widget build(BuildContext context) {
    final listo = linea.completa;

    return Material(
      color: listo ? AppColors.okBg : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
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
                linea.esCajon ? Icons.all_inbox_outlined : Icons.inventory_2_outlined,
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
                    linea.etiqueta,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                  ),
                  if (!linea.esCajon) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${linea.cantidadCargada.toStringAsFixed(0)}/${linea.cantidadObjetivo.toStringAsFixed(0)} ${linea.unidadSimbolo ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            if (modoConteo && !listo) ...[
              IconButton(
                onPressed: procesando || linea.cantidadCargada <= 0 ? null : onDecrementar,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 22,
              ),
              IconButton(
                onPressed: procesando ? null : onIncrementar,
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 22,
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: listo ? AppColors.okBg : AppColors.waBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  listo ? 'Listo' : 'Pendiente',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: listo ? AppColors.okTx : AppColors.waTx,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
