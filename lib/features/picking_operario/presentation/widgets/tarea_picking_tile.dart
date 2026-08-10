import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../application/picking_providers.dart';
import '../../domain/picking_models.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Tile de una tarea de picking. Las pendientes son tocables y abren el
/// bottom sheet de completar (mismo patrón visual que `_BuscarUbicacionSheet`
/// de Traslados: `showModalBottomSheet` + `Container` con esquinas
/// redondeadas arriba + drag-handle manual).
class TareaPickingTile extends StatelessWidget {
  const TareaPickingTile({super.key, required this.tarea, required this.idSesion});

  final TareaPicking tarea;
  final int idSesion;

  @override
  Widget build(BuildContext context) {
    final done = tarea.completada;
    final cancelled = tarea.cancelada;

    return Material(
      color: done ? AppColors.okBg : cancelled ? AppColors.erBg : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: (done || cancelled)
            ? null
            : () => _abrirCompletar(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF22C55E)
                      : cancelled
                          ? AppColors.erTx
                          : AppColors.accentSoft,
                ),
                child: Icon(
                  done ? Icons.check : cancelled ? Icons.close : Icons.shopping_basket_outlined,
                  size: 18,
                  color: done || cancelled ? Colors.white : AppColors.accentDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarea.productoNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tarea.ubicacionCodigo} · ${_fmtCantidad(tarea.cantidad)} ${tarea.unidadSimbolo}'
                      '${tarea.pickingPorPeso ? ' · pesable' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    if (done && tarea.cantidadPickeada != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pickeado: ${_fmtCantidad(tarea.cantidadPickeada!)} ${tarea.unidadSimbolo}'
                        '${tarea.contenedorIdentificador != null ? ' · ${tarea.contenedorIdentificador}' : ''}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.okTx),
                      ),
                    ],
                  ],
                ),
              ),
              if (!done && !cancelled) const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirCompletar(BuildContext context) async {
    final ajusteDiferencia = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompletarTareaSheet(tarea: tarea, idSesion: idSesion),
    );
    if (ajusteDiferencia != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚖ Se ajustó el stock automáticamente (+${_fmtCantidad(ajusteDiferencia)}) '
            'por la diferencia de peso.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _CompletarTareaSheet extends ConsumerStatefulWidget {
  const _CompletarTareaSheet({required this.tarea, required this.idSesion});

  final TareaPicking tarea;
  final int idSesion;

  @override
  ConsumerState<_CompletarTareaSheet> createState() => _CompletarTareaSheetState();
}

class _CompletarTareaSheetState extends ConsumerState<_CompletarTareaSheet> {
  late final _cantidadController = TextEditingController(text: _fmtCantidad(widget.tarea.cantidad));
  bool _confirmando = false;
  String? _error;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) {
      setState(() => _error = 'Ingresá una cantidad válida');
      return;
    }
    if (!widget.tarea.pickingPorPeso && cantidad > widget.tarea.cantidad) {
      setState(() => _error = 'Supera lo reservado (${_fmtCantidad(widget.tarea.cantidad)}) — pedile a un '
          'supervisor que modifique la cantidad primero');
      return;
    }

    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      final resultado = await ref.read(pickingRepositoryProvider).completarTarea(
        idStockReservaDetalle: widget.tarea.idStockReservaDetalle,
        idSesion: widget.idSesion,
        cantidadPickeada: cantidad,
      );
      ref.invalidate(misTareasProvider);
      if (!mounted) return;
      Navigator.of(context).pop(resultado.ajusteStockDiferencia);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e);
        _confirmando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tarea = widget.tarea;
    final cantidadIngresada = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    final esParcial = cantidadIngresada != null && cantidadIngresada > 0 && cantidadIngresada < tarea.cantidad;

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
                tarea.productoNombre,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                '${tarea.ubicacionCodigo} · pedido: ${_fmtCantidad(tarea.cantidad)} ${tarea.unidadSimbolo}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _cantidadController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: tarea.pickingPorPeso
                      ? 'Peso real (${tarea.unidadSimbolo})'
                      : 'Cantidad a pickear (${tarea.unidadSimbolo})',
                ),
              ),
              if (tarea.pickingPorPeso) ...[
                const SizedBox(height: 8),
                const Text(
                  '⚖ Producto pesable: podés ingresar cualquier peso real, puede diferir de lo pedido.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
              if (esParcial) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '⚡ Pickeo parcial — se creará una tarea nueva por el resto '
                    '(${_fmtCantidad(tarea.cantidad - cantidadIngresada)} ${tarea.unidadSimbolo})',
                    style: const TextStyle(fontSize: 12, color: AppColors.waTx, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _confirmando ? null : _confirmar,
                child: _confirmando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmar picking'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
