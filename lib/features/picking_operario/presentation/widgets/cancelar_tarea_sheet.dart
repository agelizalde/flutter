import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../application/picking_providers.dart';
import '../../domain/picking_models.dart';
import 'supervisor_auth_fields.dart';

/// Bottom sheet para cancelar una tarea de picking (acción de supervisor) —
/// solo se ofrece si `config.permiteCancelarTarea` (ver `TareaPickingTile`).
/// Pide credenciales de supervisor solo si `config.cancelarRequiereSupervisor`;
/// si no, el propio operario logueado queda como responsable de la acción,
/// igual criterio que el backend (`_resolver_actor_o_supervisor` en
/// `picking_operario_service.py`). Devuelve `true` por `Navigator.pop` si se
/// canceló la tarea, para que quien la abrió refresque lo que necesite.
class CancelarTareaSheet extends ConsumerStatefulWidget {
  const CancelarTareaSheet({super.key, required this.tarea, required this.config});

  final TareaPicking tarea;
  final PickingConfig config;

  @override
  ConsumerState<CancelarTareaSheet> createState() => _CancelarTareaSheetState();
}

class _CancelarTareaSheetState extends ConsumerState<CancelarTareaSheet> {
  final _motivoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _confirmando = false;
  String? _error;

  @override
  void dispose() {
    _motivoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (widget.config.cancelarRequiereSupervisor &&
        (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty)) {
      setState(() => _error = 'Ingresá las credenciales del supervisor');
      return;
    }
    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      await ref.read(pickingRepositoryProvider).cancelarTarea(
        idStockReservaDetalle: widget.tarea.idStockReservaDetalle,
        supervisorEmail: widget.config.cancelarRequiereSupervisor ? _emailController.text.trim() : null,
        supervisorPassword: widget.config.cancelarRequiereSupervisor ? _passwordController.text : null,
        motivo: _motivoController.text.trim().isEmpty ? null : _motivoController.text.trim(),
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
                'Cancelar tarea',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.tarea.productoNombre} · ${widget.tarea.ubicacionCodigo}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _motivoController,
                decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
                maxLength: 500,
              ),
              if (widget.config.cancelarRequiereSupervisor) ...[
                const SizedBox(height: 4),
                SupervisorAuthFields(emailController: _emailController, passwordController: _passwordController),
              ],
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.erTx),
                onPressed: _confirmando ? null : _confirmar,
                child: _confirmando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Cancelar tarea'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
