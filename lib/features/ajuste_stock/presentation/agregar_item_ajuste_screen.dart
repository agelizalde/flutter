import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../stock/domain/stock_models.dart'
    show ProductoAlmacenaje, ProductoDetalle, ProductoSimple;
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';

/// Busca un producto → muestra formulario dinámico (cantidad + lote/vencimiento/
/// faena según `productos_almacenaje`) → acumula ítems → devuelve la lista
/// al `NuevoAjusteScreen` vía `Navigator.pop`. No hace ninguna llamada al
/// backend hasta que el ajuste completo se confirme.
///
/// Recibe [productoInicial] cuando se llega desde un escaneo de código de
/// barras que no estaba en la lista de conteo; en ese caso se salta el
/// buscador y se carga el formulario directamente.
class AgregarItemAjusteScreen extends ConsumerStatefulWidget {
  const AgregarItemAjusteScreen({super.key, this.productoInicial});

  final ProductoSimple? productoInicial;

  @override
  ConsumerState<AgregarItemAjusteScreen> createState() =>
      _AgregarItemAjusteScreenState();
}

class _AgregarItemAjusteScreenState
    extends ConsumerState<AgregarItemAjusteScreen> {
  final _searchController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _loteController = TextEditingController();
  Timer? _debounce;

  ProductoDetalle? _producto;
  ProductoAlmacenaje? _almacenaje;
  DateTime? _fechaVencimiento;
  DateTime? _fechaFaenado;
  bool _cargandoDetalle = false;
  bool _agregando = false;

  final List<AjusteItemNuevo> _acumulados = [];

  @override
  void initState() {
    super.initState();
    if (widget.productoInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _seleccionarProducto(widget.productoInicial!);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cantidadController.dispose();
    _loteController.dispose();
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
      final (detalle, almacenaje) =
          await ref.read(ajusteStockRepositoryProvider).detalleProducto(p.idProducto);
      setState(() {
        _producto = detalle;
        _almacenaje = almacenaje;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(e))));
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
      final producto = await ref
          .read(ajusteStockRepositoryProvider)
          .buscarProductoPorCodigoBarra(codigo);
      if (!mounted) return;
      await _seleccionarProducto(producto);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDetalle = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  void _volverABuscar() {
    setState(() {
      _producto = null;
      _almacenaje = null;
      _fechaVencimiento = null;
      _fechaFaenado = null;
      _cantidadController.clear();
      _loteController.clear();
      _searchController.clear();
    });
    ref.read(ajusteBusquedaProductoProvider.notifier).state = '';
  }

  Future<void> _elegirFecha({required bool esVencimiento}) async {
    final ahora = DateTime.now();
    final primero = DateTime(ahora.year - 2);
    final ultimo = DateTime(ahora.year + 5);
    final elegida = await showDatePicker(
      context: context,
      initialDate: esVencimiento
          ? (_fechaVencimiento ?? _fechaFaenado ?? ahora)
          : (_fechaFaenado ?? ahora),
      firstDate: esVencimiento ? (_fechaFaenado ?? primero) : primero,
      lastDate: esVencimiento ? ultimo : (_fechaVencimiento ?? ultimo),
    );
    if (elegida == null) return;
    setState(() {
      if (esVencimiento) {
        _fechaVencimiento = elegida;
      } else {
        _fechaFaenado = elegida;
      }
    });
  }

  Future<void> _agregar() async {
    final cantidad = double.tryParse(
      _cantidadController.text.replaceAll(',', '.'),
    );
    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá una cantidad válida (mayor a 0)')),
      );
      return;
    }
    if (_almacenaje!.requiereLote && _loteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto requiere lote del proveedor')),
      );
      return;
    }
    if (_almacenaje!.requiereVencimiento && _fechaVencimiento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto requiere fecha de vencimiento')),
      );
      return;
    }
    if (_almacenaje!.requiereFechaFaena && _fechaFaenado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este producto requiere fecha de faenado')),
      );
      return;
    }

    setState(() => _agregando = true);
    try {
      final nuevo = AjusteItemNuevo(
        idProducto: _producto!.idProducto,
        productoNombre: _producto!.nombre,
        idUnidadMedida: _producto!.idUnidadBase,
        unidadSimbolo: _producto!.unidadSimbolo,
        cantidadInicial: cantidad,
        loteProveedor: _loteController.text.trim().isEmpty
            ? null
            : _loteController.text.trim(),
        fechaVencimiento: _fechaVencimiento,
        fechaFaenado: _fechaFaenado,
      );
      setState(() => _acumulados.add(nuevo));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Agregado: ${_producto!.nombre}')));
      _volverABuscar();
    } finally {
      if (mounted) setState(() => _agregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _acumulados.isNotEmpty
              ? 'Agregar producto (${_acumulados.length})'
              : 'Agregar producto',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_acumulados),
            child: const Text('Listo'),
          ),
        ],
      ),
      body: _cargandoDetalle
          ? const Center(child: CircularProgressIndicator())
          : _producto == null
          ? _BuscadorProducto(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSeleccionar: _seleccionarProducto,
              onEscanear: _escanear,
            )
          : _FormularioItem(
              producto: _producto!,
              almacenaje: _almacenaje!,
              cantidadController: _cantidadController,
              loteController: _loteController,
              fechaVencimiento: _fechaVencimiento,
              fechaFaenado: _fechaFaenado,
              agregando: _agregando,
              onElegirFecha: _elegirFecha,
              onCancelar: _volverABuscar,
              onAgregar: _agregar,
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
            error: (e, _) => Center(
              child: Text(
                describeError(e),
                style: const TextStyle(color: AppColors.erTx),
              ),
            ),
            data: (items) {
              if (controller.text.trim().isEmpty) {
                return const Center(
                  child: Text(
                    'Escribí para buscar',
                    style: TextStyle(color: AppColors.muted),
                  ),
                );
              }
              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    'Sin resultados',
                    style: TextStyle(color: AppColors.muted),
                  ),
                );
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
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.accentDark,
                                size: 20,
                              ),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    p.codigoInterno,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
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

