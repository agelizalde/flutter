import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/domain/stock_models.dart' show ExistenciaStock, ProductoConStock, ProductoSimple;
import '../application/traslados_providers.dart';
import '../domain/traslado_models.dart';
import 'traslados_ayuda.dart';

// Misma paleta que la demo de `traslados_ayuda.dart`: lo que el operario ve
// en la presentación es lo que encuentra al hacer el traslado.
const _pastel = Color(0xFFEDE9FE);
const _fuerte = Color(0xFF7C3AED);
const _oscuro = Color(0xFF5B21B6);

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
///
/// Visualmente sigue a la presentación del módulo (`traslados_ayuda.dart` +
/// `walkthrough_modulo.dart`): degradado violeta, una pregunta grande por
/// paso, puntitos de progreso y entrada en cascada.
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

  /// 0 = producto, 1 = de dónde sale, 2 = a dónde va.
  int get _paso => _origen != null ? 2 : (_producto != null ? 1 : 0);

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

  /// "Atrás" (flecha del AppBar o gesto del sistema) vuelve un paso en vez
  /// de salir de la pantalla.
  void _retroceder() {
    setState(() {
      if (_origen != null) {
        _origen = null;
        _destino = null;
      } else {
        _producto = null;
      }
    });
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
          icon: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: _fuerte, shape: BoxShape.circle),
            child: const Icon(Icons.check, size: 30, color: Colors.white),
          ),
          title: const Text('Traslado ejecutado'),
          content: Text(
            '${resultado.codigo} — movido a ${_destino!.nombre}.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: _oscuro),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
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
    final paso = _paso;
    final desdePendiente = widget.prefillAlerta != null;

    final Widget contenido = switch (paso) {
      2 => _FormularioTraslado(
          origen: _origen!,
          destino: _destino,
          cantidadController: _cantidadController,
          observacionController: _observacionController,
          ejecutando: _ejecutando,
          puedeCambiarOrigen: !desdePendiente,
          onCambiarOrigen: _volverABuscarProducto,
          onElegirDestino: _elegirDestino,
          onUsarRecomendada: _usarUbicacionRecomendada,
          onEjecutar: _ejecutar,
        ),
      1 => _ListaExistencias(
          idProducto: _producto!.idProducto,
          productoNombre: _producto!.nombre,
          onSeleccionar: _seleccionarExistencia,
        ),
      _ => _BuscadorProducto(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onSeleccionar: (p) => setState(() => _producto = _ProductoSeleccionado.deStock(p)),
          onEscanear: _escanearProducto,
        ),
    };

    return PopScope(
      canPop: desdePendiente || paso == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _retroceder();
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          backgroundColor: _pastel,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: _oscuro,
          title: Text(
            desdePendiente ? 'Trasladar' : 'Nuevo traslado',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _oscuro),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: '¿Cómo funciona?',
              onPressed: () => abrirAyudaTraslados(context),
            ),
          ],
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_pastel, AppColors.pageBg],
              stops: [0, 0.45],
            ),
          ),
          child: Column(
            children: [
              _Progreso(paso: paso, desdePendiente: desdePendiente),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(key: ValueKey(paso), child: contenido),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas comunes (mismo lenguaje que walkthrough_modulo.dart)
// ---------------------------------------------------------------------------

/// Elemento que entra en cascada: sube 24 px con fundido, demorado según
/// su [orden] — igual que en la presentación del módulo.
class _Cascada extends StatelessWidget {
  const _Cascada({required this.orden, required this.child});

  final int orden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final demora = math.min(orden, 6) * 70;
    final total = 420 + demora;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(demora / total, 1, curve: Curves.easeOutCubic),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

/// Puntitos de la presentación (el activo se estira) + "PASO N DE 3".
class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso, required this.desdePendiente});

  static const _nombres = ['Producto', 'Origen', 'Destino'];

  final int paso;
  final bool desdePendiente;

  @override
  Widget build(BuildContext context) {
    const estilo = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _oscuro, letterSpacing: 1.3);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
      child: Row(
        children: [
          if (desdePendiente)
            const Text('PENDIENTE DE ACOMODAR', style: estilo)
          else ...[
            for (var i = 0; i < 3; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(right: 6),
                width: i == paso ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= paso ? _fuerte : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            const SizedBox(width: 6),
            Text('PASO ${paso + 1} DE 3 · ${_nombres[paso].toUpperCase()}', style: estilo),
          ],
        ],
      ),
    );
  }
}

/// La pregunta grande de cada paso, como "Cómo funciona" en la presentación.
class _Titulo extends StatelessWidget {
  const _Titulo({
    required this.titulo,
    this.subtitulo,
    this.padding = const EdgeInsets.fromLTRB(24, 4, 24, 18),
  });

