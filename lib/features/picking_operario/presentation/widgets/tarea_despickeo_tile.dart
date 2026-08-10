import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../application/picking_providers.dart';
import '../../domain/picking_models.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Tile de una tarea de devolución/despickeo pendiente — toca abrir el
/// bottom sheet de confirmación (mismo patrón visual que
/// `TareaPickingTile`/`_CompletarTareaSheet`: `showModalBottomSheet` +
/// `Container` con esquinas redondeadas arriba + drag-handle manual).
class TareaDespickeoTile extends StatelessWidget {
  const TareaDespickeoTile({super.key, required this.tarea});

  final TareaDespickeo tarea;

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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.waBg,
                ),
                child: const Icon(Icons.undo_rounded, size: 18, color: AppColors.waTx),
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
                      '${_fmtCantidad(tarea.cantidad)} ${tarea.unidadSimbolo} · a ${tarea.ubicacionDestinoCodigo ?? "reacomodo"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    if (tarea.codigoPedido != null || tarea.clienteNombre != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        [tarea.codigoPedido, tarea.clienteNombre].whereType<String>().join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.faint),
                      ),
                    ],
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
      builder: (context) => _ConfirmarDespickeoSheet(tarea: tarea),
    );
  }
}

class _ConfirmarDespickeoSheet extends ConsumerStatefulWidget {
  const _ConfirmarDespickeoSheet({required this.tarea});

  final TareaDespickeo tarea;

  @override
  ConsumerState<_ConfirmarDespickeoSheet> createState() => _ConfirmarDespickeoSheetState();
}

class _ConfirmarDespickeoSheetState extends ConsumerState<_ConfirmarDespickeoSheet> {
  final _obsController = TextEditingController();
  bool _confirmando = false;
  String? _error;

  @override
  void dispose() {
    _obsController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      await ref.read(pickingRepositoryProvider).confirmarDespickeo(
        idDespickeoTarea: widget.tarea.idDespickeoTarea,
        observacion: _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
      );
      ref.invalidate(tareasDespickeoProvider);
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
    final tarea = widget.tarea;
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
              if (tarea.productoCodigo != null) ...[
                const SizedBox(height: 2),
                Text(tarea.productoCodigo!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilaDato(label: 'Cantidad a sacar', valor: '${_fmtCantidad(tarea.cantidad)} ${tarea.unidadSimbolo}'),
                    const SizedBox(height: 8),
                    _FilaDato(
                      label: 'Llevar a',
                      valor: tarea.ubicacionDestinoNombre ?? tarea.ubicacionDestinoCodigo ?? 'Ubicación de reacomodo',
                    ),
                    if (tarea.codigoPedido != null) ...[
                      const SizedBox(height: 8),
                      _FilaDato(label: 'Pedido', valor: tarea.codigoPedido!),
                    ],
                    if (tarea.clienteNombre != null) ...[
                      const SizedBox(height: 8),
                      _FilaDato(label: 'Cliente', valor: tarea.clienteNombre!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _obsController,
                enabled: !_confirmando,
                decoration: const InputDecoration(labelText: 'Observación (opcional)'),
                maxLines: 2,
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
                    : const Text('Confirmar — ya lo saqué del cajón'),
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
