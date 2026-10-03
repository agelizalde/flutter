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
///
/// **Jerarquía visual (rediseño 2026-09)**: el caso de uso normal es
/// pickear CON cajón (mejor trazabilidad/orden en depósito), así que el
/// bloque de buscar/escanear cajón va arriba, destacado con acento y un
/// badge "Recomendado". "Picking sin cajón" sigue siendo una acción de un
/// solo toque —no se le agregó fricción ni diálogo de confirmación—, pero
/// baja al final de la pantalla como link secundario de bajo contraste, para
/// no competir visualmente con el flujo recomendado.
class CajonSelectorScreen extends ConsumerStatefulWidget {
  const CajonSelectorScreen({
    super.key,
    required this.idPedidoSubpedido,
    this.cajonActual,
    this.cajonObligatorio = false,
  });

  /// Subpedido que se está armando — el backend lo usa para rechazar cajones
  /// que ya tengan productos activos de OTRO subpedido (ver
  /// `_conflicto_pedido_en_cajon` en `picking_operario_service.py`).
  final int idPedidoSubpedido;
  final ContenedorPicking? cajonActual;

  /// `true` si Ajustes -> Operaciones -> Picking exige cajón para este
  /// almacén (`cajon_obligatorio`, ver `PickingConfig`) — oculta por
  /// completo el link de "picking sin cajón" en vez de dejarlo tocable y
  /// que el backend lo rechace recién al completar la tarea.
  final bool cajonObligatorio;

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
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Bloque recomendado: elegir cajón ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'RECOMENDADO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Escaneá o buscá el cajón',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pickear con cajón mejora el orden y la trazabilidad en depósito.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.sub),
                          ),
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
                                    filled: true,
                                    fillColor: AppColors.surface,
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
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
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
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(_encontrado),
                              child: const Text('Confirmar cajón'),
                            ),
                          ],
                        ],
                      ),
                    ),
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
            ),
            if (!widget.cajonObligatorio) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 4),
              // --- Alternativa secundaria: pickear sin cajón. Sigue siendo un
              // solo toque (sin fricción extra) — solo baja de jerarquía visual.
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(const SinCajonSeleccionado()),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.muted),
                  label: const Text(
                    'Hay productos que no entran en un cajón: pickear sin cajón',
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Este almacén exige cajón para pickear.',
                  style: TextStyle(color: AppColors.faint, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