  final String titulo;
  final Widget? subtitulo;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Cascada(
            orden: 0,
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w900, color: AppColors.ink),
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 6),
            _Cascada(
              orden: 1,
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 15, height: 1.35, color: AppColors.sub),
                child: subtitulo!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta blanca de las listas — la de "Pendientes" de la demo, a tamaño
/// real: texto a la izquierda y una píldora a la derecha.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({
    required this.titulo,
    required this.detalle,
    required this.pildora,
    required this.onTap,
    this.extraTitulo,
    this.resaltada = false,
  });

  final String titulo;
  final String detalle;
  final Widget pildora;
  final VoidCallback onTap;
  final Widget? extraTitulo;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: resaltada ? Border.all(color: _fuerte.withValues(alpha: 0.45), width: 1.4) : null,
          ),
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
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                          ),
                        ),
                        if (extraTitulo != null) ...[const SizedBox(width: 6), extraTitulo!],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              pildora,
            ],
          ),
        ),
      ),
    );
  }
}

class _Pildora extends StatelessWidget {
  const _Pildora(this.texto, {this.llena = true});

  final String texto;
  final bool llena;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: llena ? _fuerte : _pastel, borderRadius: BorderRadius.circular(999)),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: llena ? Colors.white : _oscuro),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje(this.texto, {this.icono = Icons.search_off, this.color = AppColors.muted});

  final String texto;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: AppColors.faint),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Lista de [_Tarjeta]s: las primeras entran en cascada.
Widget _listaTarjetas(int cantidad, Widget Function(int i) tarjeta) {
  return ListView.separated(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    itemCount: cantidad,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, i) => i < 8 ? _Cascada(orden: 2 + i, child: tarjeta(i)) : tarjeta(i),
  );
}

// ---------------------------------------------------------------------------
// Paso 1 · ¿Qué vas a mover?
// ---------------------------------------------------------------------------

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
        const _Titulo(
          titulo: '¿Qué vas a mover?',
          subtitulo: Text('Escaneá el código del producto o buscalo por nombre.'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: _Cascada(
            orden: 2,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Nombre o código...',
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: _fuerte),
                  tooltip: 'Escanear código de barras',
                  onPressed: onEscanear,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: controller.text.trim().isEmpty
              ? _InvitacionEscanear(onEscanear: onEscanear)
              : async.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: _fuerte)),
                  error: (e, _) => _Mensaje(describeError(e), icono: Icons.error_outline, color: AppColors.erTx),
                  data: (items) {
                    if (items.isEmpty) return const _Mensaje('Sin resultados');
                    return _listaTarjetas(items.length, (i) {
                      final p = items[i];
                      return _Tarjeta(
                        titulo: p.nombre,
                        detalle:
                            '${p.codigoInterno} · ${p.stockDisponible.toStringAsFixed(0)} ${p.unidadSimbolo} disponibles',
                        pildora: const _Pildora('Elegir'),
                        onTap: () => onSeleccionar(p),
                      );
                    });
                  },
                ),
        ),
      ],
    );
  }
}

/// Con el buscador vacío: el botón grande de escanear, con las ondas de la
/// primera pantalla de la presentación.
class _InvitacionEscanear extends StatefulWidget {
  const _InvitacionEscanear({required this.onEscanear});

  final VoidCallback onEscanear;

  @override
  State<_InvitacionEscanear> createState() => _InvitacionEscanearState();
}

