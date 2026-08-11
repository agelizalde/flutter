import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/picking_control_models.dart';
import 'widgets/item_control_tile.dart';
import 'widgets/rechazar_item_sheet.dart';

/// Ítems de un cajón (o del pseudo-cajón "SIN CAJÓN") dentro de una sesión
/// de control activa — ✓ aprueba directo con la cantidad pickeada, ✗ abre
/// el bottom sheet para rechazar el producto o corregir la cantidad.
///
/// Pushed (no ruta de go_router): recibe la lista de ítems ya cargada desde
/// `PickingControlDetalleScreen`, la reproduce en estado local para
/// reflejar cada revisión al instante, y no vuelve a pedir el detalle hasta
/// que el caller invalida el provider al volver.
class ControlCajonScreen extends ConsumerStatefulWidget {
  const ControlCajonScreen({super.key, required this.idPickingControl, required this.grupo});

  final int idPickingControl;
  final GrupoCajonControl grupo;

  @override
  ConsumerState<ControlCajonScreen> createState() => _ControlCajonScreenState();
}

class _ControlCajonScreenState extends ConsumerState<ControlCajonScreen> {
  late final List<ItemControl> _items = List.of(widget.grupo.items);
  String? _error;
  int? _procesando;

  Future<void> _aprobar(int index) async {
    final item = _items[index];
    if (item.idPickingControlItem == null) return;
    setState(() {
      _procesando = index;
      _error = null;
    });
    try {
      final actualizado = await aprobarItemControl(
        ref: ref,
        idPickingControl: widget.idPickingControl,
        item: item,
      );
      setState(() => _items[index] = actualizado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  Future<void> _abrirRechazoSheet(int index) async {
    final item = _items[index];
    if (item.idPickingControlItem == null) return;
    setState(() {
      _procesando = index;
      _error = null;
    });
    try {
      final actualizado = await rechazarItemControlConSheet(
        context: context,
        ref: ref,
        idPickingControl: widget.idPickingControl,
        item: item,
      );
      if (actualizado != null) setState(() => _items[index] = actualizado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.grupo.etiqueta)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
              child: Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
            ),
            const SizedBox(height: 14),
          ],
          ..._items.asMap().entries.map((e) {
            final index = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AbsorbPointer(
                absorbing: _procesando != null,
                child: Opacity(
                  opacity: _procesando == index ? 0.6 : 1,
                  child: ItemControlTile(
                    item: e.value,
                    onAprobar: () => _aprobar(index),
                    onRechazar: () => _abrirRechazoSheet(index),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
