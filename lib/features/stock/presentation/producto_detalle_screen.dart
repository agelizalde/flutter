import '../../../core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/utils/parsing.dart';
import '../../../core/widgets/selector_sheet.dart';
import '../../auth/application/auth_controller.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../application/stock_providers.dart';
import '../domain/stock_models.dart';

/// Pantalla principal del módulo de Stock: ficha del producto + totales
/// (real/reservada/disponible) + desglose por lote y ubicación. Mismo
/// lenguaje visual que Home (`HomeScreen`): header "hero" con degradé en
/// vez de AppBar plano, tarjetas blancas con sombra suave.
class ProductoDetalleScreen extends ConsumerWidget {
  const ProductoDetalleScreen({super.key, required this.idProducto});

  final int idProducto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productoDetalleProvider(idProducto));

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              describeError(e),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.erTx),
            ),
          ),
        ),
        data: (detalle) => _Contenido(detalle: detalle),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.detalle});

  final ProductoStockDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final r = detalle.resumen;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Hero(producto: detalle.producto, resumen: r)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: _KpiBox(
                    etiqueta: 'Cantidad real',
                    valor: r.stockTotal,
                    unidad: r.unidadSimbolo,
                    pesable: detalle.producto.unidadPesable,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiBox(
                    etiqueta: 'Reservada',
                    valor: r.stockReservado,
                    unidad: r.unidadSimbolo,
                    pesable: detalle.producto.unidadPesable,
                    color: AppColors.waTx,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _KpiBox(
                    etiqueta: 'Disponible',
                    valor: r.stockDisponible,
                    unidad: r.unidadSimbolo,
                    pesable: detalle.producto.unidadPesable,
                    color: r.stockDisponible > 0 ? AppColors.okTx : AppColors.erTx,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'POR UBICACIÓN Y LOTE',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.muted,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverToBoxAdapter(
            child: detalle.existencias.isEmpty
                ? const _Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No hay stock físico de este producto',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: detalle.existencias
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ExistenciaRow(existencia: e, pesable: detalle.producto.unidadPesable),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.producto, required this.resumen});

  final ProductoDetalle producto;
  final StockResumen resumen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    // Mismos permisos que exige `GET /compras/oc/ultimas-compras`.
    final puedeVerPrecios =
        (usuario?.tienePermiso('oc.ver') ?? false) || (usuario?.tienePermiso('oc.crear') ?? false);
    final esServicio = producto.claseProducto == 'SERVICIO';
    final claseLabel = switch (producto.claseProducto) {
      'SERVICIO' => 'Servicio',
      'KIT' => 'Kit',
      'FISICO' => 'Físico',
      _ => null,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                _HeroBoton(
                  icono: Icons.arrow_back,
                  tooltip: 'Volver',
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                if (puedeVerPrecios) ...[
                  _HeroBoton(
                    icono: Icons.attach_money,
                    tooltip: 'Últimas compras',
                    onTap: () => _mostrarUltimasCompras(context, producto: producto),
                  ),
                  const SizedBox(width: 8),
                ],
                _HeroBoton(
                  icono: Icons.settings_outlined,
                  tooltip: 'Capacidad, ubicación y recepción',
                  onTap: () => _mostrarInfoExtra(context, producto: producto, resumen: resumen),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HeroFoto(url: producto.fotoUrl, esServicio: esServicio),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          producto.codigoInterno,
                          if (producto.sku != null && producto.sku!.isNotEmpty) 'SKU ${producto.sku}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (producto.descripcion != null && producto.descripcion!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                producto.descripcion!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE2E8F0), height: 1.4),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (claseLabel != null) _HeroChip(texto: claseLabel, icono: Icons.category_outlined),
                if (producto.marcaNombre != null) _HeroChip(texto: producto.marcaNombre!, icono: Icons.sell_outlined),
                if (producto.proveedorNombre != null)
                  _HeroChip(texto: producto.proveedorNombre!, icono: Icons.local_shipping_outlined),
                _HeroChip(texto: '${producto.unidadNombre} (${producto.unidadSimbolo})', icono: Icons.straighten),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón redondo translúcido de la barra superior del hero.
class _HeroBoton extends StatelessWidget {
  const _HeroBoton({required this.icono, required this.tooltip, required this.onTap});

  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icono, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

class _HeroFoto extends StatelessWidget {
  const _HeroFoto({required this.url, required this.esServicio});

  final String? url;
  final bool esServicio;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
      child: Icon(
        esServicio ? Icons.miscellaneous_services_outlined : Icons.inventory_2_outlined,
        color: Colors.white,
        size: 30,
      ),
    );

    if (url == null || url!.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        Env.resolveStorageUrl(url!),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.texto, required this.icono});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(texto, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ExistenciaRow extends StatelessWidget {
  const _ExistenciaRow({required this.existencia, required this.pesable});

  final ExistenciaStock existencia;
  final bool pesable;

  Color _colorVencimiento(DateTime? fecha) {
    if (fecha == null) return AppColors.muted;
    final dias = fecha.difference(DateTime.now()).inDays;
    if (dias < 0) return AppColors.erTx;
    if (dias <= 7) return AppColors.waTx;
    return AppColors.okTx;
  }

  String _textoVencimiento(DateTime? fecha) {
    if (fecha == null) return 'Sin vencimiento';
    final dias = fecha.difference(DateTime.now()).inDays;
    final fechaTxt = formatFecha(fecha);
    if (dias < 0) return '$fechaTxt · Vencido';
    if (dias == 0) return '$fechaTxt · Vence hoy';
    return '$fechaTxt · $dias días';
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${existencia.ubicacionNombre} (${existencia.ubicacionCodigo}) · ${existencia.almacenNombre}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Wrap (no Row) porque los códigos de lote pueden ser largos
          // (ej. "LOT-4-V20260624-F20260605-0001") y no truncamos el
          // código de lote — es el dato de trazabilidad. Si no entra junto
          // con la badge de vencimiento, esta pasa a la línea siguiente.
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_2, size: 16, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Lote ${existencia.loteInterno}',
                    style: const TextStyle(fontSize: 12, color: AppColors.sub),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _colorVencimiento(
                    existencia.fechaVencimiento,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _textoVencimiento(existencia.fechaVencimiento),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _colorVencimiento(existencia.fechaVencimiento),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.soft),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniCantidad(
                etiqueta: 'Real',
                valor: existencia.cantidad,
                unidad: existencia.unidadSimbolo,
                pesable: pesable,
              ),
              _MiniCantidad(
                etiqueta: 'Reservada',
                valor: existencia.cantidadReservadaPicking,
                unidad: existencia.unidadSimbolo,
                pesable: pesable,
              ),
              _MiniCantidad(
                etiqueta: 'Disponible',
                valor: existencia.cantidadDisponible,
                unidad: existencia.unidadSimbolo,
                pesable: pesable,
                destacar: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCantidad extends StatelessWidget {
  const _MiniCantidad({
    required this.etiqueta,
    required this.valor,
    required this.unidad,
    required this.pesable,
    this.destacar = false,
  });

  final String etiqueta;
  final double valor;
  final String unidad;
  final bool pesable;
  final bool destacar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        Text(
          '${formatCantidad(valor, pesable: pesable)} $unidad',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: destacar
                ? (valor > 0 ? AppColors.okTx : AppColors.erTx)
                : AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({
    required this.etiqueta,
    required this.valor,
    required this.unidad,
    required this.pesable,
    required this.color,
  });

  final String etiqueta;
  final double valor;
  final String unidad;
  final bool pesable;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatCantidad(valor, pesable: pesable),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            unidad,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet con los datos de depósito que no entran en el hero:
/// capacidad máxima, ubicación recomendada, ubicación automática y
/// observación de recepción (`productos_almacenaje`). Con `productos.editar`
/// — mismo permiso que la pestaña "Depósito" de la ficha web
/// (`DepositoProducto.jsx`) — se pueden editar desde acá.
void _mostrarInfoExtra(
  BuildContext context, {
  required ProductoDetalle producto,
  required StockResumen resumen,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _InfoExtraSheet(producto: producto, resumen: resumen),
  );
}

/// Bottom sheet "$": precio unitario de las últimas 3 compras (OC
/// APROBADA/CERRADA) del producto. Solo visible con `oc.ver` u `oc.crear`.
void _mostrarUltimasCompras(BuildContext context, {required ProductoDetalle producto}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _UltimasComprasSheet(idProducto: producto.idProducto),
  );
}

/// `formatGs` arma el separador de miles; acá se cambia el prefijo por la
/// moneda real de la OC (puede ser USD).
String _formatPrecio(double valor, String monedaSimbolo) {
  final numero = formatGs(valor).replaceFirst('Gs. ', '');
  return monedaSimbolo.isEmpty ? numero : '$monedaSimbolo $numero';
}

class _UltimasComprasSheet extends ConsumerWidget {
  const _UltimasComprasSheet({required this.idProducto});

  final int idProducto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ultimasComprasProvider(idProducto));

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Últimas compras',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(height: 16),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
              ),
              data: (compras) => compras.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No hay compras registradas de este producto',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 78, child: _CompraHeader('Fecha')),
                              Expanded(child: _CompraHeader('Proveedor')),
                              _CompraHeader('Precio u.'),
                            ],
                          ),
                        ),
                        for (final c in compras)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.soft)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 78,
                                  child: Text(
                                    c.fechaEmision != null ? formatFecha(c.fechaEmision!) : '—',
                                    style: const TextStyle(fontSize: 13, color: AppColors.sub),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    c.proveedorNombre,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _formatPrecio(c.precioUnitario, c.monedaSimbolo),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    if (c.unidadSimbolo.isNotEmpty)
                                      Text(
                                        'por ${c.unidadSimbolo}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompraHeader extends StatelessWidget {
  const _CompraHeader(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.muted,
      ),
    );
  }
}

String? _ubicacionLabel(String? codigo, String? nombre) {
  if (nombre == null) return null;
  return codigo != null && codigo.isNotEmpty ? '$codigo — $nombre' : nombre;
}

class _InfoExtraSheet extends ConsumerStatefulWidget {
  const _InfoExtraSheet({required this.producto, required this.resumen});

  final ProductoDetalle producto;
  final StockResumen resumen;

  @override
  ConsumerState<_InfoExtraSheet> createState() => _InfoExtraSheetState();
}

class _InfoExtraSheetState extends ConsumerState<_InfoExtraSheet> {
  bool _editando = false;
  bool _guardando = false;
  String? _error;

  final _capacidad = TextEditingController();
  final _obs = TextEditingController();
  int? _idPreferida;
  String? _labelPreferida;
  int? _idAutomatica;
  String? _labelAutomatica;

  StockResumen get _r => widget.resumen;

  @override
  void dispose() {
    _capacidad.dispose();
    _obs.dispose();
    super.dispose();
  }

  void _empezarEdicion() {
    setState(() {
      _capacidad.text = _r.capacidadMaxima != null ? formatCantidad(_r.capacidadMaxima!, pesable: true) : '';
      _obs.text = _r.obsRecepcion ?? '';
      _idPreferida = _r.idUbicacionPreferida;
      _labelPreferida = _ubicacionLabel(_r.ubicacionPreferidaCodigo, _r.ubicacionPreferidaNombre);
      _idAutomatica = _r.idUbicacionAutomatica;
      _labelAutomatica = _ubicacionLabel(_r.ubicacionAutomaticaCodigo, _r.ubicacionAutomaticaNombre);
      _error = null;
      _editando = true;
    });
  }

  Future<UbicacionSimple?> _elegirUbicacion(String titulo, int? actual) {
    final repo = ref.read(stockRepositoryProvider);
    return showSelectorSheet<UbicacionSimple>(
      context,
      titulo: titulo,
      cargar: (q) => repo.buscarUbicacionesCatalogo(q),
      etiqueta: (u) => _ubicacionLabel(u.codigo, u.nombre) ?? '',
      esIgual: (u) => u.idUbicacion == actual,
    );
  }

  Future<void> _guardar() async {
    final textoCapacidad = _capacidad.text.trim().replaceAll(',', '.');
    double? capacidad;
    if (textoCapacidad.isNotEmpty) {
      capacidad = double.tryParse(textoCapacidad);
      if (capacidad == null || capacidad < 0) {
        setState(() => _error = 'La capacidad máxima tiene que ser un número mayor o igual a 0');
        return;
      }
    }
    final version = widget.producto.rowVersion;
    if (version == null) {
      setState(() => _error = 'No se pudo leer la versión del producto. Volvé a abrir la ficha.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await ref.read(stockRepositoryProvider).editarAlmacenaje(
        widget.producto.idProducto,
        expectedVersion: version,
        almacenaje: {
          'capacidad_maxima': capacidad,
          'id_ubicacion_preferida': _idPreferida,
          'id_ubicacion_automatica': _idAutomatica,
          'obs_recepcion': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
        },
      );
      if (!mounted) return;
      ref.invalidate(productoDetalleProvider(widget.producto.idProducto));
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Datos de depósito actualizados')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;
    final puedeEditar = (usuario?.tienePermiso('productos.editar') ?? false) && widget.producto.manejaStock;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Capacidad, ubicación y recepción',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    if (puedeEditar && !_editando)
                      TextButton.icon(
                        onPressed: _empezarEdicion,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_editando) ..._formulario() else ..._vista(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _vista() => [
    _InfoExtraFila(
      icono: Icons.inventory_2_outlined,
      etiqueta: 'Capacidad máxima',
      valor: _r.capacidadMaxima != null
          ? '${formatCantidad(_r.capacidadMaxima!, pesable: true)} ${_r.unidadSimbolo}'
          : null,
    ),
    _InfoExtraFila(
      icono: Icons.push_pin_outlined,
      etiqueta: 'Ubicación recomendada',
      valor: _ubicacionLabel(_r.ubicacionPreferidaCodigo, _r.ubicacionPreferidaNombre),
    ),
    _InfoExtraFila(
      icono: Icons.route_outlined,
      etiqueta: 'Ubicación automática',
      valor: _ubicacionLabel(_r.ubicacionAutomaticaCodigo, _r.ubicacionAutomaticaNombre),
    ),
    _InfoExtraFila(
      icono: Icons.info_outline,
      etiqueta: 'Observación de recepción',
      valor: _r.obsRecepcion,
    ),
  ];

  List<Widget> _formulario() => [
    TextField(
      controller: _capacidad,
      enabled: !_guardando,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Capacidad máxima',
        suffixText: _r.unidadSimbolo,
        prefixIcon: const Icon(Icons.inventory_2_outlined),
      ),
    ),
    const SizedBox(height: 12),
    _UbicacionCampo(
      icono: Icons.push_pin_outlined,
      etiqueta: 'Ubicación recomendada',
      valor: _labelPreferida,
      habilitado: !_guardando,
      onElegir: () async {
        final u = await _elegirUbicacion('Ubicación recomendada', _idPreferida);
        if (u != null) {
          setState(() {
            _idPreferida = u.idUbicacion;
            _labelPreferida = _ubicacionLabel(u.codigo, u.nombre);
          });
        }
      },
      onQuitar: () => setState(() {
        _idPreferida = null;
        _labelPreferida = null;
      }),
    ),
    const SizedBox(height: 12),
    _UbicacionCampo(
      icono: Icons.route_outlined,
      etiqueta: 'Ubicación automática',
      valor: _labelAutomatica,
      habilitado: !_guardando,
      onElegir: () async {
        final u = await _elegirUbicacion('Ubicación automática', _idAutomatica);
        if (u != null) {
          setState(() {
            _idAutomatica = u.idUbicacion;
            _labelAutomatica = _ubicacionLabel(u.codigo, u.nombre);
          });
        }
      },
      onQuitar: () => setState(() {
        _idAutomatica = null;
        _labelAutomatica = null;
      }),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _obs,
      enabled: !_guardando,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Observación de recepción',
        prefixIcon: Icon(Icons.info_outline),
        alignLabelWithHint: true,
      ),
    ),
    if (_error != null) ...[
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
        child: Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
      ),
    ],
    const SizedBox(height: 16),
    Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _guardando ? null : () => setState(() => _editando = false),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Guardar'),
          ),
        ),
      ],
    ),
  ];
}

/// Campo de ubicación del formulario: toca para elegir, "x" para quitarla.
class _UbicacionCampo extends StatelessWidget {
  const _UbicacionCampo({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.habilitado,
    required this.onElegir,
    required this.onQuitar,
  });

  final IconData icono;
  final String etiqueta;
  final String? valor;
  final bool habilitado;
  final VoidCallback onElegir;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: habilitado ? onElegir : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: etiqueta,
          prefixIcon: Icon(icono),
          suffixIcon: valor != null && habilitado
              ? IconButton(icon: const Icon(Icons.close), tooltip: 'Quitar', onPressed: onQuitar)
              : const Icon(Icons.chevron_right),
        ),
        child: Text(
          valor ?? 'Sin definir',
          style: TextStyle(
            fontSize: 14,
            color: valor == null ? AppColors.faint : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _InfoExtraFila extends StatelessWidget {
  const _InfoExtraFila({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  final IconData icono;
  final String etiqueta;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  etiqueta,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  (valor == null || valor!.isEmpty) ? 'Sin definir' : valor!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: (valor == null || valor!.isEmpty) ? AppColors.faint : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}
