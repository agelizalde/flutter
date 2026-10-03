import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/config/servidor_config_store.dart';
import '../application/auth_controller.dart';

/// Alcanzable desde el login (sin sesión) y desde `SinConexionScreen`, para
/// pisar la URL del backend sin recompilar el APK — ver
/// `Env._runtimeOverride`. Pensada tanto para cuando cambia la IP del
/// servidor (varios teléfonos ya instalados, se corrige acá en vez de
/// reinstalar en cada uno) como para forzar un origen puntual si la
/// auto-detección erp./public. no da con el correcto.
class ConfigurarServidorScreen extends ConsumerStatefulWidget {
  const ConfigurarServidorScreen({super.key});

  @override
  ConsumerState<ConfigurarServidorScreen> createState() => _ConfigurarServidorScreenState();
}

class _ConfigurarServidorScreenState extends ConsumerState<ConfigurarServidorScreen> {
  final _urlController = TextEditingController();
  final _store = ServidorConfigStore();
  bool _cargando = true;
  bool _guardando = false;
  bool _esValorGuardado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final guardado = await _store.leer();
    if (!mounted) return;
    setState(() {
      _urlController.text = guardado ?? Env.apiBaseUrl;
      _esValorGuardado = guardado != null;
      _cargando = false;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  String? _validar(String url) {
    if (url.isEmpty) return 'Ingresá la URL del servidor';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'Tiene que empezar con http:// o https://';
    }
    if (url.endsWith('/')) return 'No termines la URL con "/"';
    return null;
  }

  Future<void> _guardar() async {
    final url = _urlController.text.trim();
    final error = _validar(url);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _guardando = true;
      _error = null;
    });
    await _store.guardar(url);
    Env.setOverrideEnMemoria(url);
    await _reconectarYVolver(mensajeError: 'No se pudo conectar con $url');
  }

  Future<void> _restablecer() async {
    setState(() => _guardando = true);
    await _store.guardar(null);
    Env.setOverrideEnMemoria(null);
    if (mounted) {
      setState(() {
        _esValorGuardado = false;
        _urlController.text = Env.apiBaseUrl;
      });
    }
    await _reconectarYVolver(
      mensajeError: 'Se restableció, pero seguimos sin poder conectar',
    );
  }

  /// Reemplaza al viejo "cerrá la app y volvé a abrirla": el `baseUrl` de
  /// `DioClient` ya se relee en cada request (ver `Env.apiBaseUrl`), así
  /// que alcanza con probar la nueva configuración ahí mismo. Si conecta,
  /// vuelve sola a donde estaba (login, `/sin-conexion`, etc.) — el router
  /// reacciona solo a `ConexionEstado` (ver `app/router.dart`).
  Future<void> _reconectarYVolver({required String mensajeError}) async {
    final conectado = await Env.reintentarConexion();
    if (conectado) ref.invalidate(authControllerProvider);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (!conectado) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeError)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conectado')),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar servidor')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const Text(
                  'URL completa del backend (incluye protocolo y puerto). Se guarda en este teléfono y pisa el valor con el que se compiló la app.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'URL del servidor',
                    hintText: 'http://192.168.100.97:8000',
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando...' : 'Guardar'),
                ),
                if (_esValorGuardado) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _guardando ? null : _restablecer,
                    child: const Text('Restablecer al valor de fábrica'),
                  ),
                ],
              ],
            ),
    );
  }
}
