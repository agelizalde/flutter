import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../stock/domain/stock_models.dart' show ProveedorSimple;
import '../application/recepcion_providers.dart';

/// Paso 1 del flujo "Recibir OC": escanear el QR del documento de la OC
/// (salta directo a la pantalla de ítems, `/recepcion/oc/:idOc/items`) o
/// elegir el proveedor a mano (va al listado de sus OC aprobadas,
/// `/recepcion/oc/proveedor/:idProveedor`).
class RecibirOcInicioScreen extends ConsumerStatefulWidget {
  const RecibirOcInicioScreen({super.key});

  @override
  ConsumerState<RecibirOcInicioScreen> createState() => _RecibirOcInicioScreenState();
}

class _RecibirOcInicioScreenState extends ConsumerState<RecibirOcInicioScreen> {
  bool _resolviendoCodigo = false;

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    setState(() => _resolviendoCodigo = true);
    try {
      final oc = await ref.read(recepcionRepositoryProvider).buscarOcPorCodigo(codigo);
      if (!mounted) return;
      context.push('/recepcion/oc/${oc.idOc}/items');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _resolviendoCodigo = false);
    }
  }

  Future<void> _elegirProveedor() async {
    final seleccionado = await showModalBottomSheet<ProveedorSimple>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _BuscarProveedorSheet(),
    );
    if (seleccionado == null || !mounted) return;
    context.push(
      '/recepcion/oc/proveedor/${seleccionado.idProveedor}',
      extra: seleccionado.nombreComercial ?? seleccionado.razonSocial,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recibir OC')),
      body: AbsorbPointer(
        absorbing: _resolviendoCodigo,
        child: Opacity(
          opacity: _resolviendoCodigo ? 0.5 : 1,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Elegí cómo identificar la orden de compra que vas a recibir.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              _OpcionCard(
                icono: Icons.qr_code_scanner,
                color: AppColors.accent,
                titulo: 'Escanear código de OC',
                subtitulo: 'Apuntá la cámara al QR impreso en el documento',
                cargando: _resolviendoCodigo,
                onTap: _escanear,
              ),
              const SizedBox(height: 14),
              _OpcionCard(
                icono: Icons.local_shipping_outlined,
                color: AppColors.accentDark,
                titulo: 'Elegir proveedor',
                subtitulo: 'Buscar por nombre y ver sus OC aprobadas',
                onTap: _elegirProveedor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpcionCard extends StatelessWidget {
  const _OpcionCard({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.cargando = false,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: cargando
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Icon(icono, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
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
  }
}

/// Mismo patrón que `_BuscarProveedorSheet` de `nueva_recepcion_screen.dart`
/// (recepción manual) — reusa las providers globales de búsqueda de
/// proveedor, solo se duplica el widget porque no hay una carpeta de
/// widgets compartidos en este proyecto (ver CONTEXTO_WHEREHOUSE.md).
class _BuscarProveedorSheet extends ConsumerStatefulWidget {
  const _BuscarProveedorSheet();

  @override
  ConsumerState<_BuscarProveedorSheet> createState() => _BuscarProveedorSheetState();
}

class _BuscarProveedorSheetState extends ConsumerState<_BuscarProveedorSheet> {
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
      ref.read(recepcionBusquedaProveedorProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recepcionResultadosProveedorProvider);

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
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                'Buscar proveedor',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Nombre, RUC...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(describeError(e))),
                  data: (items) {
                    if (_controller.text.trim().isEmpty) {
                      return const Center(
                        child: Text('Escribí para buscar', style: TextStyle(color: AppColors.muted)),
                      );
                    }
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = items[i];
                        return _ProveedorResultRow(
                          proveedor: p,
                          onTap: () => Navigator.of(context).pop(p),
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

class _ProveedorResultRow extends StatelessWidget {
  const _ProveedorResultRow({required this.proveedor, required this.onTap});

  final ProveedorSimple proveedor;
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_outlined, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proveedor.nombreComercial ?? proveedor.razonSocial,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    Text(
                      proveedor.codigoProveedor,
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
  }
}
