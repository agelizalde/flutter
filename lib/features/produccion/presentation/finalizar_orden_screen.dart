import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/produccion_providers.dart';
import '../data/produccion_api.dart';
import '../domain/produccion_models.dart';

/// Pantalla de cierre (pasos 6-8): un solo formulario con las 3 cantidades
/// reales (consumo, resultado, merma) precargadas con lo planificado — a
/// diferencia del wizard de 4 pasos de la web, acá es simple y de un solo
/// scroll, pensado para completarse rápido parado en el taller.
class FinalizarOrdenScreen extends ConsumerStatefulWidget {
  const FinalizarOrdenScreen({super.key, required this.idOrden});

  final int idOrden;

  @override
  ConsumerState<FinalizarOrdenScreen> createState() => _FinalizarOrdenScreenState();
}

class _FinalizarOrdenScreenState extends ConsumerState<FinalizarOrdenScreen> {
  final Map<int, TextEditingController> _consumoCtrl = {};
  final Map<int, TextEditingController> _resultadoCtrl = {};
  final Map<int, TextEditingController> _mermaCtrl = {};
  bool _inicializado = false;
  bool _finalizando = false;
  String? _error;

  void _inicializar(OrdenProduccion orden) {
    if (_inicializado) return;
    _inicializado = true;
    for (final c in orden.consumo) {
      _consumoCtrl[c.idOrdenConsumo] = TextEditingController(text: _fmt(c.cantidadPlanificada));
    }
    for (final r in orden.resultado) {
      _resultadoCtrl[r.idOrdenResultado] = TextEditingController(text: _fmt(r.cantidadPlanificada));
    }
    for (final m in orden.mermas) {
      _mermaCtrl[m.idOrdenMerma] = TextEditingController(text: _fmt(m.cantidadPlanificada));
    }
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  double _leer(Map<int, TextEditingController> ctrls, int id) {
    final texto = ctrls[id]?.text.replaceAll(',', '.') ?? '0';
    return double.tryParse(texto) ?? 0;
  }

  @override
  void dispose() {
    for (final c in _consumoCtrl.values) {
      c.dispose();
    }
    for (final c in _resultadoCtrl.values) {
      c.dispose();
    }
    for (final c in _mermaCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _finalizar(OrdenProduccion orden) async {
    setState(() {
      _finalizando = true;
      _error = null;
    });
    try {
      await ref.read(produccionRepositoryProvider).finalizar(
        idOrden: orden.idOrden,
        expectedVersion: orden.rowVersion,
        consumo: [
          for (final c in orden.consumo)
            FinalizarLineaIn(id: c.idOrdenConsumo, cantidadReal: _leer(_consumoCtrl, c.idOrdenConsumo)),
        ],
        resultado: [
          for (final r in orden.resultado)
            FinalizarLineaIn(id: r.idOrdenResultado, cantidadReal: _leer(_resultadoCtrl, r.idOrdenResultado)),
        ],
        mermas: [
          for (final m in orden.mermas)
            FinalizarLineaIn(id: m.idOrdenMerma, cantidadReal: _leer(_mermaCtrl, m.idOrdenMerma)),
        ],
      );
      ref.invalidate(ordenDetalleProvider(orden.idOrden));
      ref.invalidate(ordenesEnCursoProvider);
      if (!mounted) return;
      context.go('/produccion/taller/${orden.idOrden}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ordenDetalleProvider(widget.idOrden));

    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar producción')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (orden) {
          _inicializar(orden);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text(
                'Cargá exactamente lo que pasó — el sistema ajusta el stock real y aprende de esta producción.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _SeccionCantidades(
                titulo: '¿CUÁNTO USASTE?',
                icono: Icons.inventory_2_outlined,
                filas: [
                  for (final c in orden.consumo)
                    _FilaCantidad(nombre: c.productoNombre, unidad: c.unidadSimbolo, controller: _consumoCtrl[c.idOrdenConsumo]!),
                ],
              ),
              const SizedBox(height: 20),
              _SeccionCantidades(
                titulo: '¿CUÁNTO PRODUJISTE?',
                icono: Icons.emoji_events_outlined,
                filas: [
                  for (final r in orden.resultado)
                    _FilaCantidad(nombre: r.productoNombre, unidad: r.unidadSimbolo, controller: _resultadoCtrl[r.idOrdenResultado]!),
                ],
              ),
              if (orden.mermas.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SeccionCantidades(
                  titulo: '¿CUÁNTA MERMA HUBO?',
                  icono: Icons.local_fire_department_outlined,
                  filas: [
                    for (final m in orden.mermas)
                      _FilaCantidad(nombre: m.productoNombre, unidad: m.unidadSimbolo, controller: _mermaCtrl[m.idOrdenMerma]!),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppColors.erTx)),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _finalizando ? null : () => _finalizar(orden),
                icon: _finalizando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_finalizando ? 'Finalizando...' : 'Finalizar producción'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SeccionCantidades extends StatelessWidget {
  const _SeccionCantidades({required this.titulo, required this.icono, required this.filas});

  final String titulo;
  final IconData icono;
  final List<_FilaCantidad> filas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 15, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: filas),
        ),
      ],
    );
  }
}

class _FilaCantidad extends StatelessWidget {
  const _FilaCantidad({required this.nombre, required this.unidad, required this.controller});

  final String nombre;
  final String unidad;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(nombre, style: const TextStyle(fontSize: 13.5, color: AppColors.text, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 110,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixText: unidad,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
