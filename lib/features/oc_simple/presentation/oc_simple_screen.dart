import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../../stock/domain/stock_models.dart' show ProveedorSimple;
import '../application/oc_simple_providers.dart';
import '../domain/oc_simple_models.dart';

/// "OC simple": carrito de compra rápida (proveedor + productos habilitados
/// con cantidad y precio) que genera una OC ya confirmada y enviada a firma
/// (`POST /compras/oc/simple`, ver `oc_crear_simple.py`) — queda `APROBADO`
/// al instante si ninguna regla de Firmas aplica al monto, o
/// `PENDIENTE_FIRMA` si aplica alguna. No hay pantalla de detalle de OC acá
/// (a diferencia de la web): al confirmar solo se informa el código y el
/// estado resultante.
class OcSimpleScreen extends ConsumerStatefulWidget {
  const OcSimpleScreen({super.key});

  @override
  ConsumerState<OcSimpleScreen> createState() => _OcSimpleScreenState();
}

class _OcSimpleScreenState extends ConsumerState<OcSimpleScreen> {
  final _proveedorSearchController = TextEditingController();
  final _productoSearchController = TextEditingController();
  Timer? _debounceProveedor;
  Timer? _debounceProducto;

  ProveedorSimple? _proveedor;
  final List<OcSimpleCartItem> _carrito = [];
  bool _guardando = false;

  @override
  void dispose() {
    _debounceProveedor?.cancel();
    _debounceProducto?.cancel();
    _proveedorSearchController.dispose();
    _productoSearchController.dispose();
    super.dispose();
  }

  void _onBuscarProveedor(String value) {
    _debounceProveedor?.cancel();
    _debounceProveedor = Timer(const Duration(milliseconds: 400), () {
      ref.read(ocSimpleBusquedaProveedorProvider.notifier).state = value;
    });
  }

  void _onBuscarProducto(String value) {
    _debounceProducto?.cancel();
    _debounceProducto = Timer(const Duration(milliseconds: 400), () {
      ref.read(ocSimpleBusquedaProductoProvider.notifier).state = value;
    });
  }

  void _elegirProveedor(ProveedorSimple p) {
    setState(() => _proveedor = p);
  }

  void _cambiarProveedor() {
    setState(() => _proveedor = null);
    _proveedorSearchController.clear();
    ref.read(ocSimpleBusquedaProveedorProvider.notifier).state = '';
  }

  void _agregarProducto(ProductoCompraSimple p) {
    setState(() {
      final idx = _carrito.indexWhere((it) => it.producto.idProducto == p.idProducto);
      if (idx >= 0) {
        _carrito[idx] = _carrito[idx].copyWith(cantidad: _carrito[idx].cantidad + 1);
      } else {
        _carrito.add(
          OcSimpleCartItem(
            producto: p,
            cantidad: 1,
            precioUnitario: p.precioMaximoCompraSimple ?? 0,
          ),
        );
      }
    });
    _productoSearchController.clear();
    ref.read(ocSimpleBusquedaProductoProvider.notifier).state = '';
  }

  void _actualizarItem(int idProducto, {double? cantidad, double? precioUnitario}) {
    setState(() {
      final idx = _carrito.indexWhere((it) => it.producto.idProducto == idProducto);
      if (idx < 0) return;
      _carrito[idx] = _carrito[idx].copyWith(cantidad: cantidad, precioUnitario: precioUnitario);
    });
  }

  void _quitarItem(int idProducto) {
    setState(() => _carrito.removeWhere((it) => it.producto.idProducto == idProducto));
  }

  bool get _puedeGenerar =>
      _proveedor != null && _carrito.isNotEmpty && _carrito.every((it) => it.error == null);

