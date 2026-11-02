import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/produccion_providers.dart';
import '../domain/etiqueta_diseno.dart';
import '../domain/produccion_models.dart';
import 'widgets/etiqueta_preview.dart';

String _fmtFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

Future<int?> _pedirCantidadCopias(BuildContext context) {
  final controller = TextEditingController(text: '1');
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Cuántas etiquetas?'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Cantidad de paquetes a etiquetar'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text) ?? 1),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
}

Future<double?> _pedirPeso(BuildContext context, {required int actual, required int total}) {
  final controller = TextEditingController();
  return showDialog<double>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text('Etiqueta $actual de $total'),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Peso (Kg)', hintText: 'Ej: 1.250'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar resto')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text.replaceAll(',', '.'))),
          child: const Text('Imprimir'),
        ),
      ],
    ),
  );
}

Future<ImpresoraDisponible?> _elegirImpresora(BuildContext context, List<ImpresoraDisponible> impresoras) {
  return showDialog<ImpresoraDisponible>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('¿En qué impresora?'),
      children: [
        for (final imp in impresoras)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(imp),
            child: Text('${imp.nombre} (${imp.ip})'),
          ),
      ],
    ),
  );
}

/// Etiquetas de los lotes generados al finalizar una orden. El layout sale
/// de la plantilla asignada a la RECETA y la impresión la hace el SERVIDOR
/// (2026-11-02): manda el ZPL a la impresora que tiene asignada esa
/// plantilla en la web (Ajustes → Producción → Conexiones). La app ya no
/// guarda IP de impresora ni se conecta a ella.
class EtiquetasScreen extends ConsumerStatefulWidget {
  const EtiquetasScreen({super.key, required this.idOrden});

  final int idOrden;

  @override
  ConsumerState<EtiquetasScreen> createState() => _EtiquetasScreenState();
}

