import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../stock/domain/stock_models.dart' show ProductoSimple;
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';
import 'buscador_producto_ajuste.dart';

String _formatCantidad(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// "Mermar producto" (opción c de Nuevo ajuste): producto → ubicación donde
/// está → cantidad + causa → listo. No pasa por BORRADOR/CONFIRMADO:
/// `POST /ajuste-stock/merma-rapida` con `id_ubicacion` crea+confirma+aplica
/// de una, descontando solo de esa ubicación (ver `ajuste_stock_merma_rapida`
/// en el backend; con causa Vencimiento sale del lote que vence antes).
class MermaRapidaScreen extends ConsumerStatefulWidget {
  const MermaRapidaScreen({super.key});

  @override
  ConsumerState<MermaRapidaScreen> createState() => _MermaRapidaScreenState();
}

class _MermaRapidaScreenState extends ConsumerState<MermaRapidaScreen> {
  final _cantidadController = TextEditingController();

  ProductoSimple? _producto;
  bool _cargandoUbicaciones = false;
  List<StockEnUbicacion> _ubicaciones = const [];
  StockEnUbicacion? _ubicacion;
  String? _motivoCategoria;
  bool _guardando = false;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarProducto(ProductoSimple p) async {
    final idAlmacen = ref.read(authControllerProvider).value?.idAlmacenSeleccionado;
    if (idAlmacen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un almacén seleccionado')),
      );
      return;
    }

    setState(() {
      _producto = p;
      _cargandoUbicaciones = true;
    });
    try {
      final ubicaciones = await ref
          .read(ajusteStockRepositoryProvider)
          .stockPorUbicacionDeProducto(p.idProducto, idAlmacen: idAlmacen);
      if (!mounted) return;
      setState(() {
        _ubicaciones = ubicaciones;
        // Una sola ubicación: se elige sola, no tiene sentido hacer tocar.
        if (ubicaciones.length == 1) _ubicacion = ubicaciones.first;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _producto = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cargandoUbicaciones = false);
    }
  }

  void _volverAProducto() {
    setState(() {
      _producto = null;
      _ubicaciones = const [];
      _ubicacion = null;
      _motivoCategoria = null;
      _cantidadController.clear();
    });
  }

  void _volverAUbicacion() {
    if (_ubicaciones.length <= 1) {
      _volverAProducto();
      return;
    }
    setState(() {
      _ubicacion = null;
      _cantidadController.clear();
    });
  }

  Future<void> _confirmar() async {
    final u = _ubicacion!;
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá una cantidad válida (mayor a 0)')),
      );
      return;
    }
    if (cantidad > u.cantidad) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('En ${u.ubicacionNombre} hay ${_formatCantidad(u.cantidad)} ${u.unidadSimbolo}, no se puede mermar más'),
        ),
      );
      return;
    }
    if (_motivoCategoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí una causa')),
      );
      return;
    }

    final idAlmacen = u.idAlmacen ?? ref.read(authControllerProvider).value?.idAlmacenSeleccionado;
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
        idUnidadMedida: u.idUnidadMedida,
        idAlmacen: idAlmacen,
        idUbicacion: u.idUbicacion,
        cantidad: cantidad,
        motivoCategoria: _motivoCategoria!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Mermado: ${_formatCantidad(cantidad)} ${u.unidadSimbolo} de ${_producto!.nombre} (${u.ubicacionNombre})',
          ),
        ),
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
    final Widget body;
    if (_producto == null) {
      body = BuscadorProductoAjuste(
        ayuda: 'Elegí el producto a mermar.',
        onSeleccionar: _seleccionarProducto,
      );
    } else if (_cargandoUbicaciones) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_ubicacion == null) {
      body = _PasoUbicacion(
        producto: _producto!,
        ubicaciones: _ubicaciones,
        onVolver: _volverAProducto,
        onSeleccionar: (u) => setState(() => _ubicacion = u),
      );
    } else {
      body = _FormularioMerma(
        producto: _producto!,
        ubicacion: _ubicacion!,
        cantidadController: _cantidadController,
        motivoCategoria: _motivoCategoria,
        guardando: _guardando,
        onMotivoChanged: (v) => setState(() => _motivoCategoria = v),
        onVolver: _volverAUbicacion,
        onConfirmar: _confirmar,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mermar producto')),
      body: body,
    );
  }
}

class _PasoUbicacion extends StatelessWidget {
  const _PasoUbicacion({
    required this.producto,
    required this.ubicaciones,
    required this.onVolver,
    required this.onSeleccionar,
  });

  final ProductoSimple producto;
  final List<StockEnUbicacion> ubicaciones;
  final VoidCallback onVolver;
  final ValueChanged<StockEnUbicacion> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductoElegidoHeader(nombre: producto.nombre, codigo: producto.codigoInterno, onCambiar: onVolver),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            ubicaciones.isEmpty
                ? 'Este producto no tiene stock en el almacén.'
                : '¿De qué ubicación sale la merma?',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: ubicaciones.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final u = ubicaciones[i];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSeleccionar(u),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.location_on_outlined, color: AppColors.accentDark, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${u.ubicacionNombre} (${u.ubicacionCodigo})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                          ),
                        ),
                        Text(
                          '${_formatCantidad(u.cantidad)} ${u.unidadSimbolo}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.sub),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.faint),
                      ],
                    ),
                  ),
                ),
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
    required this.ubicacion,
    required this.cantidadController,
    required this.motivoCategoria,
    required this.guardando,
    required this.onMotivoChanged,
    required this.onVolver,
    required this.onConfirmar,
  });

  final ProductoSimple producto;
  final StockEnUbicacion ubicacion;
  final TextEditingController cantidadController;
  final String? motivoCategoria;
  final bool guardando;
  final ValueChanged<String> onMotivoChanged;
  final VoidCallback onVolver;
  final Future<void> Function() onConfirmar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      children: [
        ProductoElegidoHeader(nombre: producto.nombre, codigo: producto.codigoInterno, onCambiar: guardando ? null : onVolver),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: AppColors.accentDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ubicacion.ubicacionNombre} (${ubicacion.ubicacionCodigo})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                    ),
                    Text(
                      'Hay ${_formatCantidad(ubicacion.cantidad)} ${ubicacion.unidadSimbolo}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: cantidadController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(labelText: 'Cantidad a mermar (${ubicacion.unidadSimbolo})'),
              ),
              const SizedBox(height: 20),
              const Text('Causa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sub)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: motivosMermaRapida
                    .map(
                      (m) => ChoiceChip(
                        label: Text(m.$2),
                        selected: motivoCategoria == m.$1,
                        onSelected: guardando ? null : (_) => onMotivoChanged(m.$1),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: guardando || motivoCategoria == null ? null : () => onConfirmar(),
                child: guardando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Mermar'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