class _InvitacionEscanearState extends State<_InvitacionEscanear> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: _Cascada(
        orden: 3,
        child: Column(
          children: [
            SizedBox(
              width: 210,
              height: 210,
              child: AnimatedBuilder(
                animation: _loop,
                builder: (context, child) {
                  final t = _loop.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final fase in const [0.0, 0.5])
                        Container(
                          width: 104 + 100 * ((t + fase) % 1),
                          height: 104 + 100 * ((t + fase) % 1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _fuerte.withValues(alpha: 0.22 * (1 - (t + fase) % 1)),
                          ),
                        ),
                      Transform.translate(offset: Offset(0, 5 * math.sin(2 * math.pi * t)), child: child),
                    ],
                  );
                },
                child: Material(
                  color: _fuerte,
                  shape: const CircleBorder(),
                  elevation: 8,
                  shadowColor: _fuerte.withValues(alpha: 0.5),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onEscanear,
                    child: const SizedBox(
                      width: 104,
                      height: 104,
                      child: Icon(Icons.qr_code_scanner, size: 48, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tocá para escanear',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _oscuro),
            ),
            const SizedBox(height: 4),
            const Text(
              'o escribí el nombre arriba',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paso 2 · ¿De dónde sale?
// ---------------------------------------------------------------------------

class _ListaExistencias extends ConsumerWidget {
  const _ListaExistencias({
    required this.idProducto,
    required this.productoNombre,
    required this.onSeleccionar,
  });

  final int idProducto;
  final String productoNombre;
  final ValueChanged<ExistenciaStock> onSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trasladoExistenciasDeProductoProvider(idProducto));

    return Column(
      children: [
        _Titulo(
          titulo: '¿De dónde sale?',
          subtitulo: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Elegí la ubicación y el lote de '),
                TextSpan(text: productoNombre, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _fuerte)),
            error: (e, _) => _Mensaje(describeError(e), icono: Icons.error_outline, color: AppColors.erTx),
            data: (existencias) {
              final disponibles = existencias.where((e) => e.cantidadDisponible > 0).toList();
              if (disponibles.isEmpty) {
                return const _Mensaje('No hay stock disponible para trasladar', icono: Icons.inventory_2_outlined);
              }
              // La(s) que están en la ubicación recomendada del producto van
              // primero — no hay que ir a buscarlas en medio de la lista.
              final ordenadas = [
                ...disponibles.where((e) => e.esUbicacionRecomendada),
                ...disponibles.where((e) => !e.esUbicacionRecomendada),
              ];
              return _listaTarjetas(ordenadas.length, (i) {
                final e = ordenadas[i];
                return _Tarjeta(
                  titulo: _codigoONombre(e.ubicacionNombre, e.ubicacionCodigo),
                  extraTitulo: e.esUbicacionRecomendada ? const _BadgeRecomendada() : null,
                  detalle: 'Lote ${e.loteInterno} · ${e.ubicacionNombre}',
                  pildora: _Pildora(
                    '${e.cantidadDisponible.toStringAsFixed(0)} ${e.unidadSimbolo}',
                    llena: false,
                  ),
                  resaltada: e.esUbicacionRecomendada,
                  onTap: () => onSeleccionar(e),
                );
              });
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
      decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(999)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: _oscuro),
          SizedBox(width: 3),
          Text(
            'Recomendada',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _oscuro),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paso 3 · ¿A dónde va?
// ---------------------------------------------------------------------------

/// Título chico de cada bloque del formulario — mismo estilo que
/// "PENDIENTES DE ACOMODAR" en la demo.
class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
      ),
    );
  }
}

/// Muestra el código si la ubicación tiene uno (es lo que está impreso en la
/// etiqueta física), si no el nombre.
String _codigoONombre(String nombre, String codigo) => codigo.trim().isNotEmpty ? codigo : nombre;

/// Uno de los dos extremos de la ruta origen → destino. El destino se pinta
/// de violeta cuando ya está elegido, como el chip de la demo.
class _ExtremoRuta extends StatelessWidget {
  const _ExtremoRuta({
    required this.etiqueta,
    required this.codigo,
    required this.nombre,
    this.lleno = false,
    this.vacio = false,
  });

  final String etiqueta;
  final String codigo;
  final String nombre;
  final bool lleno;
  final bool vacio;

  @override
  Widget build(BuildContext context) {
    final colorTexto = lleno ? Colors.white : (vacio ? AppColors.faint : AppColors.text);
    final colorSub = lleno ? Colors.white.withValues(alpha: 0.8) : AppColors.muted;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: lleno ? _fuerte : AppColors.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lleno ? _fuerte : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: colorSub, letterSpacing: 0.8),
          ),
          const SizedBox(height: 2),
          Text(
            codigo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colorTexto),
          ),
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colorSub),
          ),
        ],
      ),
    );
  }
}

/// Píldora de la ubicación recomendada, igual a la de la demo: estrella,
/// "Recomendada: X" y un "Usar" blanco que la pone de destino de un toque.
/// Una vez elegida queda con un tilde, para que se vea que el destino actual
/// es el recomendado.
class _PildoraRecomendada extends StatelessWidget {
  const _PildoraRecomendada({
    required this.nombre,
    required this.codigo,
    required this.enUso,
    required this.onUsar,
  });

