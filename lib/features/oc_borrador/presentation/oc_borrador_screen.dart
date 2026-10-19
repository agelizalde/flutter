import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../../stock/domain/stock_models.dart' show ProveedorSimple;
import '../application/oc_borrador_providers.dart';
import '../domain/oc_borrador_models.dart';

/// Color propio de los pasos 2 y 3 (Productos / Revisar) — distinto del azul
/// de marca del paso 1, mismo criterio que OC simple y POS para diferenciar
/// las etapas de un vistazo, con un tono propio para no confundir este
/// flujo con el carrito de OC simple (violeta).
const _colorProductos = Color(0xFF0F766E);
const _colorProductosSoft = Color(0xFFF0FDFA);

const _diasSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

DateTime _hoy() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _fechaLarga(DateTime f) => '${_diasSemana[f.weekday - 1]} ${formatFecha(f)}';

/// "Nueva OC": arma una orden de compra en BORRADOR desde el depósito, en 3
/// pasos — (1) proveedor + fecha en que se quiere recibir, (2) productos y
/// cantidades (los del proveedor o búsqueda libre), (3) revisar y crear
/// (`POST /compras/oc/borrador-app`, ver `oc_crear_borrador_app.py`). No se
/// carga precio acá: el backend pone el sugerido (última compra aprobada a
/// ese proveedor) y Compras lo revisa, confirma y envía a firma desde la PC.
class OcBorradorScreen extends ConsumerStatefulWidget {
  const OcBorradorScreen({super.key});

  @override
  ConsumerState<OcBorradorScreen> createState() => _OcBorradorScreenState();
}

class _OcBorradorScreenState extends ConsumerState<OcBorradorScreen> {
  final _proveedorSearchController = TextEditingController();
  final _productoSearchController = TextEditingController();
  final _observacionController = TextEditingController();
  Timer? _debounceProveedor;
  Timer? _debounceProducto;

  /// 1 = proveedor y fecha, 2 = productos, 3 = revisar.
  int _paso = 1;
  ProveedorSimple? _proveedor;
  DateTime? _fechaEntrega;
  final List<OcBorradorItem> _items = [];

  /// true = solo productos cuyo proveedor base es el elegido; false =
  /// búsqueda libre en todo el catálogo comprable.
  bool _soloProveedor = true;
  String _qProducto = '';
  bool _guardando = false;

