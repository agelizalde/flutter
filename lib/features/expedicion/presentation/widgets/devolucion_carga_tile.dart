import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../application/expedicion_providers.dart';
import '../../domain/expedicion_models.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Tile de una devolución de carga pendiente (Ventas redujo/quitó por Excel
/// un producto que depósito ya había escaneado — ver
/// EXPEDICION/BD_CARGA_DEVOLUCION.txt). Mismo patrón visual que
/// `TareaDespickeoTile`: tocar abre un bottom sheet que confirma que el
/// producto se retiró físicamente del camión.
class DevolucionCargaTile extends StatelessWidget {
  const DevolucionCargaTile({super.key, required this.idPedidoSubpedido, required this.devolucion});

  final int idPedidoSubpedido;
  final DevolucionCarga devolucion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _abrirConfirmar(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.waBg),
                child: const Icon(Icons.assignment_return_outlined, size: 18, color: AppColors.waTx),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      devolucion.productoNombre ?? 'Producto #${devolucion.idProducto}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtCantidad(devolucion.cantidad)} ${devolucion.unidadSimbolo ?? ''} · retirar del camión',
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

  Future<void> _abrirConfirmar(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConfirmarDevolucionSheet(idPedidoSubpedido: idPedidoSubpedido, devolucion: devolucion),
    );
  }
}

class _ConfirmarDevolucionSheet extends ConsumerStatefulWidget {
  const _ConfirmarDevolucionSheet({required this.idPedidoSubpedido, required this.devolucion});

  final int idPedidoSubpedido;
  final DevolucionCarga devolucion;

  @override
  ConsumerState<_ConfirmarDevolucionSheet> createState() => _ConfirmarDevolucionSheetState();
}

class _ConfirmarDevolucionSheetState extends ConsumerState<_ConfirmarDevolucionSheet> {
  bool _confirmando = false;
  String? _error;

  Future<void> _confirmar() async {
    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      await ref.read(expedicionRepositoryProvider).confirmarDevolucion(
            widget.idPedidoSubpedido,
            widget.devolucion.idDevolucion,
          );
      ref.invalidate(devolucionesCargaProvider(widget.idPedidoSubpedido));
      if (!mounted) return;
      Navigator.of(context).pop();
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
    final devolucion = widget.devolucion;
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
                devolucion.productoNombre ?? 'Producto #${devolucion.idProducto}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              if (devolucion.productoCodigo != null) ...[
                const SizedBox(height: 2),
                Text(devolucion.productoCodigo!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
              const SizedBox(height: 10),
              Text(
                'Este producto ya se había escaneado como cargado, pero el pedido se modificó. '
                'Retiralo físicamente del camión y confirmá acá para que vuelva al stock.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilaDato(label: 'Cantidad a retirar', valor: '${_fmtCantidad(devolucion.cantidad)} ${devolucion.unidadSimbolo ?? ''}'),
                    const SizedBox(height: 8),
                    _FilaDato(
                      label: 'Llevar a',
                      valor: devolucion.ubicacionDestinoNombre ?? devolucion.ubicacionDestinoCodigo ?? 'Ubicación de reacomodo',
                    ),
                  ],
                ),
              ),
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
                    : const Text('Confirmar — ya lo retiré del camión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(valor, style: const TextStyle(fontSize: 13, color: AppColors.text, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
