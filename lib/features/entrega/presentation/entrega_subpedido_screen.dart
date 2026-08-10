import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/entrega_providers.dart';
import '../domain/entrega_models.dart';

int _nextLocalId = 0;

EntregaItem? _buscarItem(List<EntregaItem> items, int? id) {
  if (id == null) return null;
  for (final it in items) {
    if (it.idPedidoSubpedidoItem == id) return it;
  }
  return null;
}

class _RechazoRow {
  _RechazoRow() : localId = _nextLocalId++;
  final int localId;
  int? idItem;
  final cantidad = TextEditingController();
  final observacion = TextEditingController();
}

class _FaltanteRow {
  _FaltanteRow() : localId = _nextLocalId++;
  final int localId;
  final producto = TextEditingController();
  final cantidad = TextEditingController();
  final observacion = TextEditingController();
}

/// Confirmación de entrega de un subpedido `EN_ENTREGA` desde el celular del
/// chofer — mismo contrato que `EntregaConfirmarSheet.jsx` (web): rechazos
/// (ítem real del pedido + cantidad + observación), faltantes (producto
/// libre + cantidad + observación), observación general y al menos 1 foto
/// de la remisión. El backend libera los cajones y dispara la aprobación
/// gerencial (Firmas) al confirmar — ver `subpedido_entrega_service.py`.
/// Solo llega acá quien está asignado como responsable de esta entrega — el
/// backend (`confirmar_entrega`) lo vuelve a validar, esto es solo la UI.
class EntregaSubpedidoScreen extends ConsumerStatefulWidget {
  const EntregaSubpedidoScreen({super.key, required this.idPedidoSubpedido});

  final int idPedidoSubpedido;

  @override
  ConsumerState<EntregaSubpedidoScreen> createState() => _EntregaSubpedidoScreenState();
}

