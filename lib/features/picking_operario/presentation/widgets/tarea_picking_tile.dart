import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/barcode_scanner_screen.dart';
import '../../application/picking_providers.dart';
import '../../domain/picking_models.dart';
import 'devolver_item_sheet.dart';
import 'modificar_cantidad_sheet.dart';

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Tile de una tarea de picking. Las pendientes son tocables y abren el
/// bottom sheet de completar (mismo patrón visual que `_BuscarUbicacionSheet`
/// de Traslados: `showModalBottomSheet` + `Container` con esquinas
/// redondeadas arriba + drag-handle manual).
///
/// El menú de tres puntos con "Modificar cantidad"/"Cancelar tarea" (acciones
/// de supervisor) que vivía acá se sacó de esta pantalla a pedido explícito
/// (2026-09-12) — "Modificar cantidad" sigue siendo alcanzable desde dentro
/// de `_CompletarTareaSheet` cuando la cantidad ingresada supera lo
/// reservado (`_abrirModificarCantidad`, más abajo), pero "Cancelar tarea"
/// (`CancelarTareaSheet`) quedó sin ningún punto de entrada en la app — la
/// config `permite_cancelar_tarea`/`cancelar_requiere_supervisor` de Ajustes
/// -> Operaciones -> Picking no tiene efecto hasta que se le busque un lugar
/// nuevo.
class TareaPickingTile extends ConsumerWidget {
  const TareaPickingTile({super.key, required this.tarea, required this.idSesion, required this.idPedidoSubpedido});

  final TareaPicking tarea;
  final int idSesion;
  final int idPedidoSubpedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = tarea.completada;
    final cancelled = tarea.cancelada;
    final config = ref.watch(pickingConfigProvider(idPedidoSubpedido)).value;
    // No depende de que el almacén pickee con contenedor: se resuelve
    // directo del `id_picking_item` de la tarea (ver `puede_devolver` en
    // `get_mis_tareas`, backend), así que también funciona con
    // `usa_contenedor=false` — antes la única forma de devolver era
    // tocar el chip de cajón activo en `PickingTrabajoScreen`.
    final puedeDevolverAhora = done &&
        tarea.idPickingItem != null &&
        tarea.puedeDevolver &&
        (config?.permiteDevolverItem ?? true);

