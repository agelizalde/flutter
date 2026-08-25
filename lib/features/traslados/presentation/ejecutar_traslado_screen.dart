import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/domain/stock_models.dart' show ExistenciaStock, ProductoConStock, ProductoSimple;
import '../application/traslados_providers.dart';
import '../domain/traslado_models.dart';

/// Producto ya resuelto a un único shape, sin importar si vino de la
/// búsqueda por texto (`ProductoConStock`, con agregados de stock) o de
/// escanear su código de barras (`ProductoSimple`, sin esos agregados —
/// no hacen falta para pasar al siguiente paso de elegir existencia).
class _ProductoSeleccionado {
  _ProductoSeleccionado({required this.idProducto, required this.nombre});

  factory _ProductoSeleccionado.deStock(ProductoConStock p) =>
      _ProductoSeleccionado(idProducto: p.idProducto, nombre: p.nombre);

  factory _ProductoSeleccionado.deSimple(ProductoSimple p) =>
      _ProductoSeleccionado(idProducto: p.idProducto, nombre: p.nombre);

  final int idProducto;
  final String nombre;
}

/// Origen ya resuelto a un único shape, sin importar si vino de una alerta
/// de reacomodo (ya trae todo) o de buscar producto → elegir existencia.
class _OrigenSeleccionado {
  _OrigenSeleccionado({
    required this.idExistencia,
    required this.productoNombre,
    required this.loteInterno,
    required this.unidadSimbolo,
    required this.cantidadDisponible,
    required this.ubicacionNombre,
    required this.ubicacionCodigo,
    this.idUbicacionPreferida,
    this.ubicacionPreferidaNombre,
    this.ubicacionPreferidaCodigo,
  });

  factory _OrigenSeleccionado.deAlerta(AlertaReacomodo a) => _OrigenSeleccionado(
    idExistencia: a.idExistencia,
    productoNombre: a.productoNombre,
    loteInterno: a.loteInterno,
    unidadSimbolo: a.unidadSimbolo,
    cantidadDisponible: a.cantidadDisponible,
    ubicacionNombre: a.ubicacionNombre,
    ubicacionCodigo: a.ubicacionCodigo,
    idUbicacionPreferida: a.idUbicacionPreferida,
    ubicacionPreferidaNombre: a.ubicacionPreferidaNombre,
    ubicacionPreferidaCodigo: a.ubicacionPreferidaCodigo,
  );

  factory _OrigenSeleccionado.deExistencia(ExistenciaStock e) => _OrigenSeleccionado(
    idExistencia: e.idExistencia,
    productoNombre: e.productoNombre,
    loteInterno: e.loteInterno,
    unidadSimbolo: e.unidadSimbolo,
    cantidadDisponible: e.cantidadDisponible,
    ubicacionNombre: e.ubicacionNombre,
    ubicacionCodigo: e.ubicacionCodigo,
    idUbicacionPreferida: e.idUbicacionPreferida,
    ubicacionPreferidaNombre: e.ubicacionPreferidaNombre,
    ubicacionPreferidaCodigo: e.ubicacionPreferidaCodigo,
  );

  final int idExistencia;
  final String productoNombre;
  final String loteInterno;
  final String unidadSimbolo;
  final double cantidadDisponible;
  final String ubicacionNombre;
  final String ubicacionCodigo;

  /// Ubicación recomendada del producto (`productos_almacenaje.id_ubicacion_preferida`),
  /// null si no tiene una configurada.
  final int? idUbicacionPreferida;
  final String? ubicacionPreferidaNombre;
  final String? ubicacionPreferidaCodigo;
}

/// Flujo único para "Trasladar" desde una alerta de reacomodo (origen ya
/// conocido, `prefillAlerta` no nulo) y para crear un traslado manual
/// (busca producto → elige existencia → cantidad/destino). Ambos terminan
/// en el mismo `POST /traslados/ejecutar` (ver `traslados_repository.dart`).
class EjecutarTrasladoScreen extends ConsumerStatefulWidget {
  const EjecutarTrasladoScreen({super.key, this.prefillAlerta});

  final AlertaReacomodo? prefillAlerta;

  @override
  ConsumerState<EjecutarTrasladoScreen> createState() => _EjecutarTrasladoScreenState();
}

class _EjecutarTrasladoScreenState extends ConsumerState<EjecutarTrasladoScreen> {
  final _searchController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _observacionController = TextEditingController();
  Timer? _debounce;

