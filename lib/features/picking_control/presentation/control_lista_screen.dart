import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/picking_control_models.dart';
import 'widgets/item_control_tile.dart';
import 'widgets/rechazar_item_sheet.dart';

/// Control "por lista completa": todos los ítems del subpedido, uno por uno,
/// en orden de zona/ubicación, sin agrupar. Mismo criterio que el tab
/// "Lista" del WorkScreen web (`PickingControlWorkScreen.jsx`).
///
/// Pushed (no ruta de go_router), mismo patrón que `ControlCajonScreen`:
/// recibe los ítems ya cargados, refleja cada revisión al instante en
/// estado local, y el caller invalida el detalle al volver.
class ControlListaScreen extends ConsumerStatefulWidget {
  const ControlListaScreen({super.key, required this.idPickingControl, required this.items});

  final int idPickingControl;
  final List<ItemControl> items;

  @override
  ConsumerState<ControlListaScreen> createState() => _ControlListaScreenState();
}

class _ControlListaScreenState extends ConsumerState<ControlListaScreen> {
  late final List<ItemControl> _items = List.of(widget.items);
  final _busquedaController = TextEditingController();
  String _busqueda = '';
  String? _error;
  int? _procesandoId;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<ItemControl> get _filtrados {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((i) {
      return i.productoNombre.toLowerCase().contains(q) ||
          (i.productoCodigo ?? '').toLowerCase().contains(q) ||
          (i.contenedorIdentificador ?? '').toLowerCase().contains(q) ||
          (i.loteInterno ?? '').toLowerCase().contains(q) ||
          (i.loteProveedor ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int _indexDe(ItemControl item) => _items.indexWhere((i) => i.idPickingItem == item.idPickingItem);

  Future<void> _aprobar(ItemControl item) async {
    if (item.idPickingControlItem == null) return;
    setState(() {
      _procesandoId = item.idPickingItem;
      _error = null;
    });
    try {
      final actualizado = await aprobarItemControl(
        ref: ref,
        idPickingControl: widget.idPickingControl,
        item: item,
      );
      setState(() => _items[_indexDe(item)] = actualizado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  Future<void> _rechazar(ItemControl item) async {
    if (item.idPickingControlItem == null) return;
    setState(() {
      _procesandoId = item.idPickingItem;
      _error = null;
    });
    try {
      final actualizado = await rechazarItemControlConSheet(
        context: context,
        ref: ref,
        idPickingControl: widget.idPickingControl,
        item: item,
      );
      if (actualizado != null) setState(() => _items[_indexDe(item)] = actualizado);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _items.where((i) => !i.controlado).length;
    final filtrados = _filtrados;

    return Scaffold(
      appBar: AppBar(title: Text('Lista completa · $pendientes pend.')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: TextField(
              controller: _busquedaController,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar producto, cajón, lote...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _busqueda.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() {
                          _busqueda = '';
                          _busquedaController.clear();
                        }),
                      ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
                child: Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
              ),
            ),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(
                    child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: filtrados.length,
                    itemBuilder: (context, i) {
                      final item = filtrados[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AbsorbPointer(
                          absorbing: _procesandoId != null,
                          child: Opacity(
                            opacity: _procesandoId == item.idPickingItem ? 0.6 : 1,
                            child: ItemControlTile(
                              item: item,
                              onAprobar: () => _aprobar(item),
                              onRechazar: () => _rechazar(item),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
