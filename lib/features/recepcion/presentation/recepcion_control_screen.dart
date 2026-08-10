import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/recepcion_providers.dart';
import '../domain/recepcion_models.dart';

/// Resolución del control de calidad de una recepción `PEND_CONTROL`
/// (`POST /recepciones/control/{id}/resolver`). Por ítem se carga la
/// cantidad recibida/rechazada (default: toda la cantidad recibida, nada
/// rechazado) y al final se elige el resultado general del control.
class RecepcionControlScreen extends ConsumerStatefulWidget {
  const RecepcionControlScreen({super.key, required this.idRecepcion});

  final int idRecepcion;

  @override
  ConsumerState<RecepcionControlScreen> createState() => _RecepcionControlScreenState();
}

class _RecepcionControlScreenState extends ConsumerState<RecepcionControlScreen> {
  final Map<int, TextEditingController> _recibidoCtrl = {};
  final Map<int, TextEditingController> _rechazadoCtrl = {};
  final _observacionCtrl = TextEditingController();
  bool _controladoresListos = false;
  String? _resultado;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in _recibidoCtrl.values) {
      c.dispose();
    }
    for (final c in _rechazadoCtrl.values) {
      c.dispose();
    }
    _observacionCtrl.dispose();
    super.dispose();
  }

  void _prepararControladores(List<RecepcionItem> items) {
    if (_controladoresListos) return;
    for (final item in items) {
      _recibidoCtrl[item.idRecepcionItem] = TextEditingController(text: item.cantidad.toStringAsFixed(0));
      _rechazadoCtrl[item.idRecepcionItem] = TextEditingController(text: '0');
    }
    _controladoresListos = true;
  }

  Future<void> _guardar(PreparacionControl prep) async {
    if (_resultado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí si el control es positivo o negativo')),
      );
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final item in prep.items) {
      final recibido = double.tryParse(_recibidoCtrl[item.idRecepcionItem]!.text.trim());
      final rechazado = double.tryParse(_rechazadoCtrl[item.idRecepcionItem]!.text.trim());
      if (recibido == null || rechazado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Revisá las cantidades de "${item.productoNombre}"')),
        );
        return;
      }
      if (rechazado > recibido) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${item.productoNombre}": lo rechazado no puede superar lo recibido')),
        );
        return;
      }
      items.add({
        'id_recepcion_item': item.idRecepcionItem,
        'cantidad_recibida': recibido,
        'cantidad_rechazada': rechazado,
      });
    }

    setState(() => _guardando = true);
    try {
      await ref.read(recepcionRepositoryProvider).resolverControl(
            idRecepcionControl: prep.idRecepcionControl,
            expectedVersion: prep.expectedVersion,
            resultado: _resultado!,
            observacion: _observacionCtrl.text.trim().isEmpty ? null : _observacionCtrl.text.trim(),
            items: items,
          );
      ref.invalidate(recepcionDetalleProvider(widget.idRecepcion));
      ref.invalidate(recepcionesRecientesProvider);
      ref.invalidate(recepcionListadoProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recepcionControlPreparacionProvider(widget.idRecepcion));

    return Scaffold(
      appBar: AppBar(title: const Text('Controlar recepción')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (prep) {
          _prepararControladores(prep.items);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.alertBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.alertTx, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Revisá la mercadería recibida y cargá lo que realmente llegó en buen estado.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.alertTx, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ÍTEMS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              for (final item in prep.items) ...[
                _ItemControlCard(
                  item: item,
                  recibidoController: _recibidoCtrl[item.idRecepcionItem]!,
                  rechazadoController: _rechazadoCtrl[item.idRecepcionItem]!,
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
              const Text(
                'RESULTADO DEL CONTROL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ResultadoOpcion(
                      etiqueta: 'Aprobar',
                      icono: Icons.check_circle_outline,
                      color: AppColors.okTx,
                      colorBg: AppColors.okBg,
                      seleccionado: _resultado == 'POSITIVO',
                      onTap: () => setState(() => _resultado = 'POSITIVO'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultadoOpcion(
                      etiqueta: 'Rechazar',
                      icono: Icons.cancel_outlined,
                      color: AppColors.erTx,
                      colorBg: AppColors.erBg,
                      seleccionado: _resultado == 'NEGATIVO',
                      onTap: () => setState(() => _resultado = 'NEGATIVO'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _observacionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observación (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardando ? null : () => _guardar(prep),
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar control'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemControlCard extends StatelessWidget {
  const _ItemControlCard({
    required this.item,
    required this.recibidoController,
    required this.rechazadoController,
  });

  final RecepcionItem item;
  final TextEditingController recibidoController;
  final TextEditingController rechazadoController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.accentDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.productoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                ),
              ),
              Text(
                '${item.cantidad.toStringAsFixed(0)} ${item.unidadSimbolo}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: recibidoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Recibido'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: rechazadoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rechazado'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultadoOpcion extends StatelessWidget {
  const _ResultadoOpcion({
    required this.etiqueta,
    required this.icono,
    required this.color,
    required this.colorBg,
    required this.seleccionado,
    required this.onTap,
  });

  final String etiqueta;
  final IconData icono;
  final Color color;
  final Color colorBg;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seleccionado ? colorBg : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: seleccionado ? color : AppColors.borderStrong, width: seleccionado ? 1.5 : 1),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icono, color: seleccionado ? color : AppColors.muted, size: 24),
              const SizedBox(height: 6),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: seleccionado ? color : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