  _ProductoSeleccionado? _producto;
  _OrigenSeleccionado? _origen;
  UbicacionSimple? _destino;
  bool _ejecutando = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillAlerta != null) {
      _origen = _OrigenSeleccionado.deAlerta(widget.prefillAlerta!);
      _cantidadController.text = _formatCantidad(_origen!.cantidadDisponible);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _cantidadController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  static String _formatCantidad(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(trasladoBusquedaProductoProvider.notifier).state = value;
    });
  }

  /// Abre la cámara, resuelve el código escaneado a un producto (mismo
  /// patrón que `AgregarItemScreen._escanear` en Recepción) y salta directo
  /// a elegir existencia — mismo destino que tocar un resultado de
  /// búsqueda por texto.
  Future<void> _escanearProducto() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    try {
      final producto = await ref.read(trasladosRepositoryProvider).buscarProductoPorCodigoBarra(codigo);
      if (!mounted) return;
      setState(() => _producto = _ProductoSeleccionado.deSimple(producto));
    } catch (e) {
      if (!mounted) return;
      // Se muestra el código leído (no solo el mensaje del backend) para
      // poder distinguir "la cámara leyó mal" de "el código no está
      // registrado" — sin esto, ambos casos se ven igual en pantalla.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código "$codigo": ${describeError(e)}')),
      );
    }
  }

  void _seleccionarExistencia(ExistenciaStock e) {
    setState(() {
      _origen = _OrigenSeleccionado.deExistencia(e);
      _cantidadController.text = _formatCantidad(e.cantidadDisponible);
    });
  }

  void _volverABuscarProducto() {
    setState(() {
      _producto = null;
      _origen = null;
      _destino = null;
      _cantidadController.clear();
      _searchController.clear();
    });
    ref.read(trasladoBusquedaProductoProvider.notifier).state = '';
  }

  Future<void> _elegirDestino() async {
    final seleccionado = await showModalBottomSheet<UbicacionSimple>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BuscarUbicacionSheet(idUbicacionRecomendada: _origen?.idUbicacionPreferida),
    );
    if (seleccionado != null) setState(() => _destino = seleccionado);
  }

  /// Atajo de un toque: usa directo la ubicación recomendada del producto
  /// como destino, sin pasar por el buscador. Se arma con lo que ya trajo
  /// el origen (alerta de reacomodo o existencia) — no hace falta otra
  /// llamada al backend.
  void _usarUbicacionRecomendada() {
    final o = _origen;
    if (o?.idUbicacionPreferida == null) return;
    setState(() {
      _destino = UbicacionSimple(
        idUbicacion: o!.idUbicacionPreferida!,
        nombre: o.ubicacionPreferidaNombre ?? '',
        codigo: o.ubicacionPreferidaCodigo ?? '',
      );
    });
  }

  Future<void> _ejecutar() async {
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá una cantidad válida')),
      );
      return;
    }
    if (cantidad > _origen!.cantidadDisponible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad supera lo disponible')),
      );
      return;
    }
    if (_destino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí una ubicación destino')),
      );
      return;
    }

    setState(() => _ejecutando = true);
    try {
      final resultado = await ref.read(trasladosRepositoryProvider).ejecutar(
        idExistenciaOrigen: _origen!.idExistencia,
        cantidad: cantidad,
        idUbicacionDestino: _destino!.idUbicacion,
        observaciones: _observacionController.text.trim().isEmpty
            ? null
            : _observacionController.text.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Traslado ejecutado'),
          content: Text('${resultado.codigo} — ${resultado.itemsProcesados} ítem(s) movidos a stock.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _ejecutando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo traslado')),
      body: _origen != null
          ? _FormularioTraslado(
              origen: _origen!,
              destino: _destino,
              cantidadController: _cantidadController,
              observacionController: _observacionController,
              ejecutando: _ejecutando,
              puedeCambiarOrigen: widget.prefillAlerta == null,
              onCambiarOrigen: _volverABuscarProducto,
              onElegirDestino: _elegirDestino,
              onUsarRecomendada: _usarUbicacionRecomendada,
              onEjecutar: _ejecutar,
            )
          : _producto != null
              ? _ListaExistencias(
                  idProducto: _producto!.idProducto,
                  productoNombre: _producto!.nombre,
                  onSeleccionar: _seleccionarExistencia,
                  onVolver: () => setState(() => _producto = null),
                )
              : _BuscadorProducto(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSeleccionar: (p) => setState(() => _producto = _ProductoSeleccionado.deStock(p)),
                  onEscanear: _escanearProducto,
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
  final ValueChanged<ProductoConStock> onSeleccionar;
  final VoidCallback onEscanear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trasladoResultadosProductoProvider);

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
                                  Text(
                                    '${p.codigoInterno} · Disponible: ${p.stockDisponible.toStringAsFixed(0)} ${p.unidadSimbolo}',
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

class _ListaExistencias extends ConsumerWidget {
  const _ListaExistencias({
    required this.idProducto,
    required this.productoNombre,
    required this.onSeleccionar,
    required this.onVolver,
  });

  final int idProducto;
  final String productoNombre;
  final ValueChanged<ExistenciaStock> onSeleccionar;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trasladoExistenciasDeProductoProvider(idProducto));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(onPressed: onVolver, icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: Text(
                  productoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(
            'Elegí de qué lote/ubicación sale el traslado',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            data: (existencias) {
              final disponibles = existencias.where((e) => e.cantidadDisponible > 0).toList();
              if (disponibles.isEmpty) {
                return const Center(
                  child: Text('No hay stock disponible para trasladar', style: TextStyle(color: AppColors.muted)),
                );
              }
              // La(s) que están en la ubicación recomendada del producto van
              // primero — no hay que ir a buscarlas en medio de la lista.
              final ordenadas = [
                ...disponibles.where((e) => e.esUbicacionRecomendada),
                ...disponibles.where((e) => !e.esUbicacionRecomendada),
              ];
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: ordenadas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = ordenadas[i];
                  final recomendada = e.esUbicacionRecomendada;
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSeleccionar(e),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: recomendada
                              ? Border.all(color: AppColors.okTx.withValues(alpha: 0.35), width: 1.4)
                              : null,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          '${e.ubicacionNombre} (${e.ubicacionCodigo})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                                        ),
                                      ),
                                      if (recomendada) ...[
                                        const SizedBox(width: 6),
                                        const _BadgeRecomendada(),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lote ${e.loteInterno}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${e.cantidadDisponible.toStringAsFixed(0)} ${e.unidadSimbolo}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accentDark),
                            ),
                            const SizedBox(width: 8),
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

/// Distintivo para la existencia cuya ubicación coincide con la
/// "ubicación recomendada" configurada en el producto (ver
/// `ExistenciaStock.esUbicacionRecomendada`).
class _BadgeRecomendada extends StatelessWidget {
  const _BadgeRecomendada();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: AppColors.okBg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.okTx),
          const SizedBox(width: 3),
          Text(
            'Recomendada',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.okTx),
          ),
        ],
      ),
    );
  }
}

