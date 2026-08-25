import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../../core/widgets/picker_field.dart';
import '../../../core/widgets/selector_sheet.dart';
import '../../auth/application/auth_controller.dart';
import '../../pedidos/domain/pedido_models.dart' show ClienteSimple, SucursalSimple;
import '../application/pos_providers.dart';
import '../domain/pos_models.dart';

/// Color propio del paso 2 (Productos/Carrito) — distinto del azul de marca
/// (`AppColors.accent`, usado para el paso 1 y las acciones primarias) para
/// que las dos etapas del flujo se puedan diferenciar de un vistazo, tal
/// como pidió el usuario ("gerarquizar con colores").
const _colorProductos = Color(0xFF0D9488);
const _colorProductosSoft = Color(0xFFF0FDFA);

/// Punto de Venta — carrito de mostrador en 2 etapas bien diferenciadas
/// (ver `pos_venta_service.py`):
///   1. Cliente y sucursal — se completa entera antes de pasar a la 2.
///   2. Productos — buscando por nombre o escaneando el código de barra
///      (`BarcodeScannerScreen`, mismo widget que usa el buscador del Home).
/// Sin precio (se completa en Administración después) y sin pantalla de
/// detalle: al confirmar se muestra un resumen y el carrito queda listo
/// para la próxima venta — es una caja registradora, se usa seguido.
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _clienteSearchController = TextEditingController();
  final _productoSearchController = TextEditingController();
  Timer? _debounceCliente;
  Timer? _debounceProducto;

  /// 1 = eligiendo cliente/sucursal, 2 = armando el carrito. Separado de
  /// `_cliente` a propósito: permite volver del paso 2 al 1 para corregir
  /// la sucursal sin perder el cliente ya elegido (botón "Editar").
  int _paso = 1;

  ClienteSimple? _cliente;
  SucursalSimple? _sucursal;
  final List<PosCartItem> _carrito = [];
  bool _guardando = false;
  bool _buscandoEscaneo = false;

  @override
  void dispose() {
    _debounceCliente?.cancel();
    _debounceProducto?.cancel();
    _clienteSearchController.dispose();
    _productoSearchController.dispose();
    super.dispose();
  }

  void _onBuscarCliente(String value) {
    _debounceCliente?.cancel();
    _debounceCliente = Timer(const Duration(milliseconds: 400), () {
      ref.read(posBusquedaClienteProvider.notifier).state = value;
    });
  }

  void _onBuscarProducto(String value) {
    _debounceProducto?.cancel();
    _debounceProducto = Timer(const Duration(milliseconds: 400), () {
      ref.read(posBusquedaProductoProvider.notifier).state = value;
    });
  }

  void _elegirCliente(ClienteSimple c) {
    setState(() {
      _cliente = c;
      _sucursal = null;
    });
  }

  void _cambiarCliente() {
    setState(() {
      _cliente = null;
      _sucursal = null;
    });
    _clienteSearchController.clear();
    ref.read(posBusquedaClienteProvider.notifier).state = '';
  }

  Future<void> _elegirSucursal() async {
    final idCliente = _cliente!.idCliente;
    final elegida = await showSelectorSheet<SucursalSimple>(
      context,
      titulo: 'Elegir sucursal',
      cargar: (q) async {
        final todas = await ref.read(posRepositoryProvider).sucursalesDeCliente(idCliente);
        if (q.isEmpty) return todas;
        final ql = q.toLowerCase();
        return todas.where((s) => s.nombre.toLowerCase().contains(ql)).toList();
      },
      etiqueta: (s) => s.nombre,
      seleccionado: _sucursal,
      esIgual: (s) => s.idSucursal == _sucursal?.idSucursal,
    );
    if (elegida != null) setState(() => _sucursal = elegida);
  }

  void _continuarAProductos() => setState(() => _paso = 2);

  void _volverACliente() => setState(() => _paso = 1);

  /// Agrega `p` al carrito. Si su unidad es pesable (ej. carne por kg, ver
  /// `ProductoPosSimple.unidadPesable`) no suma "1" a ciegas como un
  /// paquete de arroz: abre `_PesoSheet` para que el usuario tipee el peso
  /// real de la báscula. Devuelve `false` si el usuario canceló el pesaje,
  /// para que los callers (buscador/escáner) sepan que no hay nada que
  /// limpiar/festejar.
  Future<bool> _agregarProducto(ProductoPosSimple p) async {
    var cantidadAAgregar = 1.0;
    if (p.unidadPesable) {
      final peso = await _pedirPeso(productoNombre: p.nombre, unidadSimbolo: p.unidadSimbolo);
      if (peso == null || peso <= 0 || !mounted) return false;
      cantidadAAgregar = peso;
    }
    setState(() {
      final idx = _carrito.indexWhere((it) => it.producto.idProducto == p.idProducto);
      if (idx >= 0) {
        _carrito[idx] = _carrito[idx].copyWith(cantidad: _carrito[idx].cantidad + cantidadAAgregar);
      } else {
        _carrito.add(PosCartItem(producto: p, cantidad: cantidadAAgregar));
      }
    });
    return true;
  }

  void _agregarProductoDesdeBuscador(ProductoPosSimple p) {
    _agregarProducto(p).then((agregado) {
      if (!agregado || !mounted) return;
      _productoSearchController.clear();
      ref.read(posBusquedaProductoProvider.notifier).state = '';
    });
  }

  Future<void> _escanearProducto() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    setState(() => _buscandoEscaneo = true);
    try {
      final producto = await ref.read(posRepositoryProvider).buscarPorCodigoBarra(codigo);
      if (!mounted) return;
      final agregado = await _agregarProducto(producto);
      if (!agregado || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${producto.nombre} agregado al carrito'),
          duration: const Duration(seconds: 2),
          backgroundColor: _colorProductos,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _buscandoEscaneo = false);
    }
  }

  void _cambiarCantidad(int idProducto, double delta) {
    setState(() {
      final idx = _carrito.indexWhere((it) => it.producto.idProducto == idProducto);
      if (idx < 0) return;
      final nueva = _carrito[idx].cantidad + delta;
      if (nueva <= 0) {
        _carrito.removeAt(idx);
      } else {
        _carrito[idx] = _carrito[idx].copyWith(cantidad: nueva);
      }
    });
  }

  /// Reemplaza el peso de un ítem pesable ya en el carrito (a diferencia de
  /// `_cambiarCantidad`, que suma/resta de a 1 — no tiene sentido para kg).
  /// Reabre `_PesoSheet` con el valor actual precargado para corregirlo.
  void _editarPeso(PosCartItem item) {
    _pedirPeso(
      productoNombre: item.producto.nombre,
      unidadSimbolo: item.producto.unidadSimbolo,
      valorInicial: item.cantidad,
    ).then((peso) {
      if (peso == null || !mounted) return;
      setState(() {
        final idx = _carrito.indexWhere((it) => it.producto.idProducto == item.producto.idProducto);
        if (idx < 0) return;
        if (peso <= 0) {
          _carrito.removeAt(idx);
        } else {
          _carrito[idx] = _carrito[idx].copyWith(cantidad: peso);
        }
      });
    });
  }

  Future<double?> _pedirPeso({
    required String productoNombre,
    required String unidadSimbolo,
    double? valorInicial,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PesoSheet(
        productoNombre: productoNombre,
        unidadSimbolo: unidadSimbolo,
        valorInicial: valorInicial,
      ),
    );
  }

  void _quitarProducto(int idProducto) {
    setState(() => _carrito.removeWhere((it) => it.producto.idProducto == idProducto));
  }

  bool get _puedeConfirmar => _cliente != null && _carrito.isNotEmpty && !_guardando;

  Future<void> _confirmarVenta() async {
    setState(() => _guardando = true);
    try {
      final resultado = await ref.read(posRepositoryProvider).crearVenta(
        idCliente: _cliente!.idCliente,
        idClienteSucursal: _sucursal?.idSucursal,
        items: _carrito,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _VentaConfirmadaDialog(resultado: resultado),
      );
      if (!mounted) return;
      setState(() {
        _cliente = null;
        _sucursal = null;
        _carrito.clear();
        _paso = 1;
      });
      _clienteSearchController.clear();
      ref.read(posBusquedaClienteProvider.notifier).state = '';
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
    if (usuario != null && !usuario.tienePermiso('pos.vender')) {
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
              'No tenés permiso para operar el Punto de venta.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final puntoVentaAsync = ref.watch(miPuntoVentaProvider);

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver al menú principal',
          onPressed: () => context.go('/'),
        ),
        title: puntoVentaAsync.maybeWhen(
          data: (pv) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Punto de venta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                pv.nombre,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          orElse: () => const Text('Punto de venta'),
        ),
      ),
      body: puntoVentaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.point_of_sale_outlined, size: 40, color: AppColors.faint),
                const SizedBox(height: 12),
                Text(
                  describeError(e),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        data: (puntoVenta) => Column(
          children: [
            _EtapasHeader(paso: _paso),
            Expanded(
              child: _paso == 1
                  ? _PasoCliente(
                      cliente: _cliente,
                      sucursal: _sucursal,
                      searchController: _clienteSearchController,
                      onBuscarChanged: _onBuscarCliente,
                      onSeleccionarCliente: _elegirCliente,
                      onCambiarCliente: _cambiarCliente,
                      onElegirSucursal: _elegirSucursal,
                      onContinuar: _continuarAProductos,
                    )
                  : _PasoProductos(
                      cliente: _cliente!,
                      sucursal: _sucursal,
                      carrito: _carrito,
                      productoSearchController: _productoSearchController,
                      guardando: _guardando,
                      buscandoEscaneo: _buscandoEscaneo,
                      puedeConfirmar: _puedeConfirmar,
                      onEditarCliente: _volverACliente,
                      onBuscarProducto: _onBuscarProducto,
                      onAgregarProducto: _agregarProductoDesdeBuscador,
                      onEscanear: _escanearProducto,
                      onCambiarCantidad: _cambiarCantidad,
                      onEditarPeso: _editarPeso,
                      onQuitarProducto: _quitarProducto,
                      onConfirmar: _confirmarVenta,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de etapas — dos "píldoras" conectadas por una línea, con estado
/// claro (pendiente / activa / completada) reforzado con color de fondo,
/// borde y ícono, no solo con el número. Vive en su propia tarjeta blanca
/// para separarse visualmente del contenido de abajo.
class _EtapasHeader extends StatelessWidget {
  const _EtapasHeader({required this.paso});

  final int paso;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: _Etapa(
              numero: 1,
              titulo: 'Cliente',
              subtitulo: 'y sucursal',
              icono: Icons.storefront_outlined,
              color: AppColors.accent,
              colorSoft: AppColors.accentSoft,
              activa: paso == 1,
              completada: paso > 1,
            ),
          ),
          Container(
            width: 28,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: paso > 1 ? _colorProductos : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: _Etapa(
              numero: 2,
              titulo: 'Productos',
              subtitulo: 'buscar o escanear',
              icono: Icons.shopping_basket_outlined,
              color: _colorProductos,
              colorSoft: _colorProductosSoft,
              activa: paso == 2,
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
    required this.numero,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.colorSoft,
    required this.activa,
    required this.completada,
  });

  final int numero;
  final String titulo;
  final String subtitulo;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: activa ? colorSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activa ? color.withValues(alpha: 0.35) : Colors.transparent, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: destacada ? color : AppColors.faint.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: completada
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Icon(icono, size: 15, color: destacada ? Colors.white : AppColors.muted),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: destacada ? AppColors.text : AppColors.muted,
                  ),
                ),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: destacada ? color : AppColors.faint, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// PASO 1 — CLIENTE Y SUCURSAL
// =========================================================

class _PasoCliente extends ConsumerWidget {
  const _PasoCliente({
    required this.cliente,
    required this.sucursal,
    required this.searchController,
    required this.onBuscarChanged,
    required this.onSeleccionarCliente,
    required this.onCambiarCliente,
    required this.onElegirSucursal,
    required this.onContinuar,
  });

  final ClienteSimple? cliente;
  final SucursalSimple? sucursal;
  final TextEditingController searchController;
  final ValueChanged<String> onBuscarChanged;
  final ValueChanged<ClienteSimple> onSeleccionarCliente;
  final VoidCallback onCambiarCliente;
  final VoidCallback onElegirSucursal;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cliente != null) {
      return _ClienteYSucursalRecap(
        cliente: cliente!,
        sucursal: sucursal,
        onCambiarCliente: onCambiarCliente,
        onElegirSucursal: onElegirSucursal,
        onContinuar: onContinuar,
      );
    }

    final async = ref.watch(posResultadosClienteProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: TextField(
            controller: searchController,
            autofocus: true,
            onChanged: onBuscarChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar cliente por nombre...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            data: (items) {
              if (searchController.text.trim().isEmpty) {
                return const _EstadoVacio(
                  icono: Icons.person_search_outlined,
                  texto: 'Escribí el nombre del cliente para empezar la venta',
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
                  final c = items[i];
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSeleccionarCliente(c),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                              child: const Icon(Icons.person_outline, size: 18, color: AppColors.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                c.etiqueta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.text),
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

/// Recapitulación del cliente ya elegido + selector de sucursal + botón
/// "Continuar" fijo abajo — recién ahí se pasa a la etapa 2, tal como pidió
/// el usuario ("se selecciona cliente y sucursal" como un solo paso
/// completo, no dos pantallas sueltas).
class _ClienteYSucursalRecap extends StatelessWidget {
  const _ClienteYSucursalRecap({
    required this.cliente,
    required this.sucursal,
    required this.onCambiarCliente,
    required this.onElegirSucursal,
    required this.onContinuar,
  });

  final ClienteSimple cliente;
  final SucursalSimple? sucursal;
  final VoidCallback onCambiarCliente;
  final VoidCallback onElegirSucursal;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            children: [
              Container(
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
                      child: const Icon(Icons.storefront_outlined, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CLIENTE',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.accentDark, letterSpacing: .6),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cliente.etiqueta,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.text),
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: onCambiarCliente, child: const Text('Cambiar')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'SUCURSAL (OPCIONAL)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              PickerField(
                label: 'Sucursal',
                value: sucursal?.nombre,
                placeholder: 'Sin asignar',
                onTap: onElegirSucursal,
              ),
            ],
          ),
        ),
        _BottomBar(
          child: ElevatedButton.icon(
            onPressed: onContinuar,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Continuar a productos'),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// PASO 2 — PRODUCTOS Y CARRITO
// =========================================================

class _PasoProductos extends ConsumerWidget {
  const _PasoProductos({
    required this.cliente,
    required this.sucursal,
    required this.carrito,
    required this.productoSearchController,
    required this.guardando,
    required this.buscandoEscaneo,
    required this.puedeConfirmar,
    required this.onEditarCliente,
    required this.onBuscarProducto,
    required this.onAgregarProducto,
    required this.onEscanear,
    required this.onCambiarCantidad,
    required this.onEditarPeso,
    required this.onQuitarProducto,
    required this.onConfirmar,
  });

  final ClienteSimple cliente;
  final SucursalSimple? sucursal;
  final List<PosCartItem> carrito;
  final TextEditingController productoSearchController;
  final bool guardando;
  final bool buscandoEscaneo;
  final bool puedeConfirmar;
  final VoidCallback onEditarCliente;
  final ValueChanged<String> onBuscarProducto;
  final ValueChanged<ProductoPosSimple> onAgregarProducto;
  final Future<void> Function() onEscanear;
  final void Function(int idProducto, double delta) onCambiarCantidad;
  final ValueChanged<PosCartItem> onEditarPeso;
  final ValueChanged<int> onQuitarProducto;
  final Future<void> Function() onConfirmar;

  double get _totalUnidades => carrito.fold(0, (acc, it) => acc + it.cantidad);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultadosProducto = ref.watch(posResultadosProductoProvider);
    final qProducto = productoSearchController.text.trim();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              // Chip compacto del cliente elegido — editable sin perder el
              // carrito ya armado (a diferencia de "Cambiar" del paso 1).
              Material(
                color: AppColors.soft,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onEditarCliente,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sucursal != null ? '${cliente.etiqueta} · ${sucursal!.nombre}' : cliente.etiqueta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text),
                          ),
                        ),
                        const Icon(Icons.edit_outlined, size: 15, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Buscador + escaneo ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: productoSearchController,
                      onChanged: onBuscarProducto,
                      decoration: const InputDecoration(
                        hintText: 'Buscar producto...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _BotonEscanear(cargando: buscandoEscaneo, onTap: onEscanear),
                ],
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
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: items
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _ProductoResultadoTile(producto: p, onTap: () => onAgregarProducto(p)),
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // ── Carrito ──
              Row(
                children: [
                  const Icon(Icons.shopping_basket_outlined, size: 16, color: _colorProductos),
                  const SizedBox(width: 6),
                  const Text(
                    'CARRITO',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .8, color: AppColors.text),
                  ),
                  const SizedBox(width: 8),
                  if (carrito.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _colorProductosSoft, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        '${carrito.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _colorProductos),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: carrito.isEmpty ? AppColors.border : _colorProductos.withValues(alpha: 0.18)),
                ),
                padding: carrito.isEmpty ? const EdgeInsets.symmetric(vertical: 28) : const EdgeInsets.all(10),
                child: carrito.isEmpty
                    ? const _EstadoVacio(
                        icono: Icons.qr_code_scanner,
                        texto: 'Buscá o escaneá un producto para agregarlo',
                        compacto: true,
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < carrito.length; i++) ...[
                            _CarritoItemTile(
                              item: carrito[i],
                              onSumar: () => onCambiarCantidad(carrito[i].producto.idProducto, 1),
                              onRestar: () => onCambiarCantidad(carrito[i].producto.idProducto, -1),
                              onEditarPeso: () => onEditarPeso(carrito[i]),
                              onQuitar: () => onQuitarProducto(carrito[i].producto.idProducto),
                            ),
                            if (i < carrito.length - 1) const Divider(height: 1, color: AppColors.border),
                          ],
                        ],
                      ),
              ),
            ],
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
                    Text(
                      '${carrito.length} producto(s)',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${_formatNumero(_totalUnidades)} unidad(es)',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: puedeConfirmar ? onConfirmar : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _colorProductos),
                  icon: guardando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.point_of_sale_outlined, size: 18),
                  label: Text(guardando ? 'Confirmando...' : 'Confirmar venta'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotonEscanear extends StatelessWidget {
  const _BotonEscanear({required this.cargando, required this.onTap});

  final bool cargando;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _colorProductos,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: cargando ? null : onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: cargando
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ProductoResultadoTile extends StatelessWidget {
  const _ProductoResultadoTile({required this.producto, required this.onTap});

  final ProductoPosSimple producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    Text(
                      '${producto.codigoInterno} · ${producto.unidadSimbolo}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
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

class _CarritoItemTile extends StatelessWidget {
  const _CarritoItemTile({
    required this.item,
    required this.onSumar,
    required this.onRestar,
    required this.onEditarPeso,
    required this.onQuitar,
  });

  final PosCartItem item;
  final VoidCallback onSumar;
  final VoidCallback onRestar;
  final VoidCallback onEditarPeso;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final pesable = item.producto.unidadPesable;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
                ),
                Text(
                  item.producto.unidadSimbolo,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          // Pesable (ej. carne por kg): no tiene sentido sumar/restar de a 1
          // kg con el stepper, así que en su lugar se muestra un chip con el
          // peso cargado que reabre `_PesoSheet` para corregirlo a mano.
          if (pesable)
            _PesoChip(
              texto: '${formatCantidad(item.cantidad, pesable: true)} ${item.producto.unidadSimbolo}',
              onTap: onEditarPeso,
            )
          else
            Container(
              decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(999)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepperBtn(icono: Icons.remove, onTap: onRestar),
                  SizedBox(
                    width: 26,
                    child: Text(
                      formatCantidad(item.cantidad, pesable: false),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.text),
                    ),
                  ),
                  _StepperBtn(icono: Icons.add, onTap: onSumar),
                ],
              ),
            ),
          IconButton(
            onPressed: onQuitar,
            icon: const Icon(Icons.close, size: 17, color: AppColors.faint),
            tooltip: 'Quitar',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Chip tappable con el peso actual de un ítem pesable — reemplaza al
/// stepper +/-1 de `_CarritoItemTile` para esos productos.
class _PesoChip extends StatelessWidget {
  const _PesoChip({required this.texto, required this.onTap});

  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.soft,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                texto,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.text),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.scale_outlined, size: 15, color: _colorProductos),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet para tipear un peso real (báscula) — se usa tanto al
/// agregar un producto pesable por primera vez (`valorInicial: null`) como
/// al corregir el peso de un ítem ya en el carrito (`valorInicial` con el
/// valor actual). Mismo patrón que el picking por peso
/// (`tarea_picking_tile.dart`), para que la app sea consistente.
class _PesoSheet extends StatefulWidget {
  const _PesoSheet({
    required this.productoNombre,
    required this.unidadSimbolo,
    this.valorInicial,
  });

  final String productoNombre;
  final String unidadSimbolo;
  final double? valorInicial;

  @override
  State<_PesoSheet> createState() => _PesoSheetState();
}

class _PesoSheetState extends State<_PesoSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.valorInicial != null ? formatCantidad(widget.valorInicial!, pesable: true) : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final valor = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      setState(() => _error = 'Ingresá un peso mayor a 0');
      return;
    }
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.valorInicial != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Text(
                widget.productoNombre,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              const Text(
                '⚖ Producto pesable — ingresá el peso real (báscula), no una cantidad de unidades.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _confirmar(),
                decoration: InputDecoration(
                  labelText: 'Peso (${widget.unidadSimbolo})',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(backgroundColor: _colorProductos),
                child: Text(editando ? 'Guardar peso' : 'Agregar al carrito'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: Icon(icono, size: 16, color: AppColors.sub),
      ),
    );
  }
}

/// Barra fija al fondo del paso (footer con sombra hacia arriba) — se usa
/// tanto para "Continuar" (paso 1) como para "Confirmar venta" (paso 2), así
/// la acción principal de cada etapa siempre está a la vista sin necesidad
/// de scrollear hasta el final.
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
    return compacto ? contenido : Center(child: Padding(padding: const EdgeInsets.all(24), child: contenido));
  }
}

const Map<String, (String, Color)> _resultadoLabel = {
  'stock_descontado': ('Stock descontado', Color(0xFF15803D)),
  'compra_externa': ('Sin stock — compra externa', Color(0xFFB45309)),
  'servicio': ('Servicio', Color(0xFF475569)),
};

class _VentaConfirmadaDialog extends StatelessWidget {
  const _VentaConfirmadaDialog({required this.resultado});

  final VentaPosResultado resultado;

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
      title: Text('Venta registrada', textAlign: TextAlign.center),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                resultado.codigoPedido,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.text),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Queda pendiente de facturar. Administración le va a asignar el precio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            ...resultado.items.map((it) {
              final meta = _resultadoLabel[it.resultado] ?? _resultadoLabel['servicio']!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${it.productoNombre} × ${it.cantidad}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: meta.$2.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        meta.$1,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: meta.$2),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(backgroundColor: _colorProductos),
          child: const Text('Nueva venta'),
        ),
      ],
    );
  }
}

String _formatNumero(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
