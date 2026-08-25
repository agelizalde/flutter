import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';

/// Layout común a las 5 pestañas del Creador: buscador + botón "+" arriba,
/// lista con pull-to-refresh abajo. Cada pestaña solo aporta el
/// [AsyncValue] ya resuelto (su propio provider) y cómo pintar cada fila.
class CreadorTabList<T> extends StatefulWidget {
  const CreadorTabList({
    super.key,
    required this.value,
    required this.hintBuscar,
    required this.onBuscar,
    required this.onRefresh,
    required this.onAgregar,
    required this.itemBuilder,
    required this.textoVacio,
    this.tooltipAgregar = 'Nuevo',
  });

  final AsyncValue<List<T>> value;
  final String hintBuscar;
  final ValueChanged<String> onBuscar;
  final VoidCallback onRefresh;

  /// `null` oculta el botón "+" — la pestaña no tiene permiso de crear.
  final VoidCallback? onAgregar;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String textoVacio;
  final String tooltipAgregar;

  @override
  State<CreadorTabList<T>> createState() => _CreadorTabListState<T>();
}

class _CreadorTabListState<T> extends State<CreadorTabList<T>> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => widget.onBuscar(value.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: widget.hintBuscar,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              if (widget.onAgregar != null) ...[
                const SizedBox(width: 10),
                Material(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: widget.onAgregar,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            child: widget.value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        describeError(e),
                        style: const TextStyle(color: AppColors.erTx),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 80),
                      const Icon(
                        Icons.inbox_outlined,
                        size: 40,
                        color: AppColors.faint,
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          widget.textoVacio,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      widget.itemBuilder(context, items[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Fila estándar de las listas del Creador — título + subtítulo opcional +
/// chip "Inactivo" si corresponde.
class CreadorTile extends StatelessWidget {
  const CreadorTile({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.activo,
    required this.onTap,
  });

  final String titulo;
  final String? subtitulo;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    if (subtitulo != null && subtitulo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitulo!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!activo) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.erBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Inactivo',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.erTx,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