/// Aviso arriba del campo de destino cuando el producto tiene una ubicación
/// recomendada configurada y todavía no es la elegida — con un atajo para
/// usarla directo, sin tener que buscarla ni escanearla.
class _BannerUbicacionRecomendada extends StatelessWidget {
  const _BannerUbicacionRecomendada({
    required this.nombre,
    required this.codigo,
    required this.onUsar,
  });

  final String nombre;
  final String codigo;
  final VoidCallback onUsar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.okBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.okTx.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 20, color: AppColors.okTx),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ubicación recomendada',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.okTx),
                ),
                Text(
                  codigo.isNotEmpty && codigo != nombre ? '$nombre ($codigo)' : nombre,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onUsar,
            style: TextButton.styleFrom(foregroundColor: AppColors.okTx),
            child: const Text('Usar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _FormularioTraslado extends StatelessWidget {
  const _FormularioTraslado({
    required this.origen,
    required this.destino,
    required this.cantidadController,
    required this.observacionController,
    required this.ejecutando,
    required this.puedeCambiarOrigen,
    required this.onCambiarOrigen,
    required this.onElegirDestino,
    required this.onUsarRecomendada,
    required this.onEjecutar,
  });

  final _OrigenSeleccionado origen;
  final UbicacionSimple? destino;
  final TextEditingController cantidadController;
  final TextEditingController observacionController;
  final bool ejecutando;
  final bool puedeCambiarOrigen;
  final VoidCallback onCambiarOrigen;
  final VoidCallback onElegirDestino;
  final VoidCallback onUsarRecomendada;
  final Future<void> Function() onEjecutar;

  @override
  Widget build(BuildContext context) {
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
                      origen.productoNombre,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lote ${origen.loteInterno} · Desde ${origen.ubicacionNombre} (${origen.ubicacionCodigo})',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Disponible: ${origen.cantidadDisponible.toStringAsFixed(0)} ${origen.unidadSimbolo}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                  ],
                ),
              ),
              if (puedeCambiarOrigen)
                TextButton(onPressed: onCambiarOrigen, child: const Text('Cambiar')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: cantidadController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Cantidad a trasladar (${origen.unidadSimbolo})'),
        ),
        const SizedBox(height: 16),
        if (origen.idUbicacionPreferida != null && destino?.idUbicacion != origen.idUbicacionPreferida) ...[
          _BannerUbicacionRecomendada(
            nombre: origen.ubicacionPreferidaNombre ?? '',
            codigo: origen.ubicacionPreferidaCodigo ?? '',
            onUsar: onUsarRecomendada,
          ),
          const SizedBox(height: 12),
        ],
        InkWell(
          onTap: onElegirDestino,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Ubicación destino'),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: destino == null ? AppColors.faint : AppColors.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    destino != null ? '${destino!.nombre} (${destino!.codigo})' : 'Elegir ubicación',
                    style: TextStyle(
                      color: destino == null ? AppColors.faint : AppColors.text,
                      fontWeight: destino == null ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                if (destino != null && destino!.idUbicacion == origen.idUbicacionPreferida) ...[
                  const _BadgeRecomendada(),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.search, size: 18, color: AppColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: observacionController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Observación (opcional)'),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: ejecutando ? null : onEjecutar,
          child: ejecutando
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Ejecutar traslado'),
        ),
      ],
    );
  }
}