  @override
  void dispose() {
    _debounceProveedor?.cancel();
    _debounceProducto?.cancel();
    _proveedorSearchController.dispose();
    _productoSearchController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  void _onBuscarProveedor(String value) {
    _debounceProveedor?.cancel();
    _debounceProveedor = Timer(const Duration(milliseconds: 400), () {
      ref.read(ocBorradorBusquedaProveedorProvider.notifier).state = value;
    });
  }

  void _onBuscarProducto(String value) {
    _debounceProducto?.cancel();
    _debounceProducto = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _qProducto = value.trim());
    });
  }

  void _elegirProveedor(ProveedorSimple p) {
    setState(() {
      // Cambiar de proveedor deja sin sentido los productos "del proveedor"
      // ya elegidos — se arranca la lista de cero.
      if (_proveedor?.idProveedor != p.idProveedor) _items.clear();
      _proveedor = p;
    });
  }

  void _cambiarProveedor() {
    if (_items.isNotEmpty) {
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Cambiar proveedor?'),
          content: Text('Se van a quitar los ${_items.length} producto(s) ya cargados.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Cambiar')),
          ],
        ),
      ).then((ok) {
        if (ok == true) _resetProveedor();
      });
      return;
    }
    _resetProveedor();
  }

  void _resetProveedor() {
    setState(() {
      _proveedor = null;
      _items.clear();
      _paso = 1;
    });
    _proveedorSearchController.clear();
    ref.read(ocBorradorBusquedaProveedorProvider.notifier).state = '';
  }

  Future<void> _elegirFechaCalendario() async {
    final hoy = _hoy();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega ?? hoy.add(const Duration(days: 1)),
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 1, hoy.month, hoy.day),
      helpText: 'Fecha de entrega',
    );
    if (elegida != null) setState(() => _fechaEntrega = elegida);
  }

  OcBorradorItem? _itemDe(int idProducto) {
    for (final it in _items) {
      if (it.producto.idProducto == idProducto) return it;
    }
    return null;
  }

  Future<void> _editarCantidad(ProductoOcBorrador p) async {
    final actual = _itemDe(p.idProducto);
    final cantidad = await _pedirCantidad(context, p, actual?.cantidad);
    if (cantidad == null || !mounted) return;
    setState(() {
      final idx = _items.indexWhere((it) => it.producto.idProducto == p.idProducto);
      if (cantidad <= 0) {
        if (idx >= 0) _items.removeAt(idx);
      } else if (idx >= 0) {
        _items[idx] = _items[idx].copyWith(cantidad: cantidad);
      } else {
        _items.add(OcBorradorItem(producto: p, cantidad: cantidad));
      }
    });
  }

  void _quitarItem(int idProducto) {
    setState(() => _items.removeWhere((it) => it.producto.idProducto == idProducto));
  }

  void _volverPaso() {
    if (_paso > 1) setState(() => _paso--);
  }

  Future<void> _crearOc() async {
    setState(() => _guardando = true);
    try {
      final resultado = await ref.read(ocBorradorApiProvider).crear(
            idProveedor: _proveedor!.idProveedor,
            fechaEntrega: _fechaEntrega!,
            items: _items,
            observacion: _observacionController.text,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _OcCreadaDialog(resultado: resultado),
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
    if (usuario != null && !usuario.tienePermiso('oc.crear_app')) {
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
              'No tenés permiso para crear órdenes de compra.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final Widget cuerpo = switch (_paso) {
      1 => _PasoProveedorFecha(
          proveedor: _proveedor,
          fechaEntrega: _fechaEntrega,
          proveedorSearchController: _proveedorSearchController,
          onBuscarProveedor: _onBuscarProveedor,
          onElegirProveedor: _elegirProveedor,
          onCambiarProveedor: _cambiarProveedor,
          onElegirFecha: (f) => setState(() => _fechaEntrega = f),
          onElegirFechaCalendario: _elegirFechaCalendario,
          onContinuar: () => setState(() => _paso = 2),
        ),
      2 => _PasoProductos(
          proveedor: _proveedor!,
          fechaEntrega: _fechaEntrega!,
          items: _items,
          soloProveedor: _soloProveedor,
          qProducto: _qProducto,
          productoSearchController: _productoSearchController,
          onCambiarModo: (v) => setState(() => _soloProveedor = v),
          onBuscarProducto: _onBuscarProducto,
          onTapProducto: _editarCantidad,
          onEditarCabecera: () => setState(() => _paso = 1),
          onContinuar: () => setState(() => _paso = 3),
        ),
      _ => _PasoRevisar(
          proveedor: _proveedor!,
          fechaEntrega: _fechaEntrega!,
          items: _items,
          observacionController: _observacionController,
          guardando: _guardando,
          onEditarCabecera: () => setState(() => _paso = 1),
          onAgregarMas: () => setState(() => _paso = 2),
          onEditarItem: (it) => _editarCantidad(it.producto),
          onQuitarItem: _quitarItem,
          onCrear: _crearOc,
        ),
    };

    return PopScope(
      canPop: _paso == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volverPaso();
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: _paso == 1 ? 'Volver al menú principal' : 'Paso anterior',
            onPressed: _paso == 1 ? () => context.go('/') : _volverPaso,
          ),
          title: const Text('Nueva OC'),
        ),
        body: Column(
          children: [
            _EtapasHeader(pasoActual: _paso),
            Expanded(child: cuerpo),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// ETAPAS
// =========================================================

/// Barra de etapas — mismo patrón que `oc_simple_screen.dart::_EtapasHeader`
/// pero con 3 pasos y versión compacta (solo título) para que entre en un
/// celular angosto.
class _EtapasHeader extends StatelessWidget {
  const _EtapasHeader({required this.pasoActual});

  final int pasoActual;

  @override
  Widget build(BuildContext context) {
    Widget conector(int despuesDe) => Container(
          width: 18,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: pasoActual > despuesDe ? _colorProductos : AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        );

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: _Etapa(
              titulo: 'Proveedor',
              icono: Icons.local_shipping_outlined,
              color: AppColors.accent,
              colorSoft: AppColors.accentSoft,
              activa: pasoActual == 1,
              completada: pasoActual > 1,
            ),
          ),
          conector(1),
          Expanded(
            child: _Etapa(
              titulo: 'Productos',
              icono: Icons.inventory_2_outlined,
              color: _colorProductos,
              colorSoft: _colorProductosSoft,
              activa: pasoActual == 2,
              completada: pasoActual > 2,
            ),
          ),
          conector(2),
          Expanded(
            child: _Etapa(
              titulo: 'Revisar',
              icono: Icons.fact_check_outlined,
              color: _colorProductos,
              colorSoft: _colorProductosSoft,
              activa: pasoActual == 3,
              completada: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _Etapa extends StatelessWidget {
  const _Etapa({
    required this.titulo,
    required this.icono,
    required this.color,
    required this.colorSoft,
    required this.activa,
    required this.completada,
  });

  final String titulo;
  final IconData icono;
  final Color color;
  final Color colorSoft;
  final bool activa;
  final bool completada;

  @override
  Widget build(BuildContext context) {
    final destacada = activa || completada;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: activa ? colorSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: activa ? color.withValues(alpha: 0.35) : Colors.transparent, width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: destacada ? color : AppColors.faint.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: completada
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Icon(icono, size: 13, color: destacada ? Colors.white : AppColors.muted),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: destacada ? AppColors.text : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// PASO 1 — PROVEEDOR Y FECHA
// =========================================================

class _PasoProveedorFecha extends ConsumerWidget {
  const _PasoProveedorFecha({
    required this.proveedor,
    required this.fechaEntrega,
    required this.proveedorSearchController,
    required this.onBuscarProveedor,
    required this.onElegirProveedor,
    required this.onCambiarProveedor,
    required this.onElegirFecha,
    required this.onElegirFechaCalendario,
    required this.onContinuar,
  });

  final ProveedorSimple? proveedor;
  final DateTime? fechaEntrega;
  final TextEditingController proveedorSearchController;
  final ValueChanged<String> onBuscarProveedor;
  final ValueChanged<ProveedorSimple> onElegirProveedor;
  final VoidCallback onCambiarProveedor;
  final ValueChanged<DateTime> onElegirFecha;
  final VoidCallback onElegirFechaCalendario;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (proveedor == null) {
      return _BuscadorProveedor(
        controller: proveedorSearchController,
        onChanged: onBuscarProveedor,
        onSeleccionar: onElegirProveedor,
      );
    }

    final hoy = _hoy();
    final atajos = <(String, DateTime)>[
      ('Mañana', hoy.add(const Duration(days: 1))),
      ('En 3 días', hoy.add(const Duration(days: 3))),
      ('En 1 semana', hoy.add(const Duration(days: 7))),
      ('En 2 semanas', hoy.add(const Duration(days: 14))),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              _ProveedorRecap(proveedor: proveedor!, onCambiar: onCambiarProveedor),
              const SizedBox(height: 24),
              const _TituloSeccion(icono: Icons.event_outlined, texto: '¿CUÁNDO QUERÉS QUE TE ENTREGUEN?'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, fecha) in atajos)
                    ChoiceChip(
                      label: Text(label),
                      selected: fechaEntrega == fecha,
                      onSelected: (_) => onElegirFecha(fecha),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onElegirFechaCalendario,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: fechaEntrega != null ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, color: AppColors.accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fecha de entrega',
                                style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                fechaEntrega != null ? _fechaLarga(fechaEntrega!) : 'Elegir en el calendario',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: fechaEntrega != null ? AppColors.text : AppColors.faint,
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
              ),
            ],
          ),
        ),
        _BottomBar(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: fechaEntrega != null ? onContinuar : null,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: Text(fechaEntrega != null ? 'Elegir productos' : 'Elegí la fecha de entrega'),
            ),
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
    final async = ref.watch(ocBorradorResultadosProveedorProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
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
                return const _EstadoVacio(
                  icono: Icons.local_shipping_outlined,
                  texto: 'Escribí para buscar el proveedor',
                );
              }
              if (items.isEmpty) {
                return const _EstadoVacio(icono: Icons.search_off, texto: 'Sin resultados');
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                              child: const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.razonSocial,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.text),
                                  ),
                                  Text(p.codigoProveedor, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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

class _ProveedorRecap extends StatelessWidget {
  const _ProveedorRecap({required this.proveedor, required this.onCambiar});

  final ProveedorSimple proveedor;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROVEEDOR',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accentDark, letterSpacing: .6),
                ),
                const SizedBox(height: 2),
                Text(
                  proveedor.razonSocial,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.text),
                ),
                Text(proveedor.codigoProveedor, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          TextButton(onPressed: onCambiar, child: const Text('Cambiar')),
        ],
      ),
    );
  }
}

// =========================================================
// PASO 2 — PRODUCTOS
// =========================================================

class _PasoProductos extends ConsumerWidget {
  const _PasoProductos({
    required this.proveedor,
    required this.fechaEntrega,
    required this.items,
    required this.soloProveedor,
    required this.qProducto,
    required this.productoSearchController,
    required this.onCambiarModo,
    required this.onBuscarProducto,
    required this.onTapProducto,
    required this.onEditarCabecera,
    required this.onContinuar,
  });

  final ProveedorSimple proveedor;
  final DateTime fechaEntrega;
  final List<OcBorradorItem> items;
  final bool soloProveedor;
  final String qProducto;
  final TextEditingController productoSearchController;
  final ValueChanged<bool> onCambiarModo;
  final ValueChanged<String> onBuscarProducto;
  final ValueChanged<ProductoOcBorrador> onTapProducto;
  final VoidCallback onEditarCabecera;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busqueda = (q: qProducto, idProveedor: soloProveedor ? proveedor.idProveedor : null);
    final resultados = ref.watch(ocBorradorResultadosProductoProvider(busqueda));
    final cantidades = {for (final it in items) it.producto.idProducto: it};

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Column(
            children: [
              _CabeceraCompacta(proveedor: proveedor, fechaEntrega: fechaEntrega, onTap: onEditarCabecera),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Del proveedor'), icon: Icon(Icons.local_shipping_outlined, size: 16)),
                    ButtonSegment(value: false, label: Text('Todos'), icon: Icon(Icons.travel_explore, size: 16)),
                  ],
                  selected: {soloProveedor},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => onCambiarModo(s.first),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: productoSearchController,
                onChanged: onBuscarProducto,
                decoration: InputDecoration(
                  hintText: soloProveedor ? 'Filtrar productos del proveedor...' : 'Buscar por nombre, código o barra...',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: resultados.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
              ),
            ),
            data: (productos) {
              if (!soloProveedor && qProducto.isEmpty) {
                return const _EstadoVacio(
                  icono: Icons.travel_explore,
                  texto: 'Escribí para buscar en todo el catálogo',
                );
              }
              if (productos.isEmpty) {
                return _EstadoVacio(
                  icono: Icons.search_off,
                  texto: soloProveedor
                      ? (qProducto.isEmpty
                          ? 'Este proveedor no tiene productos asignados como proveedor base.\nProbá con "Todos".'
                          : 'Sin resultados entre los productos del proveedor')
                      : 'Sin resultados',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                itemCount: productos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = productos[i];
                  return _ProductoTile(
                    producto: p,
                    item: cantidades[p.idProducto],
                    // En "Todos" se avisa si el producto tiene otro proveedor
                    // base — no se bloquea (puede comprarse a otro), pero
                    // ayuda a no equivocarse.
                    otroProveedor: !soloProveedor &&
                            p.idProveedorCabecera != null &&
                            p.idProveedorCabecera != proveedor.idProveedor
                        ? p.proveedorNombre
                        : null,
                    onTap: () => onTapProducto(p),
                  );
                },
              );
            },
          ),
        ),
        _BottomBar(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Productos', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    Text(
                      '${items.length}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: items.isNotEmpty ? onContinuar : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _colorProductos),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('Revisar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CabeceraCompacta extends StatelessWidget {
  const _CabeceraCompacta({required this.proveedor, required this.fechaEntrega, required this.onTap});

  final ProveedorSimple proveedor;
  final DateTime fechaEntrega;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proveedor.razonSocial,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.text),
                    ),
                    Text(
                      'Entrega: ${_fechaLarga(fechaEntrega)}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.accentDark, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 16, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductoTile extends StatelessWidget {
  const _ProductoTile({
    required this.producto,
    required this.item,
    required this.otroProveedor,
    required this.onTap,
  });

  final ProductoOcBorrador producto;
  final OcBorradorItem? item;
  final String? otroProveedor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final agregado = item != null;
    final subtitulo = [
      producto.codigoInterno,
      if (producto.marcaNombre != null && producto.marcaNombre!.isNotEmpty) producto.marcaNombre!,
    ].join(' · ');

    return Material(
      color: agregado ? _colorProductosSoft : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: agregado ? _colorProductos.withValues(alpha: 0.35) : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    if (otroProveedor != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Proveedor base: $otroProveedor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.waTx, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (agregado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _colorProductos, borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    item!.cantidadTexto,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: _colorProductosSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 18, color: _colorProductos),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================
// PASO 3 — REVISAR Y CREAR
// =========================================================

class _PasoRevisar extends StatelessWidget {
  const _PasoRevisar({
    required this.proveedor,
    required this.fechaEntrega,
    required this.items,
    required this.observacionController,
    required this.guardando,
    required this.onEditarCabecera,
    required this.onAgregarMas,
    required this.onEditarItem,
    required this.onQuitarItem,
    required this.onCrear,
  });

  final ProveedorSimple proveedor;
  final DateTime fechaEntrega;
  final List<OcBorradorItem> items;
  final TextEditingController observacionController;
  final bool guardando;
  final VoidCallback onEditarCabecera;
  final VoidCallback onAgregarMas;
  final ValueChanged<OcBorradorItem> onEditarItem;
  final ValueChanged<int> onQuitarItem;
  final Future<void> Function() onCrear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              _CabeceraCompacta(proveedor: proveedor, fechaEntrega: fechaEntrega, onTap: onEditarCabecera),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TituloSeccion(icono: Icons.inventory_2_outlined, texto: 'PRODUCTOS (${items.length})'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onAgregarMas,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (items.isEmpty)
                const _EstadoVacio(icono: Icons.inventory_2_outlined, texto: 'No hay productos cargados', compacto: true)
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.border),
                        _ItemRevisarTile(
                          item: items[i],
                          onEditar: () => onEditarItem(items[i]),
                          onQuitar: () => onQuitarItem(items[i].producto.idProducto),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              TextField(
                controller: observacionController,
                maxLines: 3,
                minLines: 2,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Observación (opcional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.inBg, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppColors.inTx),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La OC queda en BORRADOR. Compras revisa los precios desde la PC, '
                        'la confirma y la envía a firma.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.inTx, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _BottomBar(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: items.isNotEmpty && !guardando ? onCrear : null,
              style: ElevatedButton.styleFrom(backgroundColor: _colorProductos),
              icon: guardando
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(guardando ? 'Creando...' : 'Crear OC en borrador'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemRevisarTile extends StatelessWidget {
  const _ItemRevisarTile({required this.item, required this.onEditar, required this.onQuitar});

  final OcBorradorItem item;
  final VoidCallback onEditar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEditar,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.producto.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
                  ),
                  Text(item.producto.codigoInterno, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.cantidadTexto,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _colorProductos),
            ),
            IconButton(
              onPressed: onQuitar,
              icon: const Icon(Icons.close, size: 18, color: AppColors.faint),
              tooltip: 'Quitar',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================
// CANTIDAD
// =========================================================

/// Diálogo de cantidad para un producto. Devuelve la cantidad elegida,
/// `0` si se tocó "Quitar" (solo aparece si ya estaba cargado) o `null` si
/// se canceló. Decimales solo si la unidad es pesable (kg, litros...).
Future<double?> _pedirCantidad(BuildContext context, ProductoOcBorrador p, double? actual) {
  return showDialog<double>(
    context: context,
    builder: (context) => _CantidadDialog(producto: p, actual: actual),
  );
}

class _CantidadDialog extends StatefulWidget {
  const _CantidadDialog({required this.producto, required this.actual});

  final ProductoOcBorrador producto;
  final double? actual;

  @override
  State<_CantidadDialog> createState() => _CantidadDialogState();
}

class _CantidadDialogState extends State<_CantidadDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final inicial = widget.actual ?? 1;
    _controller = TextEditingController(text: formatCantidad(inicial, pesable: widget.producto.unidadPesable));
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? get _valor => double.tryParse(_controller.text.replaceAll(',', '.'));

  void _sumar(double delta) {
    final nuevo = ((_valor ?? 0) + delta).clamp(0, double.infinity).toDouble();
    setState(() {
      _controller.text = formatCantidad(nuevo, pesable: widget.producto.unidadPesable);
    });
  }

  void _confirmar() {
    final v = _valor;
    if (v == null || v <= 0) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.producto;
    final valido = (_valor ?? 0) > 0;
    return AlertDialog(
      title: Text(p.nombre, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(p.codigoInterno, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton.filledTonal(onPressed: () => _sumar(-1), icon: const Icon(Icons.remove)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  keyboardType: TextInputType.numberWithOptions(decimal: p.unidadPesable),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(p.unidadPesable ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]')),
                  ],
                  decoration: InputDecoration(suffixText: p.unidadSimbolo),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _confirmar(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: () => _sumar(1), icon: const Icon(Icons.add)),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.actual != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(0.0),
            style: TextButton.styleFrom(foregroundColor: AppColors.erTx),
            child: const Text('Quitar'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: valido ? _confirmar : null,
          style: FilledButton.styleFrom(backgroundColor: _colorProductos),
          child: Text(widget.actual != null ? 'Guardar' : 'Agregar'),
        ),
      ],
    );
  }
}

// =========================================================
// COMUNES
// =========================================================

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: AppColors.text),
        ),
      ],
    );
  }
}

/// Barra fija al fondo (footer con sombra hacia arriba), mismo patrón que
/// `oc_simple_screen.dart::_BottomBar`.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      child: child,
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icono, required this.texto, this.compacto = false});

  final IconData icono;
  final String texto;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final contenido = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: compacto ? 26 : 40, color: AppColors.faint),
        SizedBox(height: compacto ? 8 : 12),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: compacto ? 12.5 : 14),
        ),
      ],
    );
    return compacto
        ? Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: contenido)
        : Center(child: Padding(padding: const EdgeInsets.all(24), child: contenido));
  }
}

class _OcCreadaDialog extends StatelessWidget {
  const _OcCreadaDialog({required this.resultado});

  final OcBorradorResultado resultado;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: _colorProductosSoft, shape: BoxShape.circle),
        child: const Icon(Icons.check_circle, color: _colorProductos, size: 28),
      ),
      title: const Text('OC creada', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            resultado.codigo,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(999)),
            child: const Text(
              'En borrador',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.waTx),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Falta que Compras revise los precios, la confirme y la envíe a firma desde la PC.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: _colorProductos),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
