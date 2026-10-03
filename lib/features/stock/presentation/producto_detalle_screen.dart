import '../../../core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/utils/parsing.dart';
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

class _Hero extends StatelessWidget {
  const _Hero({required this.producto, required this.resumen});

  final ProductoDetalle producto;
  final StockResumen resumen;

  @override
  Widget build(BuildContext context) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => _mostrarInfoExtra(context, resumen: resumen),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
/// observación de recepción (`productos_almacenaje`, se configuran desde
/// la ficha web del producto, pestaña "Depósito").
void _mostrarInfoExtra(BuildContext context, {required StockResumen resumen}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _InfoExtraSheet(resumen: resumen),
  );
}

class _InfoExtraSheet extends StatelessWidget {
  const _InfoExtraSheet({required this.resumen});

  final StockResumen resumen;

  String? get _ubicacionRecomendada {
    if (resumen.ubicacionPreferidaNombre == null) return null;
    final codigo = resumen.ubicacionPreferidaCodigo;
    return codigo != null && codigo.isNotEmpty
        ? '$codigo — ${resumen.ubicacionPreferidaNombre}'
        : resumen.ubicacionPreferidaNombre;
  }

  String? get _ubicacionAutomatica {
    if (resumen.ubicacionAutomaticaNombre == null) return null;
    final codigo = resumen.ubicacionAutomaticaCodigo;
    return codigo != null && codigo.isNotEmpty
        ? '$codigo — ${resumen.ubicacionAutomaticaNombre}'
        : resumen.ubicacionAutomaticaNombre;
  }

  @override
  Widget build(BuildContext context) {
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
              'Capacidad, ubicación y recepción',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16),
            _InfoExtraFila(
              icono: Icons.inventory_2_outlined,
              etiqueta: 'Capacidad máxima',
              valor: resumen.capacidadMaxima != null
                  ? '${formatCantidad(resumen.capacidadMaxima!, pesable: true)} ${resumen.unidadSimbolo}'
                  : null,
            ),
            _InfoExtraFila(
              icono: Icons.push_pin_outlined,
              etiqueta: 'Ubicación recomendada',
              valor: _ubicacionRecomendada,
            ),
            _InfoExtraFila(
              icono: Icons.route_outlined,
              etiqueta: 'Ubicación automática',
              valor: _ubicacionAutomatica,
            ),
            _InfoExtraFila(
              icono: Icons.info_outline,
              etiqueta: 'Observación de recepción',
              valor: resumen.obsRecepcion,
            ),
          ],
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
