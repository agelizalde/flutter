import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/recepcion_oc_providers.dart';
import '../application/recepcion_providers.dart';
import '../domain/orden_compra_models.dart';
import '../domain/recepcion_models.dart';

// Azul de la app (`AppColors.accent`) para fondo, encabezado, píldoras y
// botón; los tildes de ítem listo van en verde (`_verde`).
const _pastel = Color(0xFFDBEAFE);
const _fuerte = AppColors.accent;
const _oscuro = AppColors.accentDark;
const _verde = Color(0xFF16A34A);

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
  _ItemFormState(this.item, {this.existente})
    : cantidadCtrl = TextEditingController(
        text: existente != null
            ? _fmtQty(existente.cantidad)
            : (item.requierePesaje ? '' : _fmtQty(item.cantidadPendiente)),
      ),
      rechazadaCtrl = TextEditingController(text: existente != null ? _fmtQty(existente.cantidadRechazada) : '0'),
      observacionCtrl = TextEditingController(text: existente?.observacion ?? ''),
      observacionRechazoCtrl = TextEditingController(text: existente?.observacionRechazo ?? ''),
      loteCtrl = TextEditingController(text: existente?.loteProveedor ?? ''),
      fechaVencimiento = existente?.fechaVencimiento,
      fechaFaenado = existente?.fechaFaenado;

  final OrdenCompraItemDetalle item;

  /// Línea ya existente de la recepción que se está reabriendo (`null` al
  /// crear). Se actualiza con la respuesta de cada PATCH para que un
  /// reintento use el `row_version` nuevo.
  RecepcionItem? existente;

  final TextEditingController cantidadCtrl;
  final TextEditingController rechazadaCtrl;
  final TextEditingController observacionCtrl;
  final TextEditingController observacionRechazoCtrl;
  final TextEditingController loteCtrl;
  DateTime? fechaVencimiento;
  DateTime? fechaFaenado;

  /// Quitado a mano con la X de la tarjeta: no se recibe en esta recepción
  /// (queda todo pendiente en la OC) y no se valida nada de lo cargado —
  /// así un ítem que no vino no frena por lote/vencimiento/etc.
  bool quitado = false;

  void dispose() {
    cantidadCtrl.dispose();
    rechazadaCtrl.dispose();
    observacionCtrl.dispose();
    observacionRechazoCtrl.dispose();
    loteCtrl.dispose();
  }

  double? get cantidad => double.tryParse(cantidadCtrl.text.trim().replaceAll(',', '.'));
  double get rechazada => double.tryParse(rechazadaCtrl.text.trim().replaceAll(',', '.')) ?? 0;

  /// Aceptado 0 y rechazado 0: el proveedor no trajo nada de este ítem. El
  /// backend no admite un ítem 0/0, así que se quita de la recepción al
  /// continuar y queda todo pendiente en la OC.
  bool get noVino => cantidad == 0 && rechazada <= 0;

  /// No entra en la recepción: quitado a mano o cargado 0/0.
  bool get seQuita => quitado || noVino;

  /// Ítem resuelto: entra en la recepción, tiene cantidad y pasa `validar()` — enciende el
  /// tilde de la tarjeta y cuenta en "listos" del encabezado.
  bool get listo => !seQuita && cantidad != null && validar() == null;

  /// Todo lo que el usuario tipea en la tarjeta — para que el encabezado y
  /// el tilde se actualicen al vuelo.
  Listenable get cambios =>
      Listenable.merge([cantidadCtrl, rechazadaCtrl, observacionCtrl, observacionRechazoCtrl, loteCtrl]);

  /// `null` si está todo bien, o el mensaje de error a mostrar.
  String? validar() {
    if (quitado) return null;
    final nombre = item.productoNombre;
    final pendiente = item.cantidadPendiente;
    final cantidad = this.cantidad;
    final rechazada = this.rechazada;

    if (cantidad == null || cantidad < 0 || rechazada < 0) {
      return item.requierePesaje ? '$nombre: pesalo e ingresá el peso real.' : '$nombre: ingresá una cantidad válida.';
    }
    if (noVino) return null;
    // Ya no se valida "superar lo pendiente" acá en ningún caso — esa
    // diferencia hacia arriba la resuelve el motor de Firmas al guardar
    // (OC_DIFERENCIA_PESO si es pesable, OC_EXCESO_CANTIDAD si no). Solo
    // queda el piso ("menos que lo pendiente" con observación libre), que
    // sigue exento para ítems pesables. Lo rechazado (con su motivo) también
    // explica la diferencia, igual que en el backend.
    if (cantidad + rechazada < pendiente && !item.requierePesaje && observacionCtrl.text.trim().isEmpty) {
      return '$nombre: recibís menos de lo pendiente, indicá una observación.';
    }
    if (rechazada > 0 && observacionRechazoCtrl.text.trim().isEmpty) {
      return '$nombre: indicá el motivo del rechazo.';
    }
    // Rechazo total (aceptado 0): no entra nada a stock, no hace falta
    // lote/vencimiento/faena (mismo criterio que el backend).
    if (cantidad == 0) return null;
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
///
/// Con `idRecepcion` es "Reabrir recepción" (desde `RecepcionDetalleScreen`):
/// las tarjetas arrancan con lo ya cargado en esa recepción en BORRADOR y al
/// guardar se editan sus líneas (no se crea otra ni se agregan productos) y
/// se vuelve al detalle para confirmar.
class RecibirOcItemsScreen extends ConsumerStatefulWidget {
  const RecibirOcItemsScreen({super.key, required this.idOc, this.idRecepcion});

  final int idOc;
  final int? idRecepcion;

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

  void _prepararForms(List<OrdenCompraItemDetalle> items, {Map<int, RecepcionItem> existentes = const {}}) {
    if (_formsListos) return;
    for (final item in items) {
      final form = _ItemFormState(item, existente: existentes[item.idOcItem]);
      // Reabrir: un producto de la OC que sigue pendiente pero no está en
      // la recepción (se quitó antes) aparece con la X puesta; si se vuelve
      // a agregar, se suma a la recepción al guardar.
      if (widget.idRecepcion != null && form.existente == null) form.quitado = true;
      _forms[item.idOcItem] = form;
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
    if (items.every((item) => _forms[item.idOcItem]!.seQuita)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No quedó ningún ítem para recibir ni rechazar.')));
      return;
    }

    if (widget.idRecepcion != null) {
      await _guardarReapertura(items);
      return;
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
        if (form.seQuita) {
          await repo.quitarItem(idRecepcionItem: importado.idRecepcionItem, expectedVersion: 1);
          continue;
        }
        final cantidad = form.cantidad!;
        final rechazada = form.rechazada;
        final itemResultado = await repo.editarItem(
          idRecepcionItem: importado.idRecepcionItem,
          expectedVersion: 1,
          cantidad: cantidad,
          cantidadRechazada: rechazada,
          loteProveedor: form.loteCtrl.text.trim().isEmpty ? null : form.loteCtrl.text.trim(),
          fechaVencimiento: form.fechaVencimiento,
          fechaFaenado: form.fechaFaenado,
          observacion: form.observacionCtrl.text.trim().isEmpty ? null : form.observacionCtrl.text.trim(),
          observacionRechazo: form.observacionRechazoCtrl.text.trim().isEmpty
              ? null
              : form.observacionRechazoCtrl.text.trim(),
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
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))],
          ),
        );
      }

      if (!mounted) return;
      context.pushReplacement('/recepcion/${resultado.recepcion.idRecepcion}');
    } catch (e) {
      if (!mounted) return;

      // Red de seguridad: `recepcionOcBorradorExistenteProvider` ya debería
      // haber bloqueado la pantalla antes de llegar acá, pero si de todas
      // formas el backend rechaza con este 409 (ej. otra sesión creó el
      // borrador en el medio), hay que llevar a esa recepción en vez de
      // mostrar un error genérico y dejar que la persona reintente y
      // duplique la cantidad recibida.
      final appError = e is DioException ? e.error : null;
      if (appError is RecepcionBorradorExistenteException) {
        context.pushReplacement('/recepcion/${appError.idRecepcionExistente}');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Reabrir: edita las líneas existentes de la recepción (PATCH) con lo
  /// cargado en las tarjetas. Lo que se marca con la X (o queda 0/0) se
  /// quita y queda pendiente en la OC; nunca se agregan productos. Al terminar vuelve al
  /// detalle (`pop(true)`) para confirmar.
  Future<void> _guardarReapertura(List<OrdenCompraItemDetalle> items) async {
    setState(() => _guardando = true);
    try {
      final repo = ref.read(recepcionRepositoryProvider);
      final pendientesAutorizacion = <String>[];

      for (final item in items) {
        final form = _forms[item.idOcItem]!;
        final existente = form.existente;
        if (existente == null) {
          if (form.seQuita) continue;
          final agregado = await repo.agregarItem(
            idRecepcion: widget.idRecepcion!,
            idProducto: item.idProducto,
            idUnidadMedida: item.idUnidadMedida,
            idOrdenCompraItem: item.idOcItem,
            cantidad: form.cantidad!,
            cantidadRechazada: form.rechazada,
            loteProveedor: form.loteCtrl.text.trim().isEmpty ? null : form.loteCtrl.text.trim(),
            fechaVencimiento: form.fechaVencimiento,
            fechaFaenado: form.fechaFaenado,
            observacion: form.observacionCtrl.text.trim().isEmpty ? null : form.observacionCtrl.text.trim(),
            observacionRechazo: form.observacionRechazoCtrl.text.trim().isEmpty
                ? null
                : form.observacionRechazoCtrl.text.trim(),
          );
          // Si un paso posterior falla, el reintento la edita en vez de
          // volver a insertarla.
          form.existente = agregado;
          if (agregado.diferenciaPeso?.pendiente == true || agregado.excesoCantidad?.pendiente == true) {
            pendientesAutorizacion.add(item.productoNombre);
          }
          continue;
        }
        if (form.seQuita) {
          await repo.quitarItem(idRecepcionItem: existente.idRecepcionItem, expectedVersion: existente.rowVersion);
          continue;
        }
        final itemResultado = await repo.editarItem(
          idRecepcionItem: existente.idRecepcionItem,
          expectedVersion: existente.rowVersion,
          cantidad: form.cantidad!,
          cantidadRechazada: form.rechazada,
          loteProveedor: form.loteCtrl.text.trim().isEmpty ? null : form.loteCtrl.text.trim(),
          fechaVencimiento: form.fechaVencimiento,
          fechaFaenado: form.fechaFaenado,
          observacion: form.observacionCtrl.text.trim().isEmpty ? null : form.observacionCtrl.text.trim(),
          observacionRechazo: form.observacionRechazoCtrl.text.trim().isEmpty
              ? null
              : form.observacionRechazoCtrl.text.trim(),
        );
        form.existente = itemResultado;

        if (itemResultado.diferenciaPeso?.pendiente == true) {
          final pct = itemResultado.diferenciaPeso!.porcentajeDiferencia;
          pendientesAutorizacion.add(
            '${item.productoNombre}${pct != null ? ' (${pct.toStringAsFixed(2)}% de diferencia de peso)' : ''}',
          );
        }
        if (itemResultado.excesoCantidad?.pendiente == true) {
          final pct = itemResultado.excesoCantidad!.porcentajeVariacion;
          pendientesAutorizacion.add(
            '${item.productoNombre}${pct != null ? ' (${pct.toStringAsFixed(2)}% de exceso de cantidad)' : ''}',
          );
        }
      }

      ref.invalidate(recepcionDetalleProvider(widget.idRecepcion!));
      ref.invalidate(recepcionesRecientesProvider);
      ref.invalidate(recepcionListadoProvider);
      if (!mounted) return;

      if (pendientesAutorizacion.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Diferencias pendientes de autorización'),
            content: Text(
              'Hay diferencias pendientes de autorización en: '
              '${pendientesAutorizacion.join(', ')}.\n\n'
              'No vas a poder confirmar la recepción hasta que se resuelvan desde '
              'Firmas · Solicitudes.',
            ),
            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Entendido'))],
          ),
        );
      }

      if (!mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.idRecepcion != null) return _buildReapertura(widget.idRecepcion!);

    final async = ref.watch(recepcionOcDetalleProvider(widget.idOc));
    final borradorAsync = ref.watch(recepcionOcBorradorExistenteProvider(widget.idOc));

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: const Text('Ítems a recibir'), backgroundColor: _pastel),
      // Si la OC ya tiene una recepción en BORRADOR (p. ej. esperando que
      // se apruebe/firme un exceso de cantidad), hay que continuar esa en
      // vez de dejar que se cree otra y se duplique la cantidad recibida
      // (ver `recepcionOcBorradorExistenteProvider`). Si esta consulta
      // falla, no bloqueamos: el backend igual lo rechaza con 409 como red
      // de seguridad (ver el catch de `_continuar`).
      body: borradorAsync.maybeWhen(
        data: (borrador) =>
            borrador != null ? _BorradorExistenteAviso(idRecepcion: borrador.idRecepcion) : _buildItems(async),
        orElse: () => _buildItems(async),
      ),
    );
  }

  /// Reabrir: OC completa (no solo pendientes: una línea de la recepción
  /// podría ya no figurar como pendiente) cruzada con las líneas activas de
  /// la recepción — se muestran las que la recepción tiene, más las que
  /// siguen pendientes en la OC (nadie más las recibió) marcadas con la X.
  Widget _buildReapertura(int idRecepcion) {
    final ocAsync = ref.watch(recepcionOcDetalleCompletoProvider(widget.idOc));
    final recepcionAsync = ref.watch(recepcionDetalleProvider(idRecepcion));

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: Text('Reabrir recepción #$idRecepcion'), backgroundColor: _pastel),
      body: recepcionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (detalle) {
          final existentes = <int, RecepcionItem>{
            for (final it in detalle.items)
              if (it.idOrdenCompraItem != null) it.idOrdenCompraItem!: it,
          };
          final filtrado = ocAsync.whenData(
            (oc) => OrdenCompraDetalle(
              header: oc.header,
              items: [
                for (final it in oc.items)
                  if (existentes.containsKey(it.idOcItem) || it.cantidadPendiente > 0) it,
              ],
            ),
          );
          return _buildItems(filtrado, existentes: existentes);
        },
      ),
    );
  }

  Widget _buildItems(AsyncValue<OrdenCompraDetalle> async, {Map<int, RecepcionItem> existentes = const {}}) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            describeError(e),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.erTx),
          ),
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

        _prepararForms(detalle.items, existentes: existentes);
        final forms = [for (final item in detalle.items) _forms[item.idOcItem]!];

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_pastel, AppColors.pageBg],
              stops: [0, 0.4],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  children: [
                    ListenableBuilder(
                      listenable: Listenable.merge([for (final f in forms) f.cambios]),
                      builder: (context, _) => _EncabezadoOc(
                        codigo: detalle.header.codigo,
                        proveedor: detalle.header.proveedorNombre,
                        listos: forms.where((f) => f.listo).length,
                        total: forms.where((f) => !f.seQuita).length,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ResumenQuitados(total: detalle.items.length, quitados: forms.where((f) => f.quitado).length),
                    const SizedBox(height: 12),
                    for (final item in detalle.items) ...[
                      _OcItemCard(
                        form: _forms[item.idOcItem]!,
                        onToggleQuitar: () => setState(() {
                          final form = _forms[item.idOcItem]!;
                          form.quitado = !form.quitado;
                        }),
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
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: _guardando ? null : () => _continuar(detalle.items),
                    style: FilledButton.styleFrom(
                      backgroundColor: _oscuro,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.idRecepcion != null ? 'Guardar cambios' : 'Continuar',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Aviso de bloqueo cuando `recepcionOcBorradorExistenteProvider` encuentra
/// una recepción BORRADOR previa para esta OC — en vez de dejar que se
/// cargue el formulario de ítems (que terminaría creando una segunda
/// recepción y duplicando la cantidad recibida), lleva directo a
/// continuar la existente.
class _BorradorExistenteAviso extends StatelessWidget {
  const _BorradorExistenteAviso({required this.idRecepcion});

  final int idRecepcion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: _pastel, shape: BoxShape.circle),
              child: const Icon(Icons.inventory_2_outlined, size: 30, color: _oscuro),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta OC ya se empezó a recibir',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'No hace falta empezar de nuevo. Abrí la recepción, revisá que '
              'esté todo bien y confirmala.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.sub, fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => context.pushReplacement('/recepcion/$idRecepcion'),
                style: FilledButton.styleFrom(
                  backgroundColor: _oscuro,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Continuar recepción', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Recepción #$idRecepcion',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
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
    required this.onToggleQuitar,
    required this.onElegirVencimiento,
    required this.onElegirFaena,
  });

  final _ItemFormState form;
  final VoidCallback onToggleQuitar;
  final VoidCallback onElegirVencimiento;
  final VoidCallback onElegirFaena;

  @override
  State<_OcItemCard> createState() => _OcItemCardState();
}

class _OcItemCardState extends State<_OcItemCard> {
  @override
  void initState() {
    super.initState();
    widget.form.cambios.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.form.cambios.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final form = widget.form;
    final item = form.item;
    final pendiente = item.cantidadPendiente;
    final cantidad = form.cantidad ?? 0;
    final rechazada = form.rechazada;
    final noVino = form.noVino;
    final requiereObservacion = !noVino && cantidad + rechazada < pendiente && !item.requierePesaje;
    final requiereMotivoRechazo = rechazada > 0;
    // Con aceptado 0 no entra nada a stock: no se piden lote/vencimiento/faena.
    final pideDatosStock = cantidad > 0 || form.cantidad == null;
    final minVenc = _fechaMinimaVencimiento(item.vidaUtilDias);

    if (form.quitado) {
      return _ItemQuitadoCard(item: item, onVolverAgregar: widget.onToggleQuitar);
    }

    final listo = form.listo;
    final tema = Theme.of(context);
    // Campos blancos sobre la tarjeta (que se tiñe de pastel al quedar
    // lista) y foco en azul.
    final temaCampos = tema.copyWith(
      colorScheme: tema.colorScheme.copyWith(primary: _oscuro),
      inputDecorationTheme: tema.inputDecorationTheme.copyWith(
        fillColor: listo ? Colors.white : AppColors.soft,
        floatingLabelStyle: const TextStyle(color: _oscuro, fontWeight: FontWeight.w700),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fuerte, width: 1.6),
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: listo ? _pastel : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: listo ? _fuerte.withValues(alpha: 0.35) : Colors.transparent, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 14),
      child: Theme(
        data: temaCampos,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TildeItem(listo: listo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productoNombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pendiente: ${_fmtQty(pendiente)} ${item.unidadSimbolo}${item.requierePesaje ? ' · Pesable' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: listo ? _oscuro : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CantidadPill(
                  texto: form.cantidad == null ? '—' : '${_fmtQty(form.cantidad!)} ${item.unidadSimbolo}',
                  listo: listo,
                ),
                IconButton(
                  onPressed: widget.onToggleQuitar,
                  tooltip: 'Quitar de esta recepción',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: form.cantidadCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: item.requierePesaje ? 'Peso real (${item.unidadSimbolo})' : 'Cantidad a recibir',
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
                  if (noVino) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'No vino: se quita de esta recepción y queda pendiente en la OC.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.waTx, fontWeight: FontWeight.w600),
                    ),
                  ],
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
                  if (pideDatosStock && item.requiereLote) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: form.loteCtrl,
                      decoration: const InputDecoration(labelText: 'Lote proveedor *'),
                    ),
                  ],
                  if (pideDatosStock && item.requiereVencimiento) ...[
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
                  if (pideDatosStock && item.requiereFaena) ...[
                    const SizedBox(height: 10),
                    _FechaField(label: 'Fecha de faenado *', fecha: form.fechaFaenado, onTap: widget.onElegirFaena),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de la OC: código, proveedor y cuántos ítems ya están listos
/// (el contador da un saltito cada vez que cambia), con barra de avance.
class _EncabezadoOc extends StatelessWidget {
  const _EncabezadoOc({required this.codigo, required this.proveedor, required this.listos, required this.total});

  final String codigo;
  final String proveedor;
  final int listos;
  final int total;

  @override
  Widget build(BuildContext context) {
    final completo = total > 0 && listos == total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _fuerte.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: _fuerte, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      codigo,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink),
                    ),
                    Text(
                      proveedor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'ÍTEMS LISTOS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
              ),
              const Spacer(),
              TweenAnimationBuilder<double>(
                key: ValueKey(listos),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                builder: (context, v, child) => Transform.scale(scale: 1 + 0.25 * math.sin(math.pi * v), child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: completo ? _fuerte : _pastel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$listos/$total',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: completo ? Colors.white : _oscuro,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: total > 0 ? listos / total : 0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) =>
                  LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: _pastel, color: _fuerte),
            ),
          ),
        ],
      ),
    );
  }
}

/// Círculo de estado del ítem: vacío mientras falta algo, tilde verde (con
/// rebote) cuando queda listo.
class _TildeItem extends StatelessWidget {
  const _TildeItem({required this.listo});

  final bool listo;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: child,
      ),
      child: Container(
        key: ValueKey(listo),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listo ? _verde : Colors.transparent,
          border: Border.all(color: listo ? _verde : AppColors.borderStrong, width: 2),
        ),
        child: listo ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
      ),
    );
  }
}

