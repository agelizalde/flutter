import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../application/impresora_providers.dart';
import '../domain/impresora_config.dart';

/// Configuración de la impresora de etiquetas: IP/puerto de red + tamaño
/// físico del rollo. Qué campos imprimir y en qué orden se configura por
/// receta (ver la sección "Etiqueta de producción" en la web, al editar una
/// receta) — acá solo queda lo que es realmente propio del dispositivo/
/// impresora física. Se guarda por dispositivo (`ImpresoraConfigStore`), no
/// viaja al backend.
class ConfigurarImpresoraScreen extends ConsumerStatefulWidget {
  const ConfigurarImpresoraScreen({super.key});

  @override
  ConsumerState<ConfigurarImpresoraScreen> createState() => _ConfigurarImpresoraScreenState();
}

class _ConfigurarImpresoraScreenState extends ConsumerState<ConfigurarImpresoraScreen> {
  final _ipController = TextEditingController();
  final _puertoController = TextEditingController(text: '9100');
  final _anchoController = TextEditingController();
  final _altoController = TextEditingController();

  bool _inicializado = false;
  bool _guardando = false;
  bool _probando = false;
  String? _mensaje;
  bool _mensajeEsError = false;

  void _inicializar(ImpresoraConfig config) {
    if (_inicializado) return;
    _inicializado = true;
    _ipController.text = config.ip ?? '';
    _puertoController.text = config.puerto.toString();
    _anchoController.text = _fmtMm(config.anchoMm);
    _altoController.text = _fmtMm(config.altoMm);
  }

  String _fmtMm(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _ipController.dispose();
    _puertoController.dispose();
    _anchoController.dispose();
    _altoController.dispose();
    super.dispose();
  }

  ImpresoraConfig _configActual() {
    return ImpresoraConfig(
      ip: _ipController.text.trim(),
      puerto: int.tryParse(_puertoController.text.trim()) ?? 9100,
      anchoMm: double.tryParse(_anchoController.text.trim().replaceAll(',', '.')) ?? 60,
      altoMm: double.tryParse(_altoController.text.trim().replaceAll(',', '.')) ?? 40,
    );
  }

  Future<void> _probarConexion() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _mensaje = 'Ingresá la IP de la impresora primero';
        _mensajeEsError = true;
      });
      return;
    }
    final puerto = int.tryParse(_puertoController.text.trim()) ?? 9100;

    setState(() {
      _probando = true;
      _mensaje = null;
    });
    try {
      await ref.read(impresoraServiceProvider).probarConexion(ip: ip, puerto: puerto);
      if (!mounted) return;
      setState(() {
        _mensaje = 'Conexión exitosa con $ip:$puerto';
        _mensajeEsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = e.toString();
        _mensajeEsError = true;
      });
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _mensaje = null;
    });
    try {
      await ref.read(impresoraConfigControllerProvider.notifier).guardar(_configActual());
      if (!mounted) return;
      setState(() {
        _mensaje = 'Configuración guardada';
        _mensajeEsError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mensaje = e.toString();
        _mensajeEsError = true;
      });
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(impresoraConfigControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar impresora')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.erTx))),
        data: (config) {
          _inicializar(config);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              const Text(
                'Impresora de etiquetas conectada por red (WiFi) — se imprime mandando el comando directo a su IP. Qué datos lleva cada etiqueta se configura por receta, no acá.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Text('CONEXIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'IP de la impresora', hintText: '192.168.1.50'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _puertoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Puerto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _probando ? null : _probarConexion,
                icon: _probando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_probando ? 'Probando...' : 'Probar conexión'),
              ),
              const SizedBox(height: 24),
              const Text('TAMAÑO DE LA ETIQUETA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in TamanoEtiqueta.opciones)
                    ChoiceChip(
                      label: Text(t.label),
                      selected: _anchoController.text == _fmtMm(t.anchoMm) && _altoController.text == _fmtMm(t.altoMm),
                      onSelected: (_) => setState(() {
                        _anchoController.text = _fmtMm(t.anchoMm);
                        _altoController.text = _fmtMm(t.altoMm);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _anchoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Ancho (mm)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _altoController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Alto (mm)'),
                    ),
                  ),
                ],
              ),
              if (_mensaje != null) ...[
                const SizedBox(height: 16),
                Text(_mensaje!, style: TextStyle(color: _mensajeEsError ? AppColors.erTx : AppColors.okTx)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando...' : 'Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
