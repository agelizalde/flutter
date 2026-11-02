import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../stock/domain/stock_models.dart' show ProductoSimple;
import '../application/ajuste_stock_providers.dart';

/// Paso "elegir producto" compartido por Control por producto y Mermar
/// producto: buscador por nombre/código + escaneo de código de barras.
/// Arranca con la búsqueda vacía (resetea `ajusteBusquedaProductoProvider`,
/// que es global y puede venir con texto de otra pantalla).
class BuscadorProductoAjuste extends ConsumerStatefulWidget {
  const BuscadorProductoAjuste({super.key, required this.onSeleccionar, this.ayuda});

  final ValueChanged<ProductoSimple> onSeleccionar;

  /// Texto corto arriba del buscador explicando el paso.
  final String? ayuda;

  @override
  ConsumerState<BuscadorProductoAjuste> createState() => _BuscadorProductoAjusteState();
}

class _BuscadorProductoAjusteState extends ConsumerState<BuscadorProductoAjuste> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _resolviendoEscaneo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(ajusteBusquedaProductoProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(ajusteBusquedaProductoProvider.notifier).state = value;
    });
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    setState(() => _resolviendoEscaneo = true);
    try {
      final producto = await ref.read(ajusteStockRepositoryProvider).buscarProductoPorCodigoBarra(codigo);
      if (!mounted) return;
      widget.onSeleccionar(producto);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _resolviendoEscaneo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolviendoEscaneo) return const Center(child: CircularProgressIndicator());

    final async = ref.watch(ajusteResultadosProductoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.ayuda != null) ...[
                Text(widget.ayuda!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar producto por nombre o código...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                    tooltip: 'Escanear código de barras',
                    onPressed: _escanear,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            data: (items) {
              if (_controller.text.trim().isEmpty) {
                return const Center(child: Text('Escribí o escaneá para buscar', style: TextStyle(color: AppColors.muted)));
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
                      onTap: () => widget.onSeleccionar(p),
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

/// Encabezado del producto elegido, con botón para volver a buscar otro.
class ProductoElegidoHeader extends StatelessWidget {
  const ProductoElegidoHeader({super.key, required this.nombre, required this.codigo, required this.onCambiar});

  final String nombre;
  final String codigo;
  final VoidCallback? onCambiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(onPressed: onCambiar, icon: const Icon(Icons.arrow_back), tooltip: 'Elegir otro producto'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                ),
                if (codigo.isNotEmpty) Text(codigo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
