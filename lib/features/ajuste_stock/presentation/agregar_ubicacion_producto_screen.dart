import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/domain/stock_models.dart' show ProductoAlmacenaje, ProductoDetalle, ProductoSimple;
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';

/// Ubicación agregada a mano en Control por producto: el producto está ahí
/// pero el sistema no lo tenía registrado → al aplicar se crea un lote nuevo
/// (`es_lote_nuevo`, ver `_crear_lote_y_existencia_para_ajuste`).
typedef UbicacionAgregada = ({UbicacionSimple ubicacion, AjusteItemNuevo item});

/// Paso extra de `ControlPorProductoScreen`: elegir/escanear una ubicación
/// donde está el producto sin stock registrado → cantidad + datos de lote
/// según `productos_almacenaje` (mismas reglas que "Agregar producto" del
/// control por ubicación). Devuelve un [UbicacionAgregada] vía `pop`.
class AgregarUbicacionProductoScreen extends ConsumerStatefulWidget {
  const AgregarUbicacionProductoScreen({
    super.key,
    required this.producto,
    required this.idsUbicacionYaListadas,
  });

  final ProductoSimple producto;

  /// Ubicaciones que ya tienen fila en el conteo — no se pueden repetir.
  final Set<int> idsUbicacionYaListadas;

  @override
  ConsumerState<AgregarUbicacionProductoScreen> createState() => _AgregarUbicacionProductoScreenState();
}

class _AgregarUbicacionProductoScreenState extends ConsumerState<AgregarUbicacionProductoScreen> {
  final _searchController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _loteController = TextEditingController();
  Timer? _debounce;