class _EtiquetasScreenState extends ConsumerState<EtiquetasScreen> {
  final Set<String> _imprimiendo = {};

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _imprimir(EtiquetaProduccion etiqueta, DestinoImpresion destino) async {
    if (destino.problema != null || destino.impresoras.isEmpty) {
      _aviso(destino.problema ?? 'No hay impresora para esta etiqueta');
      return;
    }

    var impresora = destino.impresoras.first;
    if (destino.impresoras.length > 1) {
      final elegida = await _elegirImpresora(context, destino.impresoras);
      if (elegida == null || !mounted) return;
      impresora = elegida;
    }

    // Etiqueta que pide pesar: el operario carga el peso de cada paquete y
    // se manda todo junto (una copia por peso).
    List<double>? pesos;
    if (destino.pidePeso) {
      final cantidad = await _pedirCantidadCopias(context);
      if (cantidad == null || cantidad <= 0 || !mounted) return;
      pesos = [];
      for (var i = 1; i <= cantidad; i++) {
        if (!mounted) return;
        final peso = await _pedirPeso(context, actual: i, total: cantidad);
        if (peso == null) break;
        pesos.add(peso);
      }
      if (pesos.isEmpty) return;
    }

    setState(() => _imprimiendo.add(etiqueta.loteInterno));
    try {
      final enviadas = await ref.read(produccionRepositoryProvider).imprimirEtiquetas(
        idOrden: widget.idOrden,
        loteInterno: etiqueta.loteInterno,
        pesos: pesos,
        idImpresora: impresora.idImpresora,
      );
      _aviso('$enviadas etiqueta${enviadas == 1 ? '' : 's'} enviada${enviadas == 1 ? '' : 's'} a ${impresora.nombre}');
    } catch (e) {
      _aviso(describeError(e));
    } finally {
      if (mounted) setState(() => _imprimiendo.remove(etiqueta.loteInterno));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(etiquetasProvider(widget.idOrden));
    final destino = ref.watch(destinoImpresionProvider(widget.idOrden)).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etiquetas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Volver a consultar la impresora',
            onPressed: () => ref.invalidate(destinoImpresionProvider(widget.idOrden)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (etiquetas) {
          if (etiquetas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Esta orden no generó etiquetas.', style: TextStyle(color: AppColors.muted)),
              ),
            );
          }

          final idReceta = etiquetas.first.idReceta;
          final recetaAsync = ref.watch(recetaDetalleProvider(idReceta));

          return recetaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
              ),
            ),
            data: (receta) {
              final idEtiqueta = receta.etiqueta?.idEtiqueta;
              if (idEtiqueta == null) {
                return _SinPlantilla(etiquetas: etiquetas);
              }

              final plantillaAsync = ref.watch(etiquetaTemplateProvider(idEtiqueta));
              return plantillaAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
                  ),
                ),
                data: (plantilla) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (destino != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: destino.problema != null ? AppColors.waBg : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              destino.problema != null ? Icons.warning_amber_rounded : Icons.print_outlined,
                              color: destino.problema != null ? AppColors.waTx : AppColors.muted,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                destino.problema ??
                                    'Imprime en ${destino.impresoras.map((i) => i.nombre).join(' o ')}',
                                style: TextStyle(
                                  color: destino.problema != null ? AppColors.waTx : AppColors.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    for (final etq in etiquetas) ...[
                      _EtiquetaCard(
                        etiqueta: etq,
                        plantilla: plantilla,
                        imprimiendo: _imprimiendo.contains(etq.loteInterno),
                        // Sin destino (impresión deshabilitada, sin impresora
                        // o etiqueta sin diseñar) no se puede imprimir.
                        onImprimir: destino == null || destino.problema != null ? null : () => _imprimir(etq, destino),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// La receta no tiene una plantilla de etiqueta asignada — se puede ver que
/// se generaron lotes, pero no hay nada que imprimir todavía.
class _SinPlantilla extends StatelessWidget {
  const _SinPlantilla({required this.etiquetas});

  final List<EtiquetaProduccion> etiquetas;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(14)),
          child: const Text(
            'Esta receta todavía no tiene una etiqueta asignada — pedile a un administrador que elija una plantilla desde Producción → Recetas en la web.',
            style: TextStyle(color: AppColors.waTx, fontWeight: FontWeight.w600, fontSize: 12.5),
          ),
        ),
        for (final etq in etiquetas) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etq.producto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
                const SizedBox(height: 4),
                Text('Lote ${etq.loteInterno}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EtiquetaCard extends StatefulWidget {
  const _EtiquetaCard({
    required this.etiqueta,
    required this.plantilla,
    required this.imprimiendo,
    required this.onImprimir,
  });

  final EtiquetaProduccion etiqueta;
  final EtiquetaTemplate plantilla;
  final bool imprimiendo;
  final VoidCallback? onImprimir;

  @override
  State<_EtiquetaCard> createState() => _EtiquetaCardState();
}

class _EtiquetaCardState extends State<_EtiquetaCard> {
  bool _mostrarPreview = false;

  @override
  Widget build(BuildContext context) {
    final etiqueta = widget.etiqueta;
    final esPesar = plantillaPidePeso(widget.plantilla);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta.producto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
          if (etiqueta.marca?.isNotEmpty ?? false) ...[
            const SizedBox(height: 2),
            Text(etiqueta.marca!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
          const SizedBox(height: 8),
          Text(
            '${etiqueta.cantidad.toStringAsFixed(2)} ${etiqueta.unidad}',
            style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600),
          ),
          if (etiqueta.codigoBarra?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.qr_code_2, size: 14, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(etiqueta.codigoBarra!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            etiqueta.fechaVencimiento != null
                ? 'Lote ${etiqueta.loteInterno} · Vence ${_fmtFecha(etiqueta.fechaVencimiento!)}'
                : 'Lote ${etiqueta.loteInterno}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          if (esPesar) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.scale_outlined, size: 14, color: AppColors.accent),
                SizedBox(width: 4),
                Text('Se pide el peso de cada paquete al imprimir', style: TextStyle(fontSize: 11.5, color: AppColors.accent, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (_mostrarPreview) ...[
            const SizedBox(height: 14),
            Center(child: EtiquetaPreview(etiqueta: etiqueta, plantilla: widget.plantilla)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _mostrarPreview = !_mostrarPreview),
                  icon: Icon(_mostrarPreview ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  label: Text(_mostrarPreview ? 'Ocultar' : 'Vista previa'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.imprimiendo ? null : widget.onImprimir,
                  icon: widget.imprimiendo
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_outlined),
                  label: Text(widget.imprimiendo ? 'Imprimiendo...' : (esPesar ? 'Imprimir...' : 'Imprimir')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
