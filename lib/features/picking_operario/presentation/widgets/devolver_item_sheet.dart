import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../application/picking_providers.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Bottom sheet para devolver (revertir) un ítem ya pickeado — vuelve a
/// `ASIGNADO` para re-pickear, `POST /picking-operario/picking-item/{id}/devolver`.
/// Compartido entre `TareaPickingTile` (acción directa sobre una tarea
/// completada, el caso de uso principal — no depende de que el almacén
/// pickee con contenedor) y `CajonItemsScreen` (ver todo lo que hay en un
/// cajón físico, incluso de otras zonas del mismo subpedido). Recibe datos
/// primitivos en vez de un modelo puntual (`TareaPicking` o
/// `ItemPickeadoCajon`) justamente para no atarse a ninguno de los dos.
class DevolverItemSheet extends ConsumerStatefulWidget {
  const DevolverItemSheet({
    super.key,
    required this.idPickingItem,
    required this.productoNombre,
    required this.cantidadPickeada,
    this.unidadSimbolo,
  });

  final int idPickingItem;
  final String productoNombre;
  final double cantidadPickeada;
  final String? unidadSimbolo;

  @override
  ConsumerState<DevolverItemSheet> createState() => _DevolverItemSheetState();
}

class _DevolverItemSheetState extends ConsumerState<DevolverItemSheet> {
  late final _cantidadController = TextEditingController(text: _fmtCantidad(widget.cantidadPickeada));
  final _motivoController = TextEditingController();
  bool _confirmando = false;
  String? _error;

  @override
  void dispose() {
    _cantidadController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0 || cantidad > widget.cantidadPickeada) {
      setState(() => _error = 'Ingresá una cantidad válida (máx. ${_fmtCantidad(widget.cantidadPickeada)})');
      return;
    }
    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      await ref.read(pickingRepositoryProvider).devolverItem(
        idPickingItem: widget.idPickingItem,
        cantidadDevolver: cantidad,
        motivo: _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e);
        _confirmando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Text(
                widget.productoNombre,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Pickeado: ${_fmtCantidad(widget.cantidadPickeada)} ${widget.unidadSimbolo ?? ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cantidadController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Cantidad a devolver'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _motivoController,
                decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
                maxLength: 500,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _confirmando ? null : _confirmar,
                child: _confirmando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmar devolución'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