  UbicacionSimple? _ubicacion;
  ProductoDetalle? _detalle;
  ProductoAlmacenaje? _almacenaje;
  DateTime? _fechaVencimiento;
  DateTime? _fechaFaenado;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(ajusteBusquedaUbicacionProvider.notifier).state = '';
    });
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
      ref.read(ajusteBusquedaUbicacionProvider.notifier).state = value;
    });
  }

  Future<void> _elegirUbicacion(UbicacionSimple u) async {
    if (widget.idsUbicacionYaListadas.contains(u.idUbicacion)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${u.nombre} ya está en la lista del conteo')),
      );
      return;
    }
    if (u.idZona == null || u.idAlmacen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El servidor no devolvió la zona de la ubicación')),
      );
      return;
    }

    setState(() {
      _ubicacion = u;
      _cargando = _detalle == null;
    });
    if (_detalle != null) return;
    try {
      final (detalle, almacenaje) =
          await ref.read(ajusteStockRepositoryProvider).detalleProducto(widget.producto.idProducto);
      if (!mounted) return;
      setState(() {
        _detalle = detalle;
        _almacenaje = almacenaje;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _ubicacion = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Mismo criterio que el escaneo de ubicación de Control por ubicación:
  /// el `codigo` impreso en la etiqueta se busca en `GET /ubicaciones?q=` y
  /// si hay una única coincidencia exacta se elige sola.
  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    _debounce?.cancel();
    _searchController.text = codigo;
    ref.read(ajusteBusquedaUbicacionProvider.notifier).state = codigo;

    try {
      final resultados = await ref.read(ajusteResultadosUbicacionProvider.future);
      final exactas = resultados
          .where((u) => u.codigo.trim().toLowerCase() == codigo.trim().toLowerCase())
          .toList();
      if (!mounted) return;
      if (exactas.length == 1) await _elegirUbicacion(exactas.first);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _elegirFecha({required bool esVencimiento}) async {
    final ahora = DateTime.now();
    final primero = DateTime(ahora.year - 2);
    final ultimo = DateTime(ahora.year + 5);
    final elegida = await showDatePicker(
      context: context,
      initialDate: esVencimiento ? (_fechaVencimiento ?? _fechaFaenado ?? ahora) : (_fechaFaenado ?? ahora),
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

  void _agregar() {
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    String? error;
    if (cantidad == null || cantidad <= 0) {
      error = 'Ingresá una cantidad válida (mayor a 0)';
    } else if (_almacenaje!.requiereLote && _loteController.text.trim().isEmpty) {
      error = 'Este producto requiere lote del proveedor';
    } else if (_almacenaje!.requiereVencimiento && _fechaVencimiento == null) {
      error = 'Este producto requiere fecha de vencimiento';
    } else if (_almacenaje!.requiereFechaFaena && _fechaFaenado == null) {
      error = 'Este producto requiere fecha de faenado';
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final lote = _loteController.text.trim();
    Navigator.of(context).pop<UbicacionAgregada>((
      ubicacion: _ubicacion!,
      item: AjusteItemNuevo(
        idProducto: _detalle!.idProducto,
        productoNombre: _detalle!.nombre,
        idUnidadMedida: _detalle!.idUnidadBase,
        unidadSimbolo: _detalle!.unidadSimbolo,
        cantidadInicial: cantidad!,
        loteProveedor: lote.isEmpty ? null : lote,
        fechaVencimiento: _fechaVencimiento,
        fechaFaenado: _fechaFaenado,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_cargando) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_ubicacion == null || _detalle == null) {
      body = _BuscadorUbicacion(
        producto: widget.producto,
        controller: _searchController,
        onChanged: _onSearchChanged,
        onEscanear: _escanear,
        onSeleccionar: _elegirUbicacion,
      );
    } else {
      body = _Formulario(
        producto: _detalle!,
        ubicacion: _ubicacion!,
        almacenaje: _almacenaje!,
        cantidadController: _cantidadController,
        loteController: _loteController,
        fechaVencimiento: _fechaVencimiento,
        fechaFaenado: _fechaFaenado,
        onElegirFecha: _elegirFecha,
        onCambiarUbicacion: () => setState(() => _ubicacion = null),
        onAgregar: _agregar,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar ubicación')),
      body: body,
    );
  }
}

class _BuscadorUbicacion extends ConsumerWidget {
  const _BuscadorUbicacion({
    required this.producto,
    required this.controller,
    required this.onChanged,
    required this.onEscanear,
    required this.onSeleccionar,
  });

  final ProductoSimple producto;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onEscanear;
  final ValueChanged<UbicacionSimple> onSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ajusteResultadosUbicacionProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿En qué otra ubicación encontraste ${producto.nombre}?',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar ubicación (nombre o código)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                    tooltip: 'Escanear ubicación',
                    onPressed: onEscanear,
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
              if (controller.text.trim().isEmpty) {
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
                  final u = items[i];
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
                                '${u.nombre} (${u.codigo})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
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

class _Formulario extends StatelessWidget {
  const _Formulario({
    required this.producto,
    required this.ubicacion,
    required this.almacenaje,
    required this.cantidadController,
    required this.loteController,
    required this.fechaVencimiento,
    required this.fechaFaenado,
    required this.onElegirFecha,
    required this.onCambiarUbicacion,
    required this.onAgregar,
  });

  final ProductoDetalle producto;
  final UbicacionSimple ubicacion;
  final ProductoAlmacenaje almacenaje;
  final TextEditingController cantidadController;
  final TextEditingController loteController;
  final DateTime? fechaVencimiento;
  final DateTime? fechaFaenado;
  final Future<void> Function({required bool esVencimiento}) onElegirFecha;
  final VoidCallback onCambiarUbicacion;
  final VoidCallback onAgregar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(producto.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(producto.codigoInterno, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.accentDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ubicacion.nombre} (${ubicacion.codigo})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
              ),
              TextButton(onPressed: onCambiarUbicacion, child: const Text('Cambiar')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: cantidadController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(labelText: 'Cantidad contada (${producto.unidadSimbolo})'),
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
        ElevatedButton(onPressed: onAgregar, child: const Text('Agregar al conteo')),
      ],
    );
  }
}

class _FechaField extends StatelessWidget {
  const _FechaField({required this.label, required this.fecha, required this.onTap});

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
                style: TextStyle(color: fecha == null ? AppColors.faint : AppColors.text),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
