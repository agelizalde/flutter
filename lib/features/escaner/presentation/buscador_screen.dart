import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../picking_operario/domain/picking_models.dart';
import '../../recepcion/domain/orden_compra_models.dart';
import '../../recepcion/domain/recepcion_models.dart' show ZonaSimple;
import '../../stock/domain/stock_models.dart';
import '../application/escaner_providers.dart';
import '../application/escaner_search_providers.dart';
import 'contenedor_detalle_screen.dart';
import 'resolver_navegacion.dart';

/// Buscador + escáner de Home: escribir nombre de producto, nombre/código
/// de ubicación o código de OC, o tocar el ícono de cámara para escanear
/// directo — ambos caminos resuelven al mismo lugar (`EscanerRepository`).
class BuscadorScreen extends ConsumerStatefulWidget {
  const BuscadorScreen({super.key});

  @override
  ConsumerState<BuscadorScreen> createState() => _BuscadorScreenState();
}

class _BuscadorScreenState extends ConsumerState<BuscadorScreen> {
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
      ref.read(escanerQueryProvider.notifier).state = value;
    });
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resultado = await ref.read(escanerRepositoryProvider).resolver(codigo);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await resolverYNavegar(context, ref, resultado, codigoNoEncontrado: codigo);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(escanerQueryProvider);

    // Mismo lenguaje visual que Home (`HomeScreen._HeroHeader`): header
    // "hero" con gradiente + buscador blanco embebido, en vez del AppBar +
    // TextField plano que tenía antes.
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: Column(
        children: [
          _Hero(controller: _controller, onChanged: _onChanged, onEscanear: _escanear),
          Expanded(child: query.trim().isEmpty ? const _EstadoInicial() : const _Resultados()),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.controller, required this.onChanged, required this.onEscanear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onEscanear;

  @override
  Widget build(BuildContext context) {
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
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Buscar',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.faint, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: true,
                        onChanged: onChanged,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(fontSize: 14, color: AppColors.text),
                        // El tema global de la app pinta los inputs con
                        // fondo gris + borde de foco azul (`theme.dart`,
                        // pensado para formularios) — acá el buscador ya
                        // está dentro de su propia píldora blanca, así que
                        // hay que anular `filled`/`enabledBorder`/
                        // `focusedBorder` a mano, no alcanza con `border`.
                        decoration: const InputDecoration(
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          hintText: 'Producto, pedido, ubicación, cajón...',
                          hintStyle: TextStyle(color: AppColors.faint, fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onEscanear,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.qr_code_scanner, color: AppColors.accent, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoInicial extends StatelessWidget {
  const _EstadoInicial();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 32, color: AppColors.faint),
              SizedBox(height: 10),
              Text('Escribí para buscar o escaneá un código', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Resultados extends ConsumerWidget {
  const _Resultados();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productos = ref.watch(escanerProductosResultsProvider);
    final ubicaciones = ref.watch(escanerUbicacionesResultsProvider);
    final zonas = ref.watch(escanerZonasResultsProvider);
    final oc = ref.watch(escanerOcResultProvider);
    final contenedor = ref.watch(escanerContenedorResultProvider);

    final cargando =
        productos.isLoading || ubicaciones.isLoading || zonas.isLoading || oc.isLoading || contenedor.isLoading;
    final error = productos.error ?? ubicaciones.error ?? zonas.error ?? oc.error ?? contenedor.error;
    final listaProductos = productos.value ?? const [];
    final listaUbicaciones = ubicaciones.value ?? const [];
    final listaZonas = zonas.value ?? const [];
    final ocEncontrada = oc.value;
    final contenedorEncontrado = contenedor.value;

    final sinNada = listaProductos.isEmpty &&
        listaUbicaciones.isEmpty &&
        listaZonas.isEmpty &&
        ocEncontrada == null &&
        contenedorEncontrado == null;

    if (cargando && sinNada) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && sinNada) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            describeError(error),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.erTx),
          ),
        ),
      );
    }
    if (sinNada) {
      return const Center(
        child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        if (ocEncontrada != null) ...[
          const _SectionTitle('ORDEN DE COMPRA'),
          _OcTile(detalle: ocEncontrada),
          const SizedBox(height: 20),
        ],
        if (contenedorEncontrado != null) ...[
          const _SectionTitle('CAJÓN'),
          _ContenedorTile(detalle: contenedorEncontrado),
          const SizedBox(height: 20),
        ],
        if (listaProductos.isNotEmpty) ...[
          const _SectionTitle('PRODUCTOS'),
          ...listaProductos.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ProductoTile(producto: p),
              )),
          const SizedBox(height: 20),
        ],
        if (listaZonas.isNotEmpty) ...[
          const _SectionTitle('ZONAS'),
          ...listaZonas.map((z) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ZonaTile(zona: z),
              )),
          const SizedBox(height: 20),
        ],
        if (listaUbicaciones.isNotEmpty) ...[
          const _SectionTitle('UBICACIONES'),
          ...listaUbicaciones.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _UbicacionTile(ubicacion: u),
              )),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _OcTile extends StatelessWidget {
  const _OcTile({required this.detalle});

  final OrdenCompraDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final header = detalle.header;
    return _ResultCard(
      onTap: () => context.push('/recepcion/oc/info/${header.idOc}'),
      leadingIcon: Icons.receipt_long_outlined,
      leadingColor: const Color(0xFF4F46E5),
      titulo: header.codigo,
      subtitulo: header.proveedorNombre,
      trailing: _Badge(texto: header.estado),
    );
  }
}

