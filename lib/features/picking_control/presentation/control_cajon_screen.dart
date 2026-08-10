import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/picking_control_providers.dart';
import '../domain/picking_control_models.dart';
import 'widgets/item_control_tile.dart';

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
      final r = await ref.read(pickingControlRepositoryProvider).revisarItem(
        idPickingControl: widget.idPickingControl,
        idPickingControlItem: item.idPickingControlItem!,
        cantidadControlada: item.cantidadPickeada,
        resultado: 'APROBADO',
      );
      _actualizarLocal(index, resultado: 'APROBADO', cantidad: r.cantidadControlada);
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
    final resultado = await showModalBottomSheet<_RevisionResultado>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RechazarItemSheet(item: item),
    );
    if (resultado == null || !mounted) return;

    setState(() {
      _procesando = index;
      _error = null;
    });
    try {
      final r = await ref.read(pickingControlRepositoryProvider).revisarItem(
        idPickingControl: widget.idPickingControl,
        idPickingControlItem: item.idPickingControlItem!,
        cantidadControlada: resultado.cantidad,
        resultado: 'RECHAZADO',
        motivosRechazo: resultado.motivo,
        observacion: resultado.observacion,
      );
      _actualizarLocal(
        index,
        resultado: 'RECHAZADO',
        cantidad: r.cantidadControlada,
        motivos: resultado.motivo,
        observacion: resultado.observacion,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  void _actualizarLocal(
    int index, {
    required String resultado,
    required double cantidad,
    String? motivos,
    String? observacion,
  }) {
    final item = _items[index];
    setState(() {
      _items[index] = ItemControl(
        idPickingItem: item.idPickingItem,
        idStockReservaDetalle: item.idStockReservaDetalle,
        idPedidoSubpedidoItem: item.idPedidoSubpedidoItem,
        idProducto: item.idProducto,
        productoNombre: item.productoNombre,
        productoCodigo: item.productoCodigo,
        productoSku: item.productoSku,
        idUnidadMedida: item.idUnidadMedida,
        unidadNombre: item.unidadNombre,
        unidadSimbolo: item.unidadSimbolo,
        cantidadReservada: item.cantidadReservada,
        cantidadPickeada: item.cantidadPickeada,
        idContenedor: item.idContenedor,
        contenedorIdentificador: item.contenedorIdentificador,
        contenedorCodigoBarras: item.contenedorCodigoBarras,
        idLote: item.idLote,
        loteInterno: item.loteInterno,
        loteProveedor: item.loteProveedor,
        fechaVencimiento: item.fechaVencimiento,
        idZona: item.idZona,
        zonaNombre: item.zonaNombre,
        zonaCodigo: item.zonaCodigo,
        zonaOrden: item.zonaOrden,
        idUbicacion: item.idUbicacion,
        ubicacionCodigo: item.ubicacionCodigo,
        ubicacionNombre: item.ubicacionNombre,
        pickerNombre: item.pickerNombre,
        pickeadoEn: item.pickeadoEn,
        idPickingControlItem: item.idPickingControlItem,
        cantidadControlada: cantidad,
        resultadoControl: resultado,
        motivosRechazo: motivos,
        observacionControl: observacion,
      );
    });
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

class _RevisionResultado {
  _RevisionResultado({required this.cantidad, required this.motivo, this.observacion});

  final double cantidad;
  final String motivo;
  final String? observacion;
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

class _RechazarItemSheet extends StatefulWidget {
  const _RechazarItemSheet({required this.item});

  final ItemControl item;

  @override
  State<_RechazarItemSheet> createState() => _RechazarItemSheetState();
}

/// 'elegir' (pantalla inicial con las 2 acciones) | 'rechazar' | 'modificar'
enum _ModoSheet { elegir, rechazar, modificar }

class _RechazarItemSheetState extends State<_RechazarItemSheet> {
  _ModoSheet _modo = _ModoSheet.elegir;
  String? _motivoSeleccionado;
  late final _cantidadController = TextEditingController(
    text: _fmtCantidad(widget.item.cantidadPickeada),
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
        _RevisionResultado(
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
      _RevisionResultado(
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
                'Pickeado: ${_fmtCantidad(widget.item.cantidadPickeada)} ${widget.item.unidadSimbolo}',
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

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
