import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../application/picking_providers.dart';
import '../domain/picking_models.dart';

/// Pantalla (pusheada con `Navigator`, no es ruta de go_router — mismo
/// tratamiento que `BarcodeScannerScreen`) para buscar/escanear un cajón por
/// código y confirmarlo. Devuelve, via `Navigator.pop`: un [ContenedorPicking]
/// si se eligió uno, `null` si se canceló (sin cambios), o
/// [SinCajonSeleccionado] si el operario eligió explícitamente pickear sin
/// cajón (hay productos que no entran en uno). Se usa tanto para el cajón
/// obligatorio al iniciar una zona sin cajón activo, como para "Cambiar
/// cajón" desde `PickingTrabajoScreen`.
class CajonSelectorScreen extends ConsumerStatefulWidget {
  const CajonSelectorScreen({super.key, required this.idPedidoSubpedido, this.cajonActual});

  /// Subpedido que se está armando — el backend lo usa para rechazar cajones
  /// que ya tengan productos activos de OTRO subpedido (ver
  /// `_conflicto_pedido_en_cajon` en `picking_operario_service.py`).
  final int idPedidoSubpedido;
  final ContenedorPicking? cajonActual;

  @override
  ConsumerState<CajonSelectorScreen> createState() => _CajonSelectorScreenState();
}

class _CajonSelectorScreenState extends ConsumerState<CajonSelectorScreen> {
  final _controller = TextEditingController();
  bool _buscando = false;
  String? _error;
  ContenedorPicking? _encontrado;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final codigo = _controller.text.trim();
    if (codigo.isEmpty) return;
    setState(() {
      _buscando = true;
      _error = null;
      _encontrado = null;
    });
    try {
      final cont = await ref
          .read(pickingRepositoryProvider)
          .buscarContenedor(codigo, idPedidoSubpedido: widget.idPedidoSubpedido);
      if (!mounted) return;
      setState(() => _encontrado = cont);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;
    _controller.text = codigo;
    await _buscar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar cajón')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escaneá el código de barras o escribí el identificador del cajón.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(const SinCajonSeleccionado()),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Picking sin cajón'),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 14),
              child: Text(
                'Hay productos que no entran en un cajón — podés pickear la zona igual.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                    decoration: InputDecoration(
                      hintText: 'Ej: CAJ-001',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                        tooltip: 'Escanear',
                        onPressed: _escanear,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Buscar'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppColors.erTx, fontSize: 13)),
            ],
            if (_encontrado != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _encontrado!.identificador,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                    ),
                    if (_encontrado!.tipoNombre != null) ...[
                      const SizedBox(height: 2),
                      Text(_encontrado!.tipoNombre!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                    if (_encontrado!.ubicacionCodigo != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ubicación: ${_encontrado!.ubicacionCodigo}',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_encontrado),
                child: const Text('Confirmar cajón'),
              ),
            ],
            if (widget.cajonActual != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Mantener cajón actual: ${widget.cajonActual!.identificador}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
