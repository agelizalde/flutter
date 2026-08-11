import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/picking_control_models.dart';
import 'widgets/item_control_tile.dart';
import 'widgets/rechazar_item_sheet.dart';

/// Control "por producto": agrupa todos los cajones/zonas donde aparece un
/// mismo producto, para revisarlo todo junto (con un botón de "aprobar
/// todos" que dispara `revisar_item` uno por uno, mismo criterio client-side
/// que ya usa `ProductoAggRow` en el WorkScreen web).
///
/// Pushed (no ruta de go_router), mismo patrón que `ControlCajonScreen`.
class ControlProductoScreen extends ConsumerStatefulWidget {
  const ControlProductoScreen({super.key, required this.idPickingControl, required this.items});

  final int idPickingControl;
  final List<ItemControl> items;

  @override
  ConsumerState<ControlProductoScreen> createState() => _ControlProductoScreenState();
}

class _ControlProductoScreenState extends ConsumerState<ControlProductoScreen> {
  late final List<ItemControl> _items = List.of(widget.items);
  String? _error;
  int? _procesandoId;
  int? _aprobandoTodoDeProducto;
  final Set<int> _expandidos = {};

  List<GrupoProductoControl> get _grupos {
    final orden = <int>[];
    final mapa = <int, List<ItemControl>>{};
    for (final item in _items) {
      final key = item.idProducto;
      final grupo = mapa.putIfAbsent(key, () {
        orden.add(key);
        return <ItemControl>[];
      });
      grupo.add(item);
    }
    final grupos = orden
        .map((key) => GrupoProductoControl(idProducto: key, etiqueta: mapa[key]!.first.productoNombre, items: mapa[key]!))
        .toList();
    grupos.sort((a, b) => a.etiqueta.compareTo(b.etiqueta));
    return grupos;
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

  Future<void> _aprobarTodos(GrupoProductoControl grupo) async {
    setState(() {
      _aprobandoTodoDeProducto = grupo.idProducto;
      _error = null;
    });
    try {
      // Uno por uno -- mismo criterio client-side que "Aprobar todo el
      // cajón" en la web, no hay endpoint bulk en el backend.
      for (final item in grupo.items) {
        if (item.controlado || item.idPickingControlItem == null) continue;
        final actualizado = await aprobarItemControl(
          ref: ref,
          idPickingControl: widget.idPickingControl,
          item: item,
        );
        if (!mounted) return;
        setState(() => _items[_indexDe(item)] = actualizado);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _aprobandoTodoDeProducto = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupos = _grupos;
    final pendientes = _items.where((i) => !i.controlado).length;

    return Scaffold(
      appBar: AppBar(title: Text('Por producto · $pendientes pend.')),
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
          ...grupos.map((g) {
            final expandido = _expandidos.contains(g.idProducto);
            final listo = g.pendientes == 0;
            final aprobandoTodo = _aprobandoTodoDeProducto == g.idProducto;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: listo ? AppColors.okBg : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() {
                        if (expandido) {
                          _expandidos.remove(g.idProducto);
                        } else {
                          _expandidos.add(g.idProducto);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    g.etiqueta,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${g.total} línea${g.total != 1 ? 's' : ''}'
                                    '${g.rechazados > 0 ? ' · ${g.rechazados} con error' : ''}',
                                    style: TextStyle(fontSize: 12, color: g.rechazados > 0 ? AppColors.erTx : AppColors.muted),
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
                                listo ? 'Listo' : '${g.pendientes} pend.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: listo ? AppColors.okTx : AppColors.waTx,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(expandido ? Icons.expand_less : Icons.expand_more, color: AppColors.faint),
                          ],
                        ),
                      ),
                    ),
                    if (expandido)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          children: [
                            if (!listo)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: aprobandoTodo ? null : () => _aprobarTodos(g),
                                    icon: aprobandoTodo
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.done_all, size: 18),
                                    label: Text(aprobandoTodo ? 'Aprobando...' : 'Aprobar todos'),
                                  ),
                                ),
                              ),
                            ...g.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: AbsorbPointer(
                                    absorbing: _procesandoId != null || _aprobandoTodoDeProducto != null,
                                    child: Opacity(
                                      opacity: _procesandoId == item.idPickingItem ? 0.6 : 1,
                                      child: ItemControlTile(
                                        item: item,
                                        onAprobar: () => _aprobar(item),
                                        onRechazar: () => _rechazar(item),
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
