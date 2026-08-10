import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/recepcion_oc_providers.dart';
import '../application/recepcion_providers.dart';
import '../domain/orden_compra_models.dart';

String _fmtQty(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

/// Fecha mínima de vencimiento aceptable para un producto con vida útil
/// configurada: hoy + vidaUtilDias — mismo criterio que ya valida el
/// backend (`recepcion_confirmacion.py`) y la versión web del wizard.
DateTime? _fechaMinimaVencimiento(int? vidaUtilDias) {
  if (vidaUtilDias == null || vidaUtilDias <= 0) return null;
  final hoy = DateTime.now();
  return DateTime(hoy.year, hoy.month, hoy.day).add(Duration(days: vidaUtilDias));
}

/// Estado editable de un ítem de OC en pantalla — vive en la pantalla, no
/// se manda nada al backend hasta "Continuar". La OC ya está en la unidad
/// base del producto desde que se confirmó (ver
/// `oc_aprobaciones.py:oc_confirmar`), así que acá hay un solo campo de
/// cantidad; si `item.requierePesaje` es true, ese mismo campo es el peso
/// real que hay que cargar pesando — arranca vacío a propósito (no
/// precargado con lo pendiente) para que la persona no confirme sin pesar.
class _ItemFormState {
  _ItemFormState(this.item)
    : cantidadCtrl = TextEditingController(
        text: item.requierePesaje ? '' : _fmtQty(item.cantidadPendiente),
      ),
      rechazadaCtrl = TextEditingController(text: '0'),
      observacionCtrl = TextEditingController(),
      observacionRechazoCtrl = TextEditingController(),
      loteCtrl = TextEditingController();

  final OrdenCompraItemDetalle item;
  final TextEditingController cantidadCtrl;
  final TextEditingController rechazadaCtrl;
  final TextEditingController observacionCtrl;
  final TextEditingController observacionRechazoCtrl;
  final TextEditingController loteCtrl;
  DateTime? fechaVencimiento;
  DateTime? fechaFaenado;

  void dispose() {
    cantidadCtrl.dispose();
    rechazadaCtrl.dispose();
    observacionCtrl.dispose();
    observacionRechazoCtrl.dispose();
    loteCtrl.dispose();
  }

  /// `null` si está todo bien, o el mensaje de error a mostrar.
  String? validar() {
    final nombre = item.productoNombre;
    final pendiente = item.cantidadPendiente;
    final cantidad = double.tryParse(cantidadCtrl.text.trim().replaceAll(',', '.'));
    final rechazada = double.tryParse(rechazadaCtrl.text.trim().replaceAll(',', '.')) ?? 0;

    if (cantidad == null || cantidad <= 0) {
      return item.requierePesaje
          ? '$nombre: pesalo e ingresá el peso real.'
          : '$nombre: ingresá una cantidad válida.';
    }
    // Ya no se valida "superar lo pendiente" acá en ningún caso — esa
    // diferencia hacia arriba la resuelve el motor de Firmas al guardar
    // (OC_DIFERENCIA_PESO si es pesable, OC_EXCESO_CANTIDAD si no). Solo
    // queda el piso ("menos que lo pendiente" con observación libre), que
    // sigue exento para ítems pesables.
    if (cantidad < pendiente && !item.requierePesaje && observacionCtrl.text.trim().isEmpty) {
      return '$nombre: recibís menos de lo pendiente, indicá una observación.';
    }
    if (rechazada > 0 && observacionRechazoCtrl.text.trim().isEmpty) {
      return '$nombre: indicá el motivo del rechazo.';
    }
    if (item.requiereLote && loteCtrl.text.trim().isEmpty) {
      return '$nombre: el producto requiere lote.';
    }
    if (item.requiereVencimiento && fechaVencimiento == null) {
      return '$nombre: el producto requiere fecha de vencimiento.';
    }
    if (item.requiereFaena && fechaFaenado == null) {
      return '$nombre: el producto requiere fecha de faena.';
    }
    if (fechaVencimiento != null && fechaFaenado != null && fechaVencimiento!.isBefore(fechaFaenado!)) {
      return '$nombre: el vencimiento no puede ser anterior a la faena.';
    }
    final minVenc = _fechaMinimaVencimiento(item.vidaUtilDias);
    if (minVenc != null && fechaVencimiento != null && fechaVencimiento!.isBefore(minVenc)) {
      return '$nombre: tiene vida útil de ${item.vidaUtilDias} días, el vencimiento no puede ser anterior a ${formatFecha(minVenc)}.';
    }
    return null;
  }
}

/// Paso 3+4+5 del flujo "Recibir OC": tarjetas por producto (cantidad
/// aceptada / rechazada + motivo si corresponde, lote/vencimiento/faena
/// según el producto) y al continuar se crea la recepción desde la OC
/// (`POST /recepciones/desde-oc`), se completa cada ítem con lo cargado
/// (`PATCH /recepciones/items/{id}`) y se entra al detalle de la recepción
/// ya existente (`RecepcionDetalleScreen`) para confirmarla — como
/// cualquier recepción manual, no se duplica esa lógica acá.
class RecibirOcItemsScreen extends ConsumerStatefulWidget {
  const RecibirOcItemsScreen({super.key, required this.idOc});

  final int idOc;

  @override
  ConsumerState<RecibirOcItemsScreen> createState() => _RecibirOcItemsScreenState();
}

class _RecibirOcItemsScreenState extends ConsumerState<RecibirOcItemsScreen> {
  final Map<int, _ItemFormState> _forms = {};
  bool _formsListos = false;
  bool _guardando = false;

  @override
  void dispose() {
    for (final f in _forms.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _prepararForms(List<OrdenCompraItemDetalle> items) {
    if (_formsListos) return;
    for (final item in items) {
      _forms[item.idOcItem] = _ItemFormState(item);
    }
    _formsListos = true;
  }

  Future<void> _elegirFecha(_ItemFormState form, {required bool esVencimiento}) async {
    final ahora = DateTime.now();
    final primero = DateTime(ahora.year - 2);
    final ultimo = DateTime(ahora.year + 5);
    final minVenc = _fechaMinimaVencimiento(form.item.vidaUtilDias);
    final elegida = await showDatePicker(
      context: context,
      initialDate: esVencimiento
          ? (form.fechaVencimiento ?? minVenc ?? form.fechaFaenado ?? ahora)
          : (form.fechaFaenado ?? ahora),
      firstDate: esVencimiento ? (minVenc ?? form.fechaFaenado ?? primero) : primero,
      lastDate: esVencimiento ? ultimo : (form.fechaVencimiento ?? ultimo),
    );
    if (elegida == null) return;
    setState(() {
      if (esVencimiento) {
        form.fechaVencimiento = elegida;
      } else {
        form.fechaFaenado = elegida;
      }
    });
  }

  Future<void> _continuar(List<OrdenCompraItemDetalle> items) async {
    for (final item in items) {
      final error = _forms[item.idOcItem]!.validar();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }

    setState(() => _guardando = true);
    try {
      final repo = ref.read(recepcionRepositoryProvider);
      final resultado = await repo.crearDesdeOc(idOc: widget.idOc);

      // Los ítems recién importados llegan con la cantidad pendiente
      // completa (ya en unidad base) y sin lote/vencimiento/faena/rechazo (el
      // backend los inserta así por defecto) — se completan acá con lo
      // cargado en pantalla, antes de ir al detalle a confirmar.
      final pendientesAutorizacion = <String>[];

      for (final importado in resultado.itemsImportados) {
        final form = _forms[importado.idOcItem];
        if (form == null) continue;
        final cantidad = double.parse(form.cantidadCtrl.text.trim().replaceAll(',', '.'));
        final rechazada = double.tryParse(form.rechazadaCtrl.text.trim().replaceAll(',', '.')) ?? 0;
        final itemResultado = await repo.editarItem(
          idRecepcionItem: importado.idRecepcionItem,
          expectedVersion: 1,
          cantidad: cantidad,
          cantidadRechazada: rechazada,
          loteProveedor: form.loteCtrl.text.trim().isEmpty ? null : form.loteCtrl.text.trim(),
          fechaVencimiento: form.fechaVencimiento,
          fechaFaenado: form.fechaFaenado,
          observacion: form.observacionCtrl.text.trim().isEmpty ? null : form.observacionCtrl.text.trim(),
          observacionRechazo:
              form.observacionRechazoCtrl.text.trim().isEmpty ? null : form.observacionRechazoCtrl.text.trim(),
        );

        if (itemResultado.diferenciaPeso?.pendiente == true) {
          final pct = itemResultado.diferenciaPeso!.porcentajeDiferencia;
          pendientesAutorizacion.add(
            '${form.item.productoNombre}${pct != null ? ' (${pct.toStringAsFixed(2)}% de diferencia de peso)' : ''}',
          );
        }
        if (itemResultado.excesoCantidad?.pendiente == true) {
          final pct = itemResultado.excesoCantidad!.porcentajeVariacion;
          pendientesAutorizacion.add(
            '${form.item.productoNombre}${pct != null ? ' (${pct.toStringAsFixed(2)}% de exceso de cantidad)' : ''}',
          );
        }
      }

      ref.invalidate(recepcionesRecientesProvider);
      ref.invalidate(recepcionListadoProvider);
      if (!mounted) return;

      if (pendientesAutorizacion.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Diferencias pendientes de autorización'),
            content: Text(
              'Hay diferencias pendientes de autorización en: '
              '${pendientesAutorizacion.join(', ')}.\n\n'
              'No vas a poder confirmar la recepción hasta que se resuelvan desde '
              'Firmas · Solicitudes.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
            ],
          ),
        );
      }

      if (!mounted) return;
      context.pushReplacement('/recepcion/${resultado.recepcion.idRecepcion}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recepcionOcDetalleProvider(widget.idOc));

    return Scaffold(
      appBar: AppBar(title: const Text('Ítems a recibir')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (detalle) {
          if (detalle.items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Esta OC no tiene ítems pendientes para recibir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }

          _prepararForms(detalle.items);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    Text(
                      detalle.header.codigo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text),
                    ),
                    Text(
                      detalle.header.proveedorNombre,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    for (final item in detalle.items) ...[
                      _OcItemCard(
                        form: _forms[item.idOcItem]!,
                        onElegirVencimiento: () => _elegirFecha(_forms[item.idOcItem]!, esVencimiento: true),
                        onElegirFaena: () => _elegirFecha(_forms[item.idOcItem]!, esVencimiento: false),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: ElevatedButton(
                  onPressed: _guardando ? null : () => _continuar(detalle.items),
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Continuar'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta de un ítem. Widget con estado propio: escucha sus propios
/// controllers para mostrar/ocultar "motivo de rechazo" y "observación"
/// (condicionados a lo que la persona va tipeando) sin pedirle a la
/// pantalla entera que se reconstruya en cada tecla.
class _OcItemCard extends StatefulWidget {
  const _OcItemCard({
    required this.form,
    required this.onElegirVencimiento,
    required this.onElegirFaena,
  });

  final _ItemFormState form;
  final VoidCallback onElegirVencimiento;
  final VoidCallback onElegirFaena;

  @override
  State<_OcItemCard> createState() => _OcItemCardState();
}

class _OcItemCardState extends State<_OcItemCard> {
  @override
  void initState() {
    super.initState();
    widget.form.cantidadCtrl.addListener(_onChanged);
    widget.form.rechazadaCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.form.cantidadCtrl.removeListener(_onChanged);
    widget.form.rechazadaCtrl.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final item = form.item;
    final pendiente = item.cantidadPendiente;
    final cantidad = double.tryParse(form.cantidadCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final rechazada = double.tryParse(form.rechazadaCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final requiereObservacion = cantidad < pendiente && !item.requierePesaje;
    final requiereMotivoRechazo = rechazada > 0;
    final minVenc = _fechaMinimaVencimiento(item.vidaUtilDias);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.inventory_2_outlined, color: AppColors.accentDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productoNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    if (item.requierePesaje)
                      const Text(
                        'Pesable',
                        style: TextStyle(fontSize: 11, color: AppColors.accentDark, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              Text(
                'Pend. ${_fmtQty(pendiente)} ${item.unidadSimbolo}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: form.cantidadCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: item.requierePesaje
                        ? 'Peso real (${item.unidadSimbolo})'
                        : 'Cantidad a recibir',
                    helperText: item.requierePesaje ? 'Pesalo y cargá el valor real' : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: form.rechazadaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Rechazada'),
                ),
              ),
            ],
          ),
          if (requiereMotivoRechazo) ...[
            const SizedBox(height: 10),
            TextField(
              controller: form.observacionRechazoCtrl,
              decoration: const InputDecoration(labelText: 'Motivo del rechazo *'),
            ),
          ],
          if (requiereObservacion) ...[
            const SizedBox(height: 10),
            TextField(
              controller: form.observacionCtrl,
              decoration: const InputDecoration(labelText: '¿Por qué llega menos? *'),
            ),
          ],
          if (item.requiereLote) ...[
            const SizedBox(height: 10),
            TextField(
              controller: form.loteCtrl,
              decoration: const InputDecoration(labelText: 'Lote proveedor *'),
            ),
          ],
          if (item.requiereVencimiento) ...[
            const SizedBox(height: 10),
            _FechaField(
              label: 'Fecha de vencimiento *',
              fecha: form.fechaVencimiento,
              onTap: widget.onElegirVencimiento,
            ),
            if (minVenc != null) ...[
              const SizedBox(height: 4),
              Text(
                'Vida útil ${item.vidaUtilDias} días · mín. ${formatFecha(minVenc)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: form.fechaVencimiento != null && form.fechaVencimiento!.isBefore(minVenc)
                      ? AppColors.erTx
                      : AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
          if (item.requiereFaena) ...[
            const SizedBox(height: 10),
            _FechaField(
              label: 'Fecha de faenado *',
              fecha: form.fechaFaenado,
              onTap: widget.onElegirFaena,
            ),
          ],
        ],
      ),
    );
  }
}

/// Mismo widget que `_FechaField` de `agregar_item_screen.dart` — se
/// duplica localmente por el mismo motivo (no hay carpeta de widgets
/// compartidos en este proyecto).
class _FechaField extends StatelessWidget {
  const _FechaField({required this.label, required this.fecha, required this.onTap});

  final String label;
  final DateTime? fecha;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fecha != null ? formatFecha(fecha!) : 'Elegir fecha',
                style: TextStyle(color: fecha == null ? AppColors.faint : AppColors.text),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