/// Píldora con la cantidad cargada — gris mientras falta algo, azul cuando
/// el ítem queda listo.
class _CantidadPill extends StatelessWidget {
  const _CantidadPill({required this.texto, required this.listo});

  final String texto;
  final bool listo;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: const BoxConstraints(minWidth: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: listo ? _fuerte : AppColors.soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: listo ? _fuerte : AppColors.border),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: listo ? Colors.white : AppColors.faint),
      ),
    );
  }
}

/// "Recibís N de M ítems" — solo aparece cuando hay algo quitado, para que
/// quede claro que lo quitado no se pierde: sigue pendiente en la OC.
class _ResumenQuitados extends StatelessWidget {
  const _ResumenQuitados({required this.total, required this.quitados});

  final int total;
  final int quitados;

  @override
  Widget build(BuildContext context) {
    if (quitados == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 15, color: _oscuro),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tocá la X para quitar lo que no vas a recibir ahora.',
                style: TextStyle(fontSize: 12, color: _oscuro, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(14)),
      child: Text(
        'Recibís ${total - quitados} de $total ítems · $quitados quitado(s), quedan pendientes en la OC.',
        style: const TextStyle(fontSize: 12, color: AppColors.waTx, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Tarjeta compacta de un ítem quitado: no pide nada, solo deja volver a
/// agregarlo (conserva lo que se había cargado).
class _ItemQuitadoCard extends StatelessWidget {
  const _ItemQuitadoCard({required this.item, required this.onVolverAgregar});

  final OrdenCompraItemDetalle item;
  final VoidCallback onVolverAgregar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          const Icon(Icons.remove_circle_outline, size: 22, color: AppColors.faint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const Text(
                  'No se recibe ahora · queda pendiente en la OC',
                  style: TextStyle(fontSize: 11.5, color: AppColors.faint),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onVolverAgregar,
            style: TextButton.styleFrom(foregroundColor: _oscuro),
            child: const Text('Agregar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
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
