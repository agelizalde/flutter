import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../stock/domain/stock_models.dart' show ProductoDetalle, ProductoSimple;
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';

/// Atajo de "Nuevo ajuste": producto → cantidad → causa → listo. No pide
/// ubicación ni pasa por BORRADOR/CONFIRMADO — `POST /ajuste-stock/merma-rapida`
/// reparte la cantidad por FEFO entre las ubicaciones del almacén donde el
/// producto tiene stock y aplica de una (ver `ajuste_stock_merma_rapida` en
/// el backend).
class MermaRapidaScreen extends ConsumerStatefulWidget {
  const MermaRapidaScreen({super.key});

  @override
  ConsumerState<MermaRapidaScreen> createState() => _MermaRapidaScreenState();
}

class _MermaRapidaScreenState extends ConsumerState<MermaRapidaScreen> {
  final _searchController = TextEditingController();
  final _cantidadController = TextEditingController();
  Timer? _debounce;

  ProductoDetalle? _producto;
  bool _cargandoDetalle = false;
  bool _guardando = false;
  String _motivoCategoria = motivosMermaRapida.first.$1;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(ajusteBusquedaProductoProvider.notifier).state = value;
    });
  }

  Future<void> _seleccionarProducto(ProductoSimple p) async {
    setState(() => _cargandoDetalle = true);
    try {
      final (detalle, _) = await ref.read(ajusteStockRepositoryProvider).detalleProducto(p.idProducto);
      if (!mounted) return;
      setState(() => _producto = detalle);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cargandoDetalle = false);
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    setState(() => _cargandoDetalle = true);
    try {
      final producto = await ref.read(ajusteStockRepositoryProvider).buscarProductoPorCodigoBarra(codigo);
      if (!mounted) return;
      await _seleccionarProducto(producto);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDetalle = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  void _volverABuscar() {
    setState(() {
      _producto = null;
      _cantidadController.clear();
      _searchController.clear();
      _motivoCategoria = motivosMermaRapida.first.$1;
    });
    ref.read(ajusteBusquedaProductoProvider.notifier).state = '';
  }

  Future<void> _confirmar() async {
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá una cantidad válida (mayor a 0)')),
      );
      return;
    }

    final idAlmacen = ref.read(authControllerProvider).value?.idAlmacenSeleccionado;
    if (idAlmacen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un almacén seleccionado')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await ref.read(ajusteStockRepositoryProvider).mermaRapida(
        idProducto: _producto!.idProducto,
        idUnidadMedida: _producto!.idUnidadBase,
        idAlmacen: idAlmacen,
        cantidad: cantidad,
        motivoCategoria: _motivoCategoria,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock descontado: ${_producto!.nombre}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merma')),
      body: _cargandoDetalle
          ? const Center(child: CircularProgressIndicator())
          : _producto == null
              ? _BuscadorProducto(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSeleccionar: _seleccionarProducto,
                  onEscanear: _escanear,
                )
              : _FormularioMerma(
                  producto: _producto!,
                  cantidadController: _cantidadController,
                  motivoCategoria: _motivoCategoria,
                  guardando: _guardando,
                  onMotivoChanged: (v) => setState(() => _motivoCategoria = v),
                  onCancelar: _volverABuscar,
                  onConfirmar: _confirmar,
                ),
    );
  }
}

class _BuscadorProducto extends ConsumerWidget {
  const _BuscadorProducto({
    required this.controller,
    required this.onChanged,
    required this.onSeleccionar,
    required this.onEscanear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<ProductoSimple> onSeleccionar;
  final VoidCallback onEscanear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ajusteResultadosProductoProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Buscar producto por nombre o código...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                tooltip: 'Escanear código de barras',
                onPressed: onEscanear,
              ),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            data: (items) {
              if (controller.text.trim().isEmpty) {
                return const Center(child: Text('Escribí para buscar', style: TextStyle(color: AppColors.muted)));
              }
              if (items.isEmpty) {
                return const Center(child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = items[i];
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSeleccionar(p),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.inventory_2_outlined, color: AppColors.accentDark, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.nombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                                  ),
                                  Text(p.codigoInterno, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.faint),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FormularioMerma extends StatelessWidget {
  const _FormularioMerma({
    required this.producto,
    required this.cantidadController,
    required this.motivoCategoria,
    required this.guardando,
    required this.onMotivoChanged,
    required this.onCancelar,
    required this.onConfirmar,
  });

  final ProductoDetalle producto;
  final TextEditingController cantidadController;
  final String motivoCategoria;
  final bool guardando;
  final ValueChanged<String> onMotivoChanged;
  final VoidCallback onCancelar;
  final Future<void> Function() onConfirmar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(producto.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(producto.codigoInterno, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 20),
        TextField(
          controller: cantidadController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(labelText: 'Cantidad (${producto.unidadSimbolo})'),
        ),
        const SizedBox(height: 20),
        const Text('Causa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sub)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: motivosMermaRapida
              .map((m) => ButtonSegment(value: m.$1, label: Text(m.$2)))
              .toList(),
          selected: {motivoCategoria},
          onSelectionChanged: (s) => onMotivoChanged(s.first),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: guardando ? null : onCancelar,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: guardando ? null : () => onConfirmar(),
                child: guardando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Descontar stock'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