class _EntregaSubpedidoScreenState extends ConsumerState<EntregaSubpedidoScreen> {
  final _rechazos = <_RechazoRow>[];
  final _faltantes = <_FaltanteRow>[];
  final _observacionGeneral = TextEditingController();
  final _fotos = <XFile>[];

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _observacionGeneral.dispose();
    for (final r in _rechazos) {
      r.cantidad.dispose();
      r.observacion.dispose();
    }
    for (final f in _faltantes) {
      f.producto.dispose();
      f.cantidad.dispose();
      f.observacion.dispose();
    }
    super.dispose();
  }

  /// Además de completo, cada rechazo no puede superar lo realmente
  /// entregado de ESE ítem (mismo tope que valida el backend en
  /// `confirmar_entrega` — acá se repite solo para dar feedback inmediato,
  /// el backend es la fuente de verdad).
  bool _rechazosValidos(List<EntregaItem> items) {
    return _rechazos.every((r) {
      if (r.idItem == null) return false;
      final cantidad = double.tryParse(r.cantidad.text) ?? 0;
      if (cantidad <= 0) return false;
      final item = _buscarItem(items, r.idItem);
      return item != null && cantidad <= item.cantidad;
    });
  }

  bool get _faltantesValidos =>
      _faltantes.every((f) => f.producto.text.trim().isNotEmpty && (double.tryParse(f.cantidad.text) ?? 0) > 0);

  bool _puedeConfirmar(List<EntregaItem> items) =>
      _fotos.isNotEmpty && _rechazosValidos(items) && _faltantesValidos && !_guardando;

  Future<void> _tomarFoto() async {
    final foto = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (foto == null) return;
    setState(() => _fotos.add(foto));
  }

  Future<void> _elegirDeGaleria() async {
    final fotos = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (fotos.isEmpty) return;
    setState(() => _fotos.addAll(fotos));
  }

  Future<void> _confirmar(int expectedVersion) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(entregaRepositoryProvider).confirmarEntrega(
        widget.idPedidoSubpedido,
        expectedVersion: expectedVersion,
        observacion: _observacionGeneral.text.trim().isEmpty ? null : _observacionGeneral.text.trim(),
        rechazos: _rechazos
            .map((r) => {
                  'id_pedido_subpedido_item': r.idItem,
                  'cantidad': double.parse(r.cantidad.text),
                  'observacion': r.observacion.text.trim().isEmpty ? null : r.observacion.text.trim(),
                })
            .toList(),
        faltantes: _faltantes
            .map((f) => {
                  'producto_libre': f.producto.text.trim(),
                  'cantidad': double.parse(f.cantidad.text),
                  'observacion': f.observacion.text.trim().isEmpty ? null : f.observacion.text.trim(),
                })
            .toList(),
        fotos: _fotos,
      );
      if (!mounted) return;
      ref.invalidate(subpedidosEnEntregaProvider);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(entregaItemsProvider(widget.idPedidoSubpedido));
    final listaAsync = ref.watch(subpedidosEnEntregaProvider);

    SubpedidoEnEntrega? subpedido;
    for (final s in listaAsync.value ?? const <SubpedidoEnEntrega>[]) {
      if (s.idPedidoSubpedido == widget.idPedidoSubpedido) {
        subpedido = s;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar entrega')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
        data: (items) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (subpedido != null) ...[
                      Text(
                        subpedido.tituloDisplay,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                      ),
                      if (subpedido.codigoPedido != null) ...[
                        const SizedBox(height: 4),
                        Text(subpedido.codigoPedido!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ],
                      const SizedBox(height: 16),
                    ],
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
                        child: Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _SeccionRechazos(
                      items: items,
                      filas: _rechazos,
                      onAdd: () => setState(() => _rechazos.add(_RechazoRow())),
                      onRemove: (fila) => setState(() {
                        fila.cantidad.dispose();
                        fila.observacion.dispose();
                        _rechazos.remove(fila);
                      }),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _SeccionFaltantes(
                      filas: _faltantes,
                      onAdd: () => setState(() => _faltantes.add(_FaltanteRow())),
                      onRemove: (fila) => setState(() {
                        fila.producto.dispose();
                        fila.cantidad.dispose();
                        fila.observacion.dispose();
                        _faltantes.remove(fila);
                      }),
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'OBSERVACIÓN GENERAL (OPCIONAL)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _observacionGeneral,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Algo que no esté en la lista de ítems de arriba…'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'FOTOS DE LA REMISIÓN *',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _guardando ? null : _tomarFoto,
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Tomar foto'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _guardando ? null : _elegirDeGaleria,
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Galería'),
                          ),
                        ),
                      ],
                    ),
                    if (_fotos.isEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Hace falta al menos 1 foto para confirmar.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < _fotos.length; i++)
                            _FotoThumb(
                              file: _fotos[i],
                              onRemove: _guardando ? null : () => setState(() => _fotos.removeAt(i)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  onPressed: (!_puedeConfirmar(items) || subpedido == null)
                      ? null
                      : () => _confirmar(subpedido!.rowVersion),
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirmar entrega'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// `Image.file` no funciona en Flutter Web (no hay filesystem real) — se lee
/// el `XFile` como bytes y se muestra con `Image.memory`, que funciona igual
/// en mobile y en web.
class _FotoThumb extends StatelessWidget {
  const _FotoThumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 80,
            height: 80,
            child: FutureBuilder<Uint8List>(
              future: file.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const ColoredBox(color: AppColors.soft);
                }
                return Image.memory(snapshot.data!, width: 80, height: 80, fit: BoxFit.cover);
              },
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: AppColors.erTx, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _SeccionRechazos extends StatelessWidget {
  const _SeccionRechazos({
    required this.items,
    required this.filas,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<EntregaItem> items;
  final List<_RechazoRow> filas;
  final VoidCallback onAdd;
  final void Function(_RechazoRow) onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Rechazos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
              ),
              TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Agregar')),
            ],
          ),
          if (filas.isEmpty)
            const Text('Sin rechazos para este subpedido.', style: TextStyle(fontSize: 13, color: AppColors.muted))
          else
            for (final fila in filas) ...[
              const SizedBox(height: 10),
              _ItemPickerField(
                items: items,
                idItemSeleccionado: fila.idItem,
                onSeleccionar: (it) {
                  fila.idItem = it.idPedidoSubpedidoItem;
                  onChanged();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fila.cantidad,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Cantidad'),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: fila.observacion,
                      decoration: const InputDecoration(hintText: 'Observación (opcional)'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemove(fila),
                    icon: const Icon(Icons.delete_outline, color: AppColors.erTx),
                  ),
                ],
              ),
              Builder(builder: (context) {
                final item = _buscarItem(items, fila.idItem);
                final cantidad = double.tryParse(fila.cantidad.text);
                if (item == null || cantidad == null || cantidad <= item.cantidad) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Supera lo entregado (${item.cantidad.toStringAsFixed(0)} ${item.unidadSimbolo ?? ""})',
                    style: const TextStyle(fontSize: 12, color: AppColors.erTx, fontWeight: FontWeight.w600),
                  ),
                );
              }),
            ],
        ],
      ),
    );
  }
}

