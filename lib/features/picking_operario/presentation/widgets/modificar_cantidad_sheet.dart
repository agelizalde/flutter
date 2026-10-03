import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../application/picking_providers.dart';
import '../../domain/picking_models.dart';
import 'supervisor_auth_fields.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Bottom sheet para modificar la cantidad de una tarea de picking (acción
/// de supervisor) — solo se ofrece si `config.permiteModificarCantidad` (ver
/// `TareaPickingTile`). Sirve, entre otros casos, para el que ya avisaba
/// `_CompletarTareaSheet` cuando el operario quiere pickear más de lo
/// reservado: acá un supervisor puede subir la cantidad primero. Pide
/// credenciales solo si `config.modificarCantidadRequiereSupervisor`, igual
/// criterio que `CancelarTareaSheet`. Devuelve `true` por `Navigator.pop` si
/// se modificó.
class ModificarCantidadSheet extends ConsumerStatefulWidget {
  const ModificarCantidadSheet({super.key, required this.tarea, required this.config});

  final TareaPicking tarea;
  final PickingConfig config;

  @override
  ConsumerState<ModificarCantidadSheet> createState() => _ModificarCantidadSheetState();
}

class _ModificarCantidadSheetState extends ConsumerState<ModificarCantidadSheet> {
  late final _cantidadController = TextEditingController(text: _fmtCantidad(widget.tarea.cantidad));
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _confirmando = false;
  String? _error;

  @override
  void dispose() {
    _cantidadController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) {
      setState(() => _error = 'Ingresá una cantidad válida');
      return;
    }
    if (widget.config.modificarCantidadRequiereSupervisor &&
        (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty)) {
      setState(() => _error = 'Ingresá las credenciales del supervisor');
      return;
    }
    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      await ref.read(pickingRepositoryProvider).modificarCantidad(
        idStockReservaDetalle: widget.tarea.idStockReservaDetalle,
        nuevaCantidad: cantidad,
        supervisorEmail: widget.config.modificarCantidadRequiereSupervisor ? _emailController.text.trim() : null,
        supervisorPassword: widget.config.modificarCantidadRequiereSupervisor ? _passwordController.text : null,
      );
      ref.invalidate(misTareasProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
              const Text(
                'Modificar cantidad',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.tarea.productoNombre} · actual: ${_fmtCantidad(widget.tarea.cantidad)} ${widget.tarea.unidadSimbolo}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cantidadController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Nueva cantidad (${widget.tarea.unidadSimbolo})'),
              ),
              if (widget.config.modificarCantidadRequiereSupervisor) ...[
                const SizedBox(height: 12),
                SupervisorAuthFields(emailController: _emailController, passwordController: _passwordController),
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
                    : const Text('Guardar cantidad'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