class _BuscarUbicacionSheet extends ConsumerStatefulWidget {
  const _BuscarUbicacionSheet({this.idUbicacionRecomendada});

  /// Si no es null, la ubicación con este id se marca con
  /// `_BadgeRecomendada` entre los resultados de la búsqueda.
  final int? idUbicacionRecomendada;

  @override
  ConsumerState<_BuscarUbicacionSheet> createState() => _BuscarUbicacionSheetState();
}

class _BuscarUbicacionSheetState extends ConsumerState<_BuscarUbicacionSheet> {
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
      ref.read(trasladoBusquedaUbicacionProvider.notifier).state = value;
    });
  }

  /// Abre la cámara y busca por el código escaneado (mismo patrón que
  /// `AgregarItemScreen._escanear`). Las ubicaciones no tienen un código de
  /// barra separado — el `codigo` (ej. "CONT-A") es lo que se imprime en la
  /// etiqueta física, así que el código escaneado se busca directo contra
  /// ese campo. Si hay un único resultado con `codigo` exactamente igual al
  /// escaneado, se selecciona solo; si no, se deja la búsqueda con ese
  /// texto para que el usuario elija de la lista.
  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    _debounce?.cancel();
    _controller.text = codigo;
    ref.read(trasladoBusquedaUbicacionProvider.notifier).state = codigo;

    try {
      final resultados = await ref.read(trasladoResultadosUbicacionProvider.future);
      final exactas = resultados
          .where((u) => u.codigo.trim().toLowerCase() == codigo.trim().toLowerCase())
          .toList();
      if (!mounted) return;
      if (exactas.length == 1) {
        Navigator.of(context).pop(exactas.first);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(trasladoResultadosUbicacionProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const Text(
                'Buscar ubicación destino',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Nombre o código de ubicación...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                    tooltip: 'Escanear ubicación',
                    onPressed: _escanear,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(describeError(e))),
                  data: (items) {
                    if (_controller.text.trim().isEmpty) {
                      return const Center(child: Text('Escribí para buscar', style: TextStyle(color: AppColors.muted)));
                    }
                    if (items.isEmpty) {
                      return const Center(child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)));
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final u = items[i];
                        final recomendada = u.idUbicacion == widget.idUbicacionRecomendada;
                        return Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => Navigator.of(context).pop(u),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: recomendada
                                    ? Border.all(color: AppColors.okTx.withValues(alpha: 0.35), width: 1.4)
                                    : null,
                              ),
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
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${u.nombre} (${u.codigo})',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                                          ),
                                        ),
                                        if (recomendada) ...[
                                          const SizedBox(width: 6),
                                          const _BadgeRecomendada(),
                                        ],
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
          ),
        ),
      ),
    );
  }
}
