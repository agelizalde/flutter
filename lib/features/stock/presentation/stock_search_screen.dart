import '../../../core/errors/app_exception.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../application/stock_providers.dart';
import '../domain/stock_models.dart';

class StockSearchScreen extends ConsumerStatefulWidget {
  const StockSearchScreen({super.key});

  @override
  ConsumerState<StockSearchScreen> createState() => _StockSearchScreenState();
}

class _StockSearchScreenState extends ConsumerState<StockSearchScreen> {
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
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(stockSearchQueryProvider.notifier).state = value;
    });
  }

  void _onModeChanged(StockSearchMode mode) {
    ref.read(stockSearchModeProvider.notifier).state = mode;
    _controller.clear();
    _debounce?.cancel();
    ref.read(stockSearchQueryProvider.notifier).state = '';
  }

  String _hintPorModo(StockSearchMode modo) {
    switch (modo) {
      case StockSearchMode.nombre:
        return 'Buscar producto por nombre o código...';
      case StockSearchMode.ubicacion:
        return 'Buscar ubicación...';
      case StockSearchMode.proveedor:
        return 'Buscar proveedor...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final modo = ref.watch(stockSearchModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<StockSearchMode>(
                  segments: const [
                    ButtonSegment(
                      value: StockSearchMode.nombre,
                      label: Text('Producto'),
                    ),
                    ButtonSegment(
                      value: StockSearchMode.ubicacion,
                      label: Text('Ubicación'),
                    ),
                    ButtonSegment(
                      value: StockSearchMode.proveedor,
                      label: Text('Proveedor'),
                    ),
                  ],
                  selected: {modo},
                  onSelectionChanged: (s) => _onModeChanged(s.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: _hintPorModo(modo),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _controller.clear();
                              _debounce?.cancel();
                              ref
                                      .read(stockSearchQueryProvider.notifier)
                                      .state =
                                  '';
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _Resultados(modo: modo)),
        ],
      ),
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados({required this.modo});

  final StockSearchMode modo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(stockSearchQueryProvider);

    if (query.trim().isEmpty) {
      return const _EstadoVacio(
        icono: Icons.search,
        mensaje: 'Escribí para buscar',
      );
    }

    switch (modo) {
      case StockSearchMode.nombre:
        final async = ref.watch(productoResultsProvider);
        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _EstadoError(mensaje: describeError(e)),
          data: (items) {
            if (items.isEmpty) {
              return const _EstadoVacio(
                icono: Icons.inventory_2_outlined,
                mensaje: 'Sin resultados',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ProductoTile(producto: items[i]),
            );
          },
        );
      case StockSearchMode.ubicacion:
        final async = ref.watch(ubicacionResultsProvider);
        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _EstadoError(mensaje: describeError(e)),
          data: (items) {
            if (items.isEmpty) {
              return const _EstadoVacio(
                icono: Icons.location_on_outlined,
                mensaje: 'Sin resultados',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _UbicacionTile(ubicacion: items[i]),
            );
          },
        );
      case StockSearchMode.proveedor:
        final async = ref.watch(proveedorResultsProvider);
        return async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _EstadoError(mensaje: describeError(e)),
          data: (items) {
            if (items.isEmpty) {
              return const _EstadoVacio(
                icono: Icons.local_shipping_outlined,
                mensaje: 'Sin resultados',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ProveedorTile(proveedor: items[i]),
            );
          },
        );
    }
  }
}

class _ProductoTile extends StatelessWidget {
  const _ProductoTile({required this.producto});

  final ProductoConStock producto;

  @override
  Widget build(BuildContext context) {
    return _ResultCard(
      onTap: () => context.push('/stock/producto/${producto.idProducto}'),
      leadingIcon: Icons.inventory_2_outlined,
      leadingColor: const Color(0xFF2563EB),
      titulo: producto.nombre,
      subtitulo: producto.codigoInterno,
      trailing: _BadgeCantidad(
        valor: producto.stockDisponible,
        unidad: producto.unidadSimbolo,
        etiqueta: 'disponible',
      ),
    );
  }
}

class _UbicacionTile extends StatelessWidget {
  const _UbicacionTile({required this.ubicacion});

  final UbicacionStock ubicacion;

  @override
  Widget build(BuildContext context) {
    return _ResultCard(
      onTap: () => context.push(
        '/stock/ubicacion/${ubicacion.idUbicacion}',
        extra: ubicacion.ubicacionNombre,
      ),
      leadingIcon: Icons.location_on_outlined,
      leadingColor: const Color(0xFF7C3AED),
      titulo: ubicacion.ubicacionNombre,
      subtitulo: '${ubicacion.almacenNombre} · ${ubicacion.ubicacionCodigo}',
      trailing: _Badge(texto: '${ubicacion.cantidadProductos} prod.'),
    );
  }
}

class _ProveedorTile extends StatelessWidget {
  const _ProveedorTile({required this.proveedor});

  final ProveedorSimple proveedor;

  @override
  Widget build(BuildContext context) {
    return _ResultCard(
      onTap: () => context.push(
        '/stock/proveedor/${proveedor.idProveedor}',
        extra: proveedor.nombreComercial ?? proveedor.razonSocial,
      ),
      leadingIcon: Icons.local_shipping_outlined,
      leadingColor: const Color(0xFFDC2626),
      titulo: proveedor.nombreComercial ?? proveedor.razonSocial,
      subtitulo: proveedor.codigoProveedor,
      trailing: null,
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.onTap,
    required this.leadingIcon,
    required this.leadingColor,
    required this.titulo,
    required this.subtitulo,
    required this.trailing,
  });

  final VoidCallback onTap;
  final IconData leadingIcon;
  final Color leadingColor;
  final String titulo;
  final String subtitulo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: leadingColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(leadingIcon, color: leadingColor, size: 22),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.sub,
        ),
      ),
    );
  }
}

class _BadgeCantidad extends StatelessWidget {
  const _BadgeCantidad({
    required this.valor,
    required this.unidad,
    required this.etiqueta,
  });

  final double valor;
  final String unidad;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final critico = valor <= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${valor.toStringAsFixed(valor.truncateToDouble() == valor ? 0 : 2)} $unidad',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: critico ? AppColors.erTx : AppColors.text,
          ),
        ),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 40, color: AppColors.faint),
          const SizedBox(height: 12),
          Text(mensaje, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _EstadoError extends StatelessWidget {
  const _EstadoError({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.erTx),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.erTx),
            ),
          ],
        ),
      ),
    );
  }
}