class _ContenedorTile extends StatelessWidget {
  const _ContenedorTile({required this.detalle});

  final ContenedorDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final subpedido = detalle.subpedido;
    return _ResultCard(
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ContenedorDetalleScreen(detalle: detalle)),
      ),
      leadingIcon: Icons.all_inbox_outlined,
      leadingColor: const Color(0xFFDC2626),
      titulo: detalle.identificador,
      subtitulo: subpedido?.tituloDisplay ?? 'Sin asignar',
      trailing: _Badge(texto: '${detalle.items.length} prod.'),
    );
  }
}

class _ProductoTile extends StatelessWidget {
  const _ProductoTile({required this.producto});

  final ProductoSimple producto;

  @override
  Widget build(BuildContext context) {
    final esServicio = producto.claseProducto == 'SERVICIO';
    final claseLabel = switch (producto.claseProducto) {
      'SERVICIO' => 'Servicio',
      'KIT' => 'Kit',
      'FISICO' => 'Físico',
      _ => null,
    };

    return _ResultCard(
      onTap: () => context.push('/stock/producto/${producto.idProducto}'),
      // Sin foto: ícono distinto según sea producto físico o servicio (no
      // hay stock/ubicaciones que mostrar para un servicio, pero igual
      // aparece en el buscador — ver `escanerProductosResultsProvider`).
      leadingIcon: esServicio ? Icons.miscellaneous_services_outlined : Icons.inventory_2_outlined,
      leadingColor: const Color(0xFF2563EB),
      leadingImageUrl: producto.fotoUrl,
      titulo: producto.nombre,
      subtitulo: producto.codigoInterno,
      trailing: claseLabel == null ? null : _Badge(texto: claseLabel),
    );
  }
}

class _ZonaTile extends StatelessWidget {
  const _ZonaTile({required this.zona});

  final ZonaSimple zona;

  @override
  Widget build(BuildContext context) {
    return _ResultCard(
      onTap: () => context.push('/stock/zona/${zona.idZona}', extra: zona.nombre),
      leadingIcon: Icons.map_outlined,
      leadingColor: const Color(0xFF0891B2),
      titulo: zona.nombre,
      subtitulo: zona.codigo ?? 'Sin código',
      trailing: null,
    );
  }
}

class _UbicacionTile extends StatelessWidget {
  const _UbicacionTile({required this.ubicacion});

  final UbicacionStock ubicacion;

  @override
  Widget build(BuildContext context) {
    return _ResultCard(
      onTap: () => context.push(
        '/stock/ubicacion/${ubicacion.idUbicacion}',
        extra: ubicacion.ubicacionNombre,
      ),
      leadingIcon: Icons.location_on_outlined,
      leadingColor: const Color(0xFF7C3AED),
      titulo: ubicacion.ubicacionNombre,
      subtitulo: '${ubicacion.almacenNombre} · ${ubicacion.ubicacionCodigo}',
      trailing: _Badge(texto: '${ubicacion.cantidadProductos} prod.'),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.onTap,
    required this.leadingIcon,
    required this.leadingColor,
    this.leadingImageUrl,
    required this.titulo,
    required this.subtitulo,
    required this.trailing,
  });

  final VoidCallback onTap;
  final IconData leadingIcon;
  final Color leadingColor;

  /// Si viene, se muestra en vez del ícono (foto principal del producto).
  final String? leadingImageUrl;
  final String titulo;
  final String subtitulo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _ResultLeading(icon: leadingIcon, color: leadingColor, imageUrl: leadingImageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(999)),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub),
      ),
    );
  }
}

/// Foto principal del producto si tiene (`ProductoSimple.fotoUrl`); si no,
/// el ícono de color de siempre — también sirve de fallback si la imagen
/// falla al cargar.
class _ResultLeading extends StatelessWidget {
  const _ResultLeading({required this.icon, required this.color, this.imageUrl});

  final IconData icon;
  final Color color;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _IconBox(icon: icon, color: color);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        Env.resolveStorageUrl(url),
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _IconBox(icon: icon, color: color),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
