import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';

/// Se llega desde el tab Perfil — `POST /auth/change-password` (mismo
/// backend que la web, ver `auth_rout.py`). No pasa por `AuthController`
/// porque no cambia el estado de sesión: la contraseña actual se valida
/// server-side y solo se revocan las OTRAS sesiones, no la de este
/// dispositivo, así que después de guardar seguís logueado acá.
class CambiarPasswordScreen extends ConsumerStatefulWidget {
  const CambiarPasswordScreen({super.key});

  @override
  ConsumerState<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends ConsumerState<CambiarPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _obscureActual = true;
  bool _obscureNueva = true;
  bool _cerrarOtrasSesiones = true;
  bool _guardando = false;

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      await ref.read(authRepositoryProvider).cambiarPassword(
            actual: _actualController.text,
            nueva: _nuevaController.text,
            cerrarOtrasSesiones: _cerrarOtrasSesiones,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(describeError(e))),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actualizar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _actualController,
                  obscureText: _obscureActual,
                  decoration: InputDecoration(
                    labelText: 'Contraseña actual',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.faint, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureActual ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.faint,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureActual = !_obscureActual),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nuevaController,
                  obscureText: _obscureNueva,
                  decoration: InputDecoration(
                    labelText: 'Contraseña nueva',
                    prefixIcon: const Icon(Icons.key_outlined, color: AppColors.faint, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNueva ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.faint,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureNueva = !_obscureNueva),
                    ),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmarController,
                  obscureText: _obscureNueva,
                  decoration: const InputDecoration(labelText: 'Confirmar contraseña nueva'),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _guardar(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v != _nuevaController.text) return 'No coincide con la contraseña nueva';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _cerrarOtrasSesiones,
                  onChanged: (v) => setState(() => _cerrarOtrasSesiones = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Cerrar sesión en otros dispositivos',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                  subtitle: const Text(
                    'Este dispositivo sigue logueado',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Actualizar contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