    return Material(
      color: done ? AppColors.okBg : cancelled ? AppColors.erBg : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: (done || cancelled)
            ? null
            : () => _abrirCompletar(context, config),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF22C55E)
                      : cancelled
                          ? AppColors.erTx
                          : AppColors.accentSoft,
                ),
                child: Icon(
                  done ? Icons.check : cancelled ? Icons.close : Icons.shopping_basket_outlined,
                  size: 18,
                  color: done || cancelled ? Colors.white : AppColors.accentDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tarea.productoNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${tarea.ubicacionCodigo} · ${_fmtCantidad(tarea.cantidad)} ${tarea.unidadSimbolo}'
                      '${tarea.pickingPorPeso ? ' · pesable' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    if (done && tarea.cantidadPickeada != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pickeado: ${_fmtCantidad(tarea.cantidadPickeada!)} ${tarea.unidadSimbolo}'
                        '${tarea.contenedorIdentificador != null ? ' · ${tarea.contenedorIdentificador}' : ''}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.okTx),
                      ),
                    ],
                  ],
                ),
              ),
              if (puedeDevolverAhora)
                TextButton(
                  onPressed: () => _devolver(context, ref),
                  child: const Text('Devolver'),
                ),
              if (!done && !cancelled) const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _devolver(BuildContext context, WidgetRef ref) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DevolverItemSheet(
        idPickingItem: tarea.idPickingItem!,
        productoNombre: tarea.productoNombre,
        cantidadPickeada: tarea.cantidadPickeada!,
        unidadSimbolo: tarea.unidadSimbolo,
      ),
    );
    if (resultado == true) {
      ref.invalidate(misTareasProvider);
    }
  }

  Future<void> _abrirCompletar(BuildContext context, PickingConfig? config) async {
    final ajusteDiferencia = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CompletarTareaSheet(tarea: tarea, idSesion: idSesion, config: config),
    );
    if (ajusteDiferencia != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚖ Se ajustó el stock automáticamente (+${_fmtCantidad(ajusteDiferencia)}) '
            'por la diferencia de peso.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

class _CompletarTareaSheet extends ConsumerStatefulWidget {
  const _CompletarTareaSheet({required this.tarea, required this.idSesion, required this.config});

  final TareaPicking tarea;
  final int idSesion;

  /// `null` mientras `pickingConfigProvider` todavía no resolvió — en ese
  /// caso se asumen los defaults (pickeo parcial permitido, sin tope de
  /// pesaje) y el backend sigue validando igual si algo no encaja.
  final PickingConfig? config;

  @override
  ConsumerState<_CompletarTareaSheet> createState() => _CompletarTareaSheetState();
}

class _CompletarTareaSheetState extends ConsumerState<_CompletarTareaSheet> {
  late final _cantidadController = TextEditingController(text: _fmtCantidad(widget.tarea.cantidad));
  bool _confirmando = false;
  String? _error;

  /// Código de barras que matcheó contra `tarea.codigosBarra` — una vez
  /// seteado, recién ahí se muestra el paso de cantidad (ver
  /// `_mostrarPasoEscaneo` en `build`). `null` también significa "no
  /// escaneó todavía" mientras el paso de escaneo sigue en pantalla.
  String? _codigoVerificado;
  String? _errorEscaneo;

  /// El operario tocó "Continuar sin escanear" — solo posible si
  /// `escaneoProductoObligatorio` está apagado (el botón ni se muestra si
  /// está prendido).
  bool _saltarEscaneo = false;

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;
    final normalizado = codigo.trim();
    if (widget.tarea.codigosBarra.contains(normalizado)) {
      setState(() {
        _codigoVerificado = normalizado;
        _errorEscaneo = null;
      });
    } else {
      setState(() => _errorEscaneo = 'Ese código no corresponde a "${widget.tarea.productoNombre}" — probá de nuevo.');
    }
  }

  Future<void> _abrirModificarCantidad() async {
    final config = widget.config;
    if (config == null) return;
    final cambio = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModificarCantidadSheet(tarea: widget.tarea, config: config),
    );
    if (cambio == true && mounted) {
      // La tarea que este sheet tiene en memoria quedó con la cantidad
      // vieja — se cierra para que el operario la vuelva a abrir con el
      // valor ya actualizado desde `misTareasProvider` (invalidado por
      // `ModificarCantidadSheet`), en vez de arrastrar acá un segundo
      // estado desincronizado.
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmar() async {
    final cantidad = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) {
      setState(() => _error = 'Ingresá una cantidad válida');
      return;
    }
    if (!widget.tarea.pickingPorPeso && cantidad > widget.tarea.cantidad) {
      setState(() => _error = 'Supera lo reservado (${_fmtCantidad(widget.tarea.cantidad)}) — pedile a un '
          'supervisor que modifique la cantidad primero');
      return;
    }
    if (!widget.tarea.pickingPorPeso &&
        cantidad < widget.tarea.cantidad &&
        widget.config?.permitePickeoParcial == false) {
      setState(() => _error = 'Este almacén no permite pickeo parcial — pickeá la cantidad completa '
          '(${_fmtCantidad(widget.tarea.cantidad)}) o cancelá la tarea.');
      return;
    }

    setState(() {
      _confirmando = true;
      _error = null;
    });
    try {
      final resultado = await ref.read(pickingRepositoryProvider).completarTarea(
        idStockReservaDetalle: widget.tarea.idStockReservaDetalle,
        idSesion: widget.idSesion,
        cantidadPickeada: cantidad,
        codigoBarra: _codigoVerificado,
      );
      ref.invalidate(misTareasProvider);
      if (!mounted) return;
      Navigator.of(context).pop(resultado.ajusteStockDiferencia);
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
    final tarea = widget.tarea;
    final cantidadIngresada = double.tryParse(_cantidadController.text.replaceAll(',', '.'));
    final esParcial = cantidadIngresada != null && cantidadIngresada > 0 && cantidadIngresada < tarea.cantidad;
    final excedeReservado =
        !tarea.pickingPorPeso && cantidadIngresada != null && cantidadIngresada > tarea.cantidad;
    final puedeModificarDesdeAca = excedeReservado && (widget.config?.permiteModificarCantidad ?? false);

    // "Escaneo de producto" (Ajustes -> Operaciones -> Picking -> APP -
    // Picking): solo aplica si el producto tiene algún código activo
    // cargado — si no tiene ninguno, no hay nada que escanear y el sheet se
    // comporta exactamente igual que si la config estuviera apagada.
    final ofreceEscaneo = (widget.config?.escaneoProductoHabilitado ?? false) && tarea.codigosBarra.isNotEmpty;
    final escaneoObligatorio = widget.config?.escaneoProductoObligatorio ?? false;
    final mostrarPasoEscaneo = ofreceEscaneo && _codigoVerificado == null && !_saltarEscaneo;

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
              Text(
                tarea.productoNombre,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                '${tarea.ubicacionCodigo} · pedido: ${_fmtCantidad(tarea.cantidad)} ${tarea.unidadSimbolo}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              if (mostrarPasoEscaneo) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_scanner, size: 40, color: AppColors.accent),
                      const SizedBox(height: 10),
                      const Text(
                        'Escaneá el producto',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Confirmá que es el producto correcto antes de cargar la cantidad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: AppColors.sub),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _escanear,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear código de barras'),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_errorEscaneo != null) ...[
                  const SizedBox(height: 10),
                  Text(_errorEscaneo!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
                ],
                if (!escaneoObligatorio) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() => _saltarEscaneo = true),
                      child: const Text('Continuar sin escanear'),
                    ),
                  ),
                ],
              ] else ...[
                if (_codigoVerificado != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.okBg, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check_circle, size: 14, color: AppColors.okTx),
                        SizedBox(width: 4),
                        Text('Producto verificado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.okTx)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                TextField(
                  controller: _cantidadController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: tarea.pickingPorPeso
                        ? 'Peso real (${tarea.unidadSimbolo})'
                        : 'Cantidad a pickear (${tarea.unidadSimbolo})',
                  ),
                ),
                if (tarea.pickingPorPeso) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.config?.ajusteAutomaticoPesoHabilitado == false
                        ? '⚖ Producto pesable: no puede superar el stock registrado en el sistema para este almacén.'
                        : '⚖ Producto pesable: podés ingresar cualquier peso real, puede diferir de lo pedido.',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
                if (esParcial && widget.config?.permitePickeoParcial != false) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '⚡ Pickeo parcial — se creará una tarea nueva por el resto '
                      '(${_fmtCantidad(tarea.cantidad - cantidadIngresada)} ${tarea.unidadSimbolo})',
                      style: const TextStyle(fontSize: 12, color: AppColors.waTx, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
                  if (puedeModificarDesdeAca) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _abrirModificarCantidad,
                      child: const Text('Pedir modificación de cantidad'),
                    ),
                  ],
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
                      : const Text('Confirmar picking'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
