import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../errors/app_exception.dart';

/// Bottom sheet de selección única detrás de cada [PickerField] — nació en
/// el módulo Creador (marca, categoría, unidad, IVA, proveedor, zona,
/// ubicación padre) y hoy también lo usa Pedidos (cliente, sucursal, lugar
/// de entrega, vehículo). `cargar` trae las opciones — si viene `q` no nulo
/// es porque el caller soporta búsqueda server-side (ej. proveedores); si
/// el caller ignora `q` y siempre devuelve todo, el filtro queda igual a
/// cargo del `where` local de abajo.
Future<T?> showSelectorSheet<T>(
  BuildContext context, {
  required String titulo,
  required Future<List<T>> Function(String query) cargar,
  required String Function(T) etiqueta,
  String? Function(T)? subtitulo,
  T? seleccionado,
  bool Function(T)? esIgual,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SelectorSheetBody<T>(
      titulo: titulo,
      cargar: cargar,
      etiqueta: etiqueta,
      subtitulo: subtitulo,
      seleccionado: seleccionado,
      esIgual: esIgual,
    ),
  );
}

class _SelectorSheetBody<T> extends StatefulWidget {
  const _SelectorSheetBody({
    required this.titulo,
    required this.cargar,
    required this.etiqueta,
    required this.subtitulo,
    required this.seleccionado,
    required this.esIgual,
  });

  final String titulo;
  final Future<List<T>> Function(String query) cargar;
  final String Function(T) etiqueta;
  final String? Function(T)? subtitulo;
  final T? seleccionado;
  final bool Function(T)? esIgual;

  @override
  State<_SelectorSheetBody<T>> createState() => _SelectorSheetBodyState<T>();
}

class _SelectorSheetBodyState<T> extends State<_SelectorSheetBody<T>> {
  final _controller = TextEditingController();
  Timer? _debounce;
  Future<List<T>>? _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cargar('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _future = widget.cargar(value.trim()));
    });
  }

  bool _esSeleccionado(T item) {
    if (widget.seleccionado == null) return false;
    if (widget.esIgual != null) return widget.esIgual!(item);
    return item == widget.seleccionado;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Text(
                  widget.titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: const InputDecoration(
                    hintText: 'Buscar...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<T>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            describeError(snapshot.error!),
                            style: const TextStyle(color: AppColors.erTx),
                          ),
                        ),
                      );
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final sub = widget.subtitulo?.call(item);
                        final activo = _esSeleccionado(item);
                        return ListTile(
                          title: Text(
                            widget.etiqueta(item),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: sub != null && sub.isNotEmpty
                              ? Text(sub)
                              : null,
                          trailing: activo
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.accent,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
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
