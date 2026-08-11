import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/config/servidor_config_store.dart';

/// Pantalla accesible desde el login (sin sesión) para pisar la URL del
/// backend sin recompilar el APK — ver `Env._runtimeOverride`. Pensada para
/// cuando cambia la IP del servidor y hay varios teléfonos ya instalados: en
/// vez de recompilar y reinstalar en cada uno, se corrige acá.
class ConfigurarServidorScreen extends StatefulWidget {
  const ConfigurarServidorScreen({super.key});

  @override
  State<ConfigurarServidorScreen> createState() => _ConfigurarServidorScreenState();
}

class _ConfigurarServidorScreenState extends State<ConfigurarServidorScreen> {
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
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _esValorGuardado = true;
    });
    _mostrarDialogoReinicio();
  }

  Future<void> _restablecer() async {
    setState(() => _guardando = true);
    await _store.guardar(null);
    Env.setOverrideEnMemoria(null);
    if (!mounted) return;
    setState(() {
      _guardando = false;
      _esValorGuardado = false;
      _urlController.text = Env.apiBaseUrl;
    });
    _mostrarDialogoReinicio();
  }

  void _mostrarDialogoReinicio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Listo'),
        content: const Text(
          'Se guardó la configuración. Cerrá la app por completo (no solo minimizarla) y volvé a abrirla para que tome efecto en toda la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
