import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/picking_control_providers.dart';
import '../../domain/picking_control_models.dart';

/// Resultado elegido en `RechazarItemSheet`: o bien un rechazo real (motivo
/// != CANTIDAD, cantidad forzada a 0) o una corrección de cantidad (motivo
/// CANTIDAD, cantidad la que haya tipeado el controlador).
class RevisionResultado {
  RevisionResultado({required this.cantidad, required this.motivo, this.observacion});

  final double cantidad;
  final String motivo;
  final String? observacion;
}

/// Aprueba un ítem directo con la cantidad pickeada. Usado igual desde las
/// 3 pantallas de control (cajón/lista/producto) -- devuelve el ItemControl
/// ya actualizado para que el caller lo reemplace en su lista local.
Future<ItemControl> aprobarItemControl({
  required WidgetRef ref,
  required int idPickingControl,
  required ItemControl item,
}) async {
  final r = await ref.read(pickingControlRepositoryProvider).revisarItem(
    idPickingControl: idPickingControl,
    idPickingControlItem: item.idPickingControlItem!,
    cantidadControlada: item.cantidadPickeada,
    resultado: 'APROBADO',
  );
  return item.copyWith(resultadoControl: 'APROBADO', cantidadControlada: r.cantidadControlada);
}

/// Abre el bottom sheet de rechazar/modificar cantidad y, si el controlador
/// confirma, llama a `revisar_item`. Devuelve el ItemControl actualizado, o
/// `null` si se canceló el sheet (el caller no debe tocar su lista local).
Future<ItemControl?> rechazarItemControlConSheet({
  required BuildContext context,
  required WidgetRef ref,
  required int idPickingControl,
  required ItemControl item,
}) async {
  final resultado = await showModalBottomSheet<RevisionResultado>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RechazarItemSheet(item: item),
  );
  if (resultado == null) return null;

  final r = await ref.read(pickingControlRepositoryProvider).revisarItem(
    idPickingControl: idPickingControl,
    idPickingControlItem: item.idPickingControlItem!,
    cantidadControlada: resultado.cantidad,
    resultado: 'RECHAZADO',
    motivosRechazo: resultado.motivo,
    observacion: resultado.observacion,
  );
  return item.copyWith(
    resultadoControl: 'RECHAZADO',
    cantidadControlada: r.cantidadControlada,
    motivosRechazo: resultado.motivo,
    observacionControl: resultado.observacion,
  );
}

/// Motivos disponibles al "rechazar producto" — excluye `CANTIDAD`, que es
/// el motivo reservado para el flujo "modificar cantidad" (ver
/// `motivosControlValidos` y la nota de diseño en CONTEXTO_WHEREHOUSE.md).
const _motivosRechazoProducto = ['CALIDAD', 'VENCIMIENTO', 'DANO', 'OTRO'];

const _motivoLabels = {
  'CANTIDAD': 'Cantidad',
  'CALIDAD': 'Calidad',
  'VENCIMIENTO': 'Vencimiento',
  'DANO': 'Daño',
  'OTRO': 'Otro',
};

String fmtCantidadControl(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class RechazarItemSheet extends StatefulWidget {
  const RechazarItemSheet({super.key, required this.item});

  final ItemControl item;

  @override
  State<RechazarItemSheet> createState() => _RechazarItemSheetState();
}

/// 'elegir' (pantalla inicial con las 2 acciones) | 'rechazar' | 'modificar'
enum _ModoSheet { elegir, rechazar, modificar }

class _RechazarItemSheetState extends State<RechazarItemSheet> {
  _ModoSheet _modo = _ModoSheet.elegir;
  String? _motivoSeleccionado;
  late final _cantidadController = TextEditingController(
    text: fmtCantidadControl(widget.item.cantidadPickeada),
  );
  final _observacionController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _cantidadController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_modo == _ModoSheet.rechazar) {
      if (_motivoSeleccionado == null) {
        setState(() => _error = 'Elegí un motivo');
        return;
      }
      Navigator.of(context).pop(
        RevisionResultado(
          cantidad: 0,
          motivo: _motivoSeleccionado!,
          observacion: _observacionController.text.trim().isEmpty ? null : _observacionController.text.trim(),
        ),
      );
      return;
    }

    // modificar cantidad
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad < 0) {
      setState(() => _error = 'Ingresá una cantidad válida');
      return;
    }
    Navigator.of(context).pop(
      RevisionResultado(
        cantidad: cantidad,
        motivo: 'CANTIDAD',
        observacion: _observacionController.text.trim().isEmpty ? null : _observacionController.text.trim(),
      ),
    );
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
                widget.item.productoNombre,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Pickeado: ${fmtCantidadControl(widget.item.cantidadPickeada)} ${widget.item.unidadSimbolo}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              if (_modo == _ModoSheet.elegir) ...[
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _modo = _ModoSheet.rechazar;
                    _error = null;
                  }),
                  icon: const Icon(Icons.block, color: AppColors.erTx),
                  label: const Text('Rechazar producto', style: TextStyle(color: AppColors.erTx)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _modo = _ModoSheet.modificar;
                    _error = null;
                  }),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modificar cantidad'),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () => setState(() {
                    _modo = _ModoSheet.elegir;
                    _error = null;
                  }),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Volver'),
                ),
                const SizedBox(height: 6),
                if (_modo == _ModoSheet.rechazar) ...[
                  const Text(
                    'Motivo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _motivosRechazoProducto.map((m) {
                      final sel = _motivoSeleccionado == m;
                      return ChoiceChip(
                        label: Text(_motivoLabels[m] ?? m),
                        selected: sel,
                        onSelected: (_) => setState(() => _motivoSeleccionado = m),
                        selectedColor: AppColors.erBg,
                        labelStyle: TextStyle(color: sel ? AppColors.erTx : AppColors.sub, fontWeight: FontWeight.w600),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  TextField(
                    controller: _cantidadController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Cantidad real (${widget.item.unidadSimbolo})'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _observacionController,
                  decoration: const InputDecoration(labelText: 'Observación (opcional)'),
                  maxLines: 2,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
                ],
                const SizedBox(height: 18),
                ElevatedButton(onPressed: _confirmar, child: const Text('Confirmar')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
