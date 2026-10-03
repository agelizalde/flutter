import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Campos de credenciales de supervisor (email + contraseña), reusados por
/// los sheets de "Cancelar tarea" y "Modificar cantidad" cuando Ajustes ->
/// Operaciones -> Picking exige autorización de un supervisor para esa
/// acción (`cancelar_requiere_supervisor` / `modificar_cantidad_requiere_supervisor`
/// — ver `picking_config_service.py`). Valida server-side
/// (`picking_operario.supervisar`) — acá solo se pide que no estén vacíos.
class SupervisorAuthFields extends StatefulWidget {
  const SupervisorAuthFields({
    super.key,
    required this.emailController,
    required this.passwordController,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  State<SupervisorAuthFields> createState() => _SupervisorAuthFieldsState();
}

class _SupervisorAuthFieldsState extends State<SupervisorAuthFields> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(10)),
          child: const Text(
            '🔒 Este almacén exige autorización de un supervisor para esta acción.',
            style: TextStyle(fontSize: 12, color: AppColors.waTx, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email del supervisor',
            prefixIcon: Icon(Icons.person_outline, color: AppColors.faint, size: 20),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: widget.passwordController,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Contraseña del supervisor',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.faint, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.faint,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ],
    );
  }
}