/// Campo tappable que abre un buscador (`_ItemPickerSheet`) en vez de un
/// dropdown inline — un subpedido puede tener cientos de ítems, un
/// `DropdownButtonFormField` con esa cantidad de opciones es inusable en el
/// celular (lista larga sin filtro).
class _ItemPickerField extends StatelessWidget {
  const _ItemPickerField({required this.items, required this.idItemSeleccionado, required this.onSeleccionar});

  final List<EntregaItem> items;
  final int? idItemSeleccionado;
  final void Function(EntregaItem) onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final seleccionado = _buscarItem(items, idItemSeleccionado);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final elegido = await showModalBottomSheet<EntregaItem>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _ItemPickerSheet(items: items),
        );
        if (elegido != null) onSeleccionar(elegido);
      },
      child: InputDecorator(
        decoration: const InputDecoration(hintText: 'Elegir ítem del pedido'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                seleccionado == null
                    ? ''
                    : '${seleccionado.productoNombre ?? "—"} (entregado: ${seleccionado.cantidad.toStringAsFixed(0)} ${seleccionado.unidadSimbolo ?? ""})',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text),
              ),
            ),
            const Icon(Icons.search, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Buscador de ítems del pedido — filtra por nombre de producto a medida
/// que se escribe.
class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({required this.items});

  final List<EntregaItem> items;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final _query = TextEditingController();
  List<EntregaItem> _filtrados = const [];

  @override
  void initState() {
    super.initState();
    _filtrados = widget.items;
    _query.addListener(_filtrar);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filtrar() {
    final q = _query.text.trim().toLowerCase();
    setState(() {
      _filtrados = q.isEmpty
          ? widget.items
          : widget.items.where((it) => (it.productoNombre ?? '').toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Elegir ítem del pedido', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar producto…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _filtrados.isEmpty
                    ? const Center(
                        child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtrados.length,
                        itemBuilder: (context, i) {
                          final it = _filtrados[i];
                          return ListTile(
                            title: Text(it.productoNombre ?? '—'),
                            subtitle: Text('Entregado: ${it.cantidad.toStringAsFixed(0)} ${it.unidadSimbolo ?? ""}'),
                            onTap: () => Navigator.of(context).pop(it),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeccionFaltantes extends StatelessWidget {
  const _SeccionFaltantes({required this.filas, required this.onAdd, required this.onRemove, required this.onChanged});

  final List<_FaltanteRow> filas;
  final VoidCallback onAdd;
  final void Function(_FaltanteRow) onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Faltantes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
              ),
              TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Agregar')),
            ],
          ),
          if (filas.isEmpty)
            const Text('Sin faltantes para este subpedido.', style: TextStyle(fontSize: 13, color: AppColors.muted))
          else
            for (final fila in filas) ...[
              const SizedBox(height: 10),
              TextField(
                controller: fila.producto,
                decoration: const InputDecoration(hintText: 'Nombre del producto faltante'),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: fila.cantidad,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Cantidad'),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: fila.observacion,
                      decoration: const InputDecoration(hintText: 'Observación (opcional)'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => onRemove(fila),
                    icon: const Icon(Icons.delete_outline, color: AppColors.erTx),
                  ),
                ],
              ),
            ],
        ],
      ),
    );
  }
}