  final String nombre;
  final String codigo;
  final bool enUso;
  final VoidCallback onUsar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 18, color: _oscuro),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Recomendada: '),
                  TextSpan(text: _codigoONombre(nombre, codigo), style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _oscuro),
            ),
          ),
          if (enUso)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(color: _fuerte, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 17, color: Colors.white),
            )
          else
            Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onUsar,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Usar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _oscuro)),
                ),
              ),
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
    final d = destino;
    final tieneRecomendada = origen.idUbicacionPreferida != null;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            children: [
              const _Titulo(
                titulo: '¿A dónde va?',
                subtitulo: Text('Elegí el destino y cuánto movés.'),
                padding: EdgeInsets.fromLTRB(4, 4, 4, 18),
              ),
              // Tarjeta del traslado: producto + ruta origen → destino, como
              // la hoja que sube en la demo.
              _Cascada(
                orden: 2,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: _fuerte.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              origen.productoNombre,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                            ),
                          ),
                          if (puedeCambiarOrigen)
                            InkWell(
                              onTap: onCambiarOrigen,
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.fromLTRB(8, 2, 2, 2),
                                child: Text(
                                  'Cambiar',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _fuerte),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lote ${origen.loteInterno} · Disponible ${_EjecutarTrasladoScreenState._formatCantidad(origen.cantidadDisponible)} ${origen.unidadSimbolo}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ExtremoRuta(
                              etiqueta: 'DESDE',
                              codigo: _codigoONombre(origen.ubicacionNombre, origen.ubicacionCodigo),
                              nombre: origen.ubicacionNombre,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, size: 18, color: AppColors.faint),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: onElegirDestino,
                              // El destino entra con el mismo saltito elástico
                              // que en la demo cada vez que cambia.
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(d?.idUbicacion),
                                tween: Tween(begin: d == null ? 1 : 0, end: 1),
                                duration: const Duration(milliseconds: 650),
                                curve: Curves.elasticOut,
                                builder: (context, v, child) => Transform.scale(scale: 0.6 + 0.4 * v, child: child),
                                child: d == null
                                    ? const _ExtremoRuta(etiqueta: 'HACIA', codigo: 'Destino', nombre: 'Sin elegir', vacio: true)
                                    : _ExtremoRuta(
                                        etiqueta: 'HACIA',
                                        codigo: _codigoONombre(d.nombre, d.codigo),
                                        nombre: d.nombre,
                                        lleno: true,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _Cascada(
                orden: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Etiqueta('DESTINO'),
                    if (tieneRecomendada) ...[
                      _PildoraRecomendada(
                        nombre: origen.ubicacionPreferidaNombre ?? '',
                        codigo: origen.ubicacionPreferidaCodigo ?? '',
                        enUso: d?.idUbicacion == origen.idUbicacionPreferida,
                        onUsar: onUsarRecomendada,
                      ),
                      const SizedBox(height: 10),
                    ],
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: onElegirDestino,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.location_on_outlined, color: _oscuro, size: 19),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  d == null
                                      ? (tieneRecomendada ? 'Elegir otra ubicación' : 'Buscar o escanear ubicación')
                                      : 'Cambiar destino',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                                ),
                              ),
                              const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.muted),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: AppColors.faint),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Cascada(
                orden: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Etiqueta('CANTIDAD'),
                    TextField(
                      controller: cantidadController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: 'Cantidad a trasladar',
                        filled: true,
                        fillColor: AppColors.surface,
                        suffixText: origen.unidadSimbolo,
                        suffixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _Etiqueta('OBSERVACIÓN'),
                    TextField(
                      controller: observacionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Opcional',
                        filled: true,
                        fillColor: AppColors.surface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Botón píldora fijo abajo, como el de la presentación: gris hasta
        // que haya destino, violeta oscuro después.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: ejecutando ? null : onEjecutar,
              style: FilledButton.styleFrom(
                backgroundColor: d != null ? _oscuro : AppColors.borderStrong,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _oscuro.withValues(alpha: 0.7),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              child: ejecutando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Ejecutar traslado'),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Buscador de ubicación destino
// ---------------------------------------------------------------------------

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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_pastel, AppColors.pageBg],
            stops: [0, 0.35],
          ),
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
                  decoration: BoxDecoration(color: _fuerte.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const Text(
                'Ubicación destino',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              const Text(
                'Escaneá la etiqueta o buscala por nombre.',
                style: TextStyle(fontSize: 14, color: AppColors.sub),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Nombre o código de ubicación...',
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: _fuerte),
                    tooltip: 'Escanear ubicación',
                    onPressed: _escanear,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: _fuerte)),
                  error: (e, _) => _Mensaje(describeError(e), icono: Icons.error_outline, color: AppColors.erTx),
                  data: (items) {
                    if (_controller.text.trim().isEmpty) {
                      return const _Mensaje('Escribí para buscar', icono: Icons.location_on_outlined);
                    }
                    if (items.isEmpty) return const _Mensaje('Sin resultados');
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final u = items[i];
                        final recomendada = u.idUbicacion == widget.idUbicacionRecomendada;
                        return _Tarjeta(
                          titulo: _codigoONombre(u.nombre, u.codigo),
                          extraTitulo: recomendada ? const _BadgeRecomendada() : null,
                          detalle: u.nombre,
                          pildora: const _Pildora('Usar'),
                          resaltada: recomendada,
                          onTap: () => Navigator.of(context).pop(u),
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