class _FormularioItem extends StatelessWidget {
  const _FormularioItem({
    required this.producto,
    required this.almacenaje,
    required this.cantidadController,
    required this.loteController,
    required this.fechaVencimiento,
    required this.fechaFaenado,
    required this.agregando,
    required this.onElegirFecha,
    required this.onCancelar,
    required this.onAgregar,
  });

  final ProductoDetalle producto;
  final ProductoAlmacenaje almacenaje;
  final TextEditingController cantidadController;
  final TextEditingController loteController;
  final DateTime? fechaVencimiento;
  final DateTime? fechaFaenado;
  final bool agregando;
  final Future<void> Function({required bool esVencimiento}) onElegirFecha;
  final VoidCallback onCancelar;
  final Future<void> Function() onAgregar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          producto.nombre,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          producto.codigoInterno,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: cantidadController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Cantidad (${producto.unidadSimbolo})',
          ),
        ),
        if (almacenaje.requiereLote) ...[
          const SizedBox(height: 16),
          TextField(
            controller: loteController,
            decoration: const InputDecoration(labelText: 'Lote del proveedor *'),
          ),
        ],
        if (almacenaje.requiereVencimiento) ...[
          const SizedBox(height: 16),
          _FechaField(
            label: 'Fecha de vencimiento *',
            fecha: fechaVencimiento,
            onTap: () => onElegirFecha(esVencimiento: true),
          ),
        ],
        if (almacenaje.requiereFechaFaena) ...[
          const SizedBox(height: 16),
          _FechaField(
            label: 'Fecha de faenado *',
            fecha: fechaFaenado,
            onTap: () => onElegirFecha(esVencimiento: false),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancelar,
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: agregando ? null : onAgregar,
                child: agregando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Agregar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FechaField extends StatelessWidget {
  const _FechaField({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fecha != null ? formatFecha(fecha!) : 'Elegir fecha',
                style: TextStyle(
                  color: fecha == null ? AppColors.faint : AppColors.text,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
