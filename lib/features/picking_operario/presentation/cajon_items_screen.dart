import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/picking_providers.dart';
import '../domain/picking_models.dart';
import 'widgets/devolver_item_sheet.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Ítems ya pickeados dentro de un cajón — pusheada con `Navigator` desde el
/// chip de "Cajón activo" de `PickingTrabajoScreen` (no es ruta de
/// go_router, mismo tratamiento que `CajonSelectorScreen`). Permite devolver
/// un ítem (revertir su picking: vuelve a `ASIGNADO` para re-pickear) si
/// Ajustes -> Operaciones -> Picking lo permite (`permite_devolver_item`,
/// ver [PickingConfig]) y el ítem todavía no pasó por control
/// (`puede_devolver`, resuelto server-side).
class CajonItemsScreen extends ConsumerStatefulWidget {
  const CajonItemsScreen({super.key, required this.idContenedor, required this.permiteDevolverItem});

  final int idContenedor;
  final bool permiteDevolverItem;

  @override
  ConsumerState<CajonItemsScreen> createState() => _CajonItemsScreenState();
}

class _CajonItemsScreenState extends ConsumerState<CajonItemsScreen> {
  late Future<CajonItemsResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(pickingRepositoryProvider).cajonItems(widget.idContenedor);
  }

  void _reload() {
    setState(() => _future = ref.read(pickingRepositoryProvider).cajonItems(widget.idContenedor));
  }

  Future<void> _devolver(ItemPickeadoCajon item) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DevolverItemSheet(
        idPickingItem: item.idPickingItem,
        productoNombre: item.productoNombre,
        cantidadPickeada: item.cantidadPickeada,
        unidadSimbolo: item.unidadSimbolo,
      ),
    );
    if (resultado == true) {
      _reload();
      ref.invalidate(misTareasProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ítems del cajón')),
      body: FutureBuilder<CajonItemsResponse>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text(describeError(snap.error!), style: const TextStyle(color: AppColors.erTx)));
          }
          final data = snap.data!;
          if (data.items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Este cajón todavía no tiene ítems pickeados.', style: TextStyle(color: AppColors.muted)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: data.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final item = data.items[i];
              final puedeDevolver = widget.permiteDevolverItem && item.puedeDevolver;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productoNombre,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_fmtCantidad(item.cantidadPickeada)} ${item.unidadSimbolo ?? ''}',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (puedeDevolver)
                      TextButton(onPressed: () => _devolver(item), child: const Text('Devolver'))
                    else if (widget.permiteDevolverItem)
                      const Text('Ya en control', style: TextStyle(fontSize: 11, color: AppColors.faint)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
