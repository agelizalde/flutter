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

/// Color propio del paso 2 (Productos/Carrito) — distinto del azul de marca
/// (`AppColors.accent`, usado para el paso 1) para que las dos etapas del
/// flujo se puedan diferenciar de un vistazo, mismo patrón que POS
/// (`pos_screen.dart`, `_colorProductos`), con un tono propio para no
/// confundir visualmente los dos carritos de la app.
const _colorProductos = Color(0xFF7C3AED);
const _colorProductosSoft = Color(0xFFF5F3FF);

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
        builder: (context) => _OcGeneradaDialog(resultado: resultado),
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
      backgroundColor: AppColors.pageBg,
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
          _EtapasHeader(pasoActual: _proveedor == null ? 1 : 2),
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

/// Barra de etapas — dos "píldoras" conectadas por una línea, con estado
/// claro (pendiente / activa / completada) reforzado con color de fondo,
/// borde e ícono, no solo con el número. Mismo patrón que POS
/// (`pos_screen.dart::_EtapasHeader`).
class _EtapasHeader extends StatelessWidget {
  const _EtapasHeader({required this.pasoActual});

  /// 1 = eligiendo proveedor, 2 = eligiendo productos.
  final int pasoActual;

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
              titulo: 'Proveedor',
              subtitulo: 'razón social o RUC',
              icono: Icons.local_shipping_outlined,
              color: AppColors.accent,
              colorSoft: AppColors.accentSoft,
              activa: pasoActual == 1,
              completada: pasoActual > 1,
            ),
          ),
          Container(
            width: 28,
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: pasoActual > 1 ? _colorProductos : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: _Etapa(
              numero: 2,
              titulo: 'Productos',
              subtitulo: 'cantidad y precio',
              icono: Icons.inventory_2_outlined,
              color: _colorProductos,
              colorSoft: _colorProductosSoft,
              activa: pasoActual == 2,
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
// PASO 1 — PROVEEDOR
// =========================================================

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

// =========================================================
// PASO 2 — PRODUCTOS Y CARRITO
// =========================================================

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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              // Recap del proveedor ya elegido — mismo patrón que el chip de
              // cliente en POS (`_ClienteYSucursalRecap`), pero acá el
              // proveedor no se puede editar sin volver al paso 1 (no hay
              // datos adicionales que completar, a diferencia de sucursal).
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
              if (carrito.isEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: const _EstadoVacio(
                    icono: Icons.add_shopping_cart_outlined,
                    texto: 'Buscá un producto para agregarlo',
                    compacto: true,
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
                      formatGs(_total),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: puedeGenerar && !guardando ? onGenerar : null,
                  style: ElevatedButton.styleFrom(backgroundColor: _colorProductos),
                  icon: guardando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(guardando ? 'Generando...' : 'Generar OC'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductoResultadoTile extends StatelessWidget {
  const _ProductoResultadoTile({required this.producto, required this.onTap});

  final ProductoCompraSimple producto;
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
                      producto.precioMaximoCompraSimple != null
                          ? '${producto.codigoInterno} · máx. ${formatGs(producto.precioMaximoCompraSimple!)}'
                          : producto.codigoInterno,
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error != null ? AppColors.erTx.withValues(alpha: 0.35) : AppColors.border),
      ),
      padding: const EdgeInsets.all(14),
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
              if (error == null)
                Text(
                  formatGs(item.subtotal),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.text),
                ),
              IconButton(
                onPressed: onQuitar,
                icon: const Icon(Icons.close, size: 18, color: AppColors.faint),
                tooltip: 'Quitar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          if (error != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 15, color: AppColors.erTx),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      error,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.erTx),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra fija al fondo del paso 2 (footer con sombra hacia arriba) — así el
/// total y "Generar OC" siempre están a la vista sin scrollear hasta el
/// final, mismo patrón que POS (`pos_screen.dart::_BottomBar`).
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

const Map<String, (String, Color)> _estadoLabel = {
  'APROBADO': ('Aprobada automáticamente', Color(0xFF15803D)),
  'PENDIENTE_FIRMA': ('Pendiente de firma', Color(0xFFB45309)),
};

class _OcGeneradaDialog extends StatelessWidget {
  const _OcGeneradaDialog({required this.resultado});

  final OcSimpleResultado resultado;

  @override
  Widget build(BuildContext context) {
    final estado = _estadoLabel[resultado.estado] ?? ('Registrada', AppColors.muted);
    return AlertDialog(
      icon: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: _colorProductosSoft, shape: BoxShape.circle),
        child: const Icon(Icons.check_circle, color: _colorProductos, size: 28),
      ),
      title: const Text('OC generada', textAlign: TextAlign.center),
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
            decoration: BoxDecoration(color: estado.$2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(
              estado.$1,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: estado.$2),
            ),
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

String _formatNumero(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