  Future<void> _generarOc() async {
    setState(() => _guardando = true);
    try {
      final resultado = await ref.read(ocSimpleRepositoryProvider).crear(
        idProveedor: _proveedor!.idProveedor,
        items: _carrito,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('OC generada'),
          content: Text('${resultado.codigo} quedó APROBADA automáticamente.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario != null && !usuario.tienePermiso('oc.crear_simple')) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver al menú principal',
            onPressed: () => context.go('/'),
          ),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tenés permiso para crear OC simple.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al menú principal',
          onPressed: () => context.go('/'),
        ),
        title: const Text('OC simple'),
      ),
      body: Column(
        children: [
          _PasoIndicador(pasoActual: _proveedor == null ? 1 : 2),
          Expanded(
            child: _proveedor == null
                ? _BuscadorProveedor(
                    controller: _proveedorSearchController,
                    onChanged: _onBuscarProveedor,
                    onSeleccionar: _elegirProveedor,
                  )
                : _CarritoOcSimple(
                    proveedor: _proveedor!,
                    carrito: _carrito,
                    productoSearchController: _productoSearchController,
                    guardando: _guardando,
                    puedeGenerar: _puedeGenerar,
                    onCambiarProveedor: _cambiarProveedor,
                    onBuscarProducto: _onBuscarProducto,
                    onAgregarProducto: _agregarProducto,
                    onActualizarItem: _actualizarItem,
                    onQuitarItem: _quitarItem,
                    onGenerar: _generarOc,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Indicador de los 2 pasos del flujo: elegir proveedor y después elegir
/// productos. Puramente visual — el paso activo lo determina
/// `_OcSimpleScreenState` según si ya hay proveedor elegido (`_proveedor`),
/// no hay navegación propia acá.
class _PasoIndicador extends StatelessWidget {
  const _PasoIndicador({required this.pasoActual});

  /// 1 = eligiendo proveedor, 2 = eligiendo productos.
  final int pasoActual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: _Paso(numero: 1, titulo: 'Proveedor', activo: pasoActual == 1, completado: pasoActual > 1),
          ),
          Container(
            width: 24,
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: pasoActual > 1 ? AppColors.accent : AppColors.border,
          ),
          Expanded(
            child: _Paso(numero: 2, titulo: 'Productos', activo: pasoActual == 2, completado: false),
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.numero,
    required this.titulo,
    required this.activo,
    required this.completado,
  });

  final int numero;
  final String titulo;
  final bool activo;
  final bool completado;

  @override
  Widget build(BuildContext context) {
    final destacado = activo || completado;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: destacado ? AppColors.accent : AppColors.faint.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: completado
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$numero',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: destacado ? Colors.white : AppColors.muted,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
            color: destacado ? AppColors.text : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _BuscadorProveedor extends ConsumerWidget {
  const _BuscadorProveedor({
    required this.controller,
    required this.onChanged,
    required this.onSeleccionar,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<ProveedorSimple> onSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocSimpleResultadosProveedorProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar proveedor por razón social o RUC...',
              prefixIcon: Icon(Icons.search),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.razonSocial,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                                  ),
                                  Text(
                                    p.codigoProveedor,
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
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

class _CarritoOcSimple extends ConsumerWidget {
  const _CarritoOcSimple({
    required this.proveedor,
    required this.carrito,
    required this.productoSearchController,
    required this.guardando,
    required this.puedeGenerar,
    required this.onCambiarProveedor,
    required this.onBuscarProducto,
    required this.onAgregarProducto,
    required this.onActualizarItem,
    required this.onQuitarItem,
    required this.onGenerar,
  });

  final ProveedorSimple proveedor;
  final List<OcSimpleCartItem> carrito;
  final TextEditingController productoSearchController;
  final bool guardando;
  final bool puedeGenerar;
  final VoidCallback onCambiarProveedor;
  final ValueChanged<String> onBuscarProducto;
  final ValueChanged<ProductoCompraSimple> onAgregarProducto;
  final void Function(int idProducto, {double? cantidad, double? precioUnitario}) onActualizarItem;
  final ValueChanged<int> onQuitarItem;
  final Future<void> Function() onGenerar;

  double get _total => carrito.fold(0, (acc, it) => acc + it.subtotal);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultadosProducto = ref.watch(ocSimpleResultadosProductoProvider);
    final qProducto = productoSearchController.text.trim();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proveedor.razonSocial,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                    ),
                    Text(
                      proveedor.codigoProveedor,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onCambiarProveedor, child: const Text('Cambiar')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: productoSearchController,
          onChanged: onBuscarProducto,
          decoration: const InputDecoration(
            hintText: 'Buscar producto por nombre o código...',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (qProducto.isNotEmpty)
          resultadosProducto.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: items
                      .map(
                        (p) => Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => onAgregarProducto(p),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
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
                                        Text(
                                          p.precioMaximoCompraSimple != null
                                              ? '${p.codigoInterno} · máx. ${formatGs(p.precioMaximoCompraSimple!)}'
                                              : p.codigoInterno,
                                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.add_circle_outline, color: AppColors.accent),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList()
                      .expand((w) => [w, const SizedBox(height: 8)])
                      .toList(),
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        Text(
          'CARRITO',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        if (carrito.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Todavía no agregaste productos', style: TextStyle(color: AppColors.muted)),
            ),
          )
        else
          ...carrito.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CarritoItemTile(
                item: it,
                onCantidadChanged: (v) => onActualizarItem(it.producto.idProducto, cantidad: v),
                onPrecioChanged: (v) => onActualizarItem(it.producto.idProducto, precioUnitario: v),
                onQuitar: () => onQuitarItem(it.producto.idProducto),
              ),
            ),
          ),
        if (carrito.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text)),
              Text(
                formatGs(_total),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: puedeGenerar && !guardando ? onGenerar : null,
          child: guardando
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Generar OC'),
        ),
      ],
    );
  }
}

class _CarritoItemTile extends StatelessWidget {
  const _CarritoItemTile({
    required this.item,
    required this.onCantidadChanged,
    required this.onPrecioChanged,
    required this.onQuitar,
  });

  final OcSimpleCartItem item;
  final ValueChanged<double> onCantidadChanged;
  final ValueChanged<double> onPrecioChanged;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final error = item.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    Text(
                      item.producto.codigoInterno,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onQuitar,
                icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                tooltip: 'Quitar',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _formatNumero(item.cantidad),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Cantidad (${item.producto.unidadSimbolo})'),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed != null) onCantidadChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: _formatNumero(item.precioUnitario),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Precio unit.', prefixText: 'Gs. '),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed != null) onPrecioChanged(parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                error ?? 'Subtotal: ${formatGs(item.subtotal)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: error != null ? AppColors.erTx : AppColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatNumero(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
