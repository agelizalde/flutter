import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/produccion_providers.dart';
import '../domain/produccion_models.dart';

String _fmtReloj(int segundos) {
  var s = segundos;
  if (s < 0) s = 0;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  final mStr = m.toString().padLeft(2, '0');
  final sStr = ss.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mStr:$sStr' : '$mStr:$sStr';
}

/// Pantalla "en curso" (`/produccion/taller/:idOrden`, pasos 4-5): cronómetro
/// grande, pausar/reanudar, y botón para pasar a finalizar. Es la pantalla a
/// la que también se vuelve desde "Retomar" en el Home si se cerró la app a
/// mitad de una producción.
class OrdenEnCursoScreen extends ConsumerStatefulWidget {
  const OrdenEnCursoScreen({super.key, required this.idOrden});

  final int idOrden;

  @override
  ConsumerState<OrdenEnCursoScreen> createState() => _OrdenEnCursoScreenState();
}

class _OrdenEnCursoScreenState extends ConsumerState<OrdenEnCursoScreen> {
  Timer? _tick;
  OrdenProduccion? _ultimaOrdenVista;
  DateTime? _fetchedAt;
  bool _cambiandoEstado = false;
  bool _anulando = false;

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

  Future<void> _pausar(OrdenProduccion orden) async {
    setState(() => _cambiandoEstado = true);
    try {
      await ref.read(produccionRepositoryProvider).pausar(idOrden: orden.idOrden, expectedVersion: orden.rowVersion);
      ref.invalidate(ordenDetalleProvider(widget.idOrden));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cambiandoEstado = false);
    }
  }

  Future<void> _reanudar(OrdenProduccion orden) async {
    setState(() => _cambiandoEstado = true);
    try {
      await ref.read(produccionRepositoryProvider).reanudar(idOrden: orden.idOrden, expectedVersion: orden.rowVersion);
      ref.invalidate(ordenDetalleProvider(widget.idOrden));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cambiandoEstado = false);
    }
  }

  Future<void> _anular(OrdenProduccion orden) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular producción'),
        content: const Text('Se revierte todo el consumo de insumos ya descontado. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Anular')),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _anulando = true);
    try {
      await ref.read(produccionRepositoryProvider).anular(idOrden: orden.idOrden, expectedVersion: orden.rowVersion);
      ref.invalidate(ordenesEnCursoProvider);
      if (!mounted) return;
      context.go('/produccion');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _anulando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ordenDetalleProvider(widget.idOrden));

    return Scaffold(
      appBar: AppBar(title: const Text('Producción en curso')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (orden) {
          if (!identical(orden, _ultimaOrdenVista)) {
            _ultimaOrdenVista = orden;
            _fetchedAt = DateTime.now();
          }

          if (orden.estado == 'FINALIZADA' || orden.estado == 'ANULADA') {
            return _EstadoTerminalCartel(orden: orden);
          }

          final enProceso = orden.estado == 'EN_PROCESO';
          final elapsed = enProceso
              ? orden.tiempoTranscurridoSegundos + DateTime.now().difference(_fetchedAt!).inSeconds
              : orden.tiempoTranscurridoSegundos;
          final progreso = orden.tiempoEstimadoSegundos > 0
              ? (elapsed / orden.tiempoEstimadoSegundos).clamp(0.0, 1.0)
              : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(orden.codigo, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CircularProgressIndicator(
                          value: progreso,
                          strokeWidth: 10,
                          backgroundColor: AppColors.soft,
                          color: enProceso ? AppColors.accent : AppColors.waTx,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fmtReloj(elapsed),
                            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            enProceso ? 'Produciendo...' : 'Pausada',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: enProceso ? AppColors.accent : AppColors.waTx),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cambiandoEstado
                          ? null
                          : () => enProceso ? _pausar(orden) : _reanudar(orden),
                      icon: Icon(enProceso ? Icons.pause : Icons.play_arrow),
                      label: Text(enProceso ? 'Pausar' : 'Reanudar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/produccion/taller/${orden.idOrden}/finalizar'),
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Finalizar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('CONSUMO PLANIFICADO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    for (var i = 0; i < orden.consumo.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(child: Text(orden.consumo[i].productoNombre, style: const TextStyle(fontSize: 13.5, color: AppColors.text))),
                            Text(
                              '${orden.consumo[i].cantidadPlanificada.toStringAsFixed(2)} ${orden.consumo[i].unidadSimbolo}',
                              style: const TextStyle(fontSize: 13.5, color: AppColors.sub, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: _anulando ? null : () => _anular(orden),
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.erTx, size: 18),
                  label: Text(_anulando ? 'Anulando...' : 'Anular producción', style: const TextStyle(color: AppColors.erTx)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EstadoTerminalCartel extends StatelessWidget {
  const _EstadoTerminalCartel({required this.orden});

  final OrdenProduccion orden;

  @override
  Widget build(BuildContext context) {
    final finalizada = orden.estado == 'FINALIZADA';
    OrdenLineaResultado? principal;
    for (final r in orden.resultado) {
      if (r.esPrincipal) {
        principal = r;
        break;
      }
    }
    final mermaTotal = orden.mermas.fold<double>(0, (acc, m) => acc + (m.cantidadReal ?? 0));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: finalizada ? const Color(0xFF22C55E) : AppColors.erTx, shape: BoxShape.circle),
              child: Icon(finalizada ? Icons.check : Icons.close, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              finalizada ? '¡Producción completa!' : 'Producción anulada',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            Text(orden.codigo, style: const TextStyle(color: AppColors.muted)),
            if (finalizada) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (principal != null)
                    _StatFinal(
                      label: 'Producido',
                      valor: '${principal.cantidadReal?.toStringAsFixed(2) ?? '—'} ${principal.unidadSimbolo}',
                    ),
                  if (principal != null) const SizedBox(width: 16),
                  _StatFinal(label: 'Tiempo real', valor: _fmtReloj(orden.tiempoRealSegundos ?? orden.tiempoTranscurridoSegundos)),
                  if (orden.mermas.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    _StatFinal(label: 'Merma', valor: mermaTotal.toStringAsFixed(2)),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 28),
            if (finalizada) ...[
              ElevatedButton.icon(
                onPressed: () => context.push('/produccion/taller/${orden.idOrden}/etiquetas'),
                icon: const Icon(Icons.print_outlined),
                label: const Text('Ver e imprimir etiquetas'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/produccion'),
                child: const Text('Volver a Producción'),
              ),
            ] else
              ElevatedButton(
                onPressed: () => context.go('/produccion'),
                child: const Text('Volver a Producción'),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatFinal extends StatelessWidget {
  const _StatFinal({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
