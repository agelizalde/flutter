import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/network/conexion_estado.dart';
import '../application/auth_controller.dart';

/// A la que manda `app/router.dart` cuando `ConexionEstado.sinConexion` es
/// `true` — sin importar en qué pantalla estaba el usuario, ni si tenía o
/// no sesión iniciada. Reemplaza el fallo silencioso que había antes: sin
/// esto, quedarse sin señal en el arranque hacía que `AuthController`
/// tratara el token guardado como inválido y mandara al login sin explicar
/// nada (ver `AuthController.build`).
class SinConexionScreen extends ConsumerStatefulWidget {
  const SinConexionScreen({super.key});

  @override
  ConsumerState<SinConexionScreen> createState() => _SinConexionScreenState();
}

class _SinConexionScreenState extends ConsumerState<SinConexionScreen> {
  bool _reintentando = false;

  Future<void> _reintentar() async {
    setState(() => _reintentando = true);
    final conectado = await Env.reintentarConexion();
    if (conectado) {
      // El `AuthController` pudo haber quedado en `null` porque el primer
      // `/auth/me` falló por falta de conexión, no porque la sesión sea
      // inválida (ver `AuthController.build`) — hay que reintentarlo ahora
      // que sí hay red, si no el usuario cae al login de nuevo sin
      // necesidad aunque el token guardado siga siendo válido.
      ref.invalidate(authControllerProvider);
    }
    if (!mounted) return;
    setState(() => _reintentando = false);
    if (!conectado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seguimos sin poder conectar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = ConexionEstado.detalle;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: AppColors.erBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.wifi_off_rounded, color: AppColors.erTx, size: 40),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sin conexión con el servidor',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No se pudo conectar ni con la red de la empresa ni con el '
                    'servidor público. Revisá el wifi o los datos móviles del '
                    'equipo — la app va a seguir intentando sola en segundo plano.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
                  ),
                  if (detalle != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        detalle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: AppColors.faint),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: _reintentando ? null : _reintentar,
                    icon: _reintentando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_reintentando ? 'Probando conexión...' : 'Reintentar'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/configurar-servidor'),
                    icon: const Icon(Icons.dns_outlined, size: 18),
                    label: const Text('Cambiar servidor'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
