import '../../../core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/recepcion_providers.dart';
import '../domain/recepcion_models.dart';

class RecepcionDetalleScreen extends ConsumerWidget {
  const RecepcionDetalleScreen({super.key, required this.idRecepcion});

  final int idRecepcion;

  Future<void> _agregarItem(BuildContext context, WidgetRef ref) async {
    await context.push('/recepcion/$idRecepcion/items/nuevo');
    ref.invalidate(recepcionDetalleProvider(idRecepcion));
  }

  Future<void> _controlar(BuildContext context, WidgetRef ref) async {
    final resultado = await context.push<bool>('/recepcion/$idRecepcion/controlar');
    if (resultado == true) {
      ref.invalidate(recepcionDetalleProvider(idRecepcion));
    }
  }

  Future<void> _quitarItem(
    BuildContext context,
    WidgetRef ref,
    RecepcionItem item,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar ítem'),
        content: Text('¿Quitar "${item.productoNombre}" de la recepción?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref
          .read(recepcionRepositoryProvider)
          .quitarItem(
            idRecepcionItem: item.idRecepcionItem,
            expectedVersion: item.rowVersion,
          );
      ref.invalidate(recepcionDetalleProvider(idRecepcion));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _confirmar(
    BuildContext context,
    WidgetRef ref,
    Recepcion recepcion,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar recepción'),
        content: const Text(
          'Esto cierra la carga de ítems. Si el producto/proveedor no requiere control de calidad, '
          'el stock se ingresa automáticamente. ¿Confirmar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      final resultado = await ref
          .read(recepcionRepositoryProvider)
          .confirmar(
            idRecepcion: idRecepcion,
            expectedVersion: recepcion.rowVersion,
          );
      ref.invalidate(recepcionDetalleProvider(idRecepcion));
      ref.invalidate(recepcionesRecientesProvider);
      ref.invalidate(recepcionListadoProvider);
      if (!context.mounted) return;

      final esIngreso = resultado.accion == 'confirmada_e_ingresada';
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(esIngreso ? 'Ingresada a stock' : 'Pendiente de control'),
          content: Text(
            esIngreso
                ? 'Se generaron los lotes y el stock para ${resultado.ingreso?.countItems ?? 0} ítem(s).'
                : 'El proveedor/producto requiere control de calidad antes de ingresar a stock.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recepcionDetalleProvider(idRecepcion));
    final usuario = ref.watch(authControllerProvider).value;
    final puedeControlar = usuario?.tienePermiso('recepciones.controlar') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Recepción')),
      body: async.when(
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
          final esBorrador = detalle.recepcion.estado == 'BORRADOR';
          final esPendienteControl = detalle.recepcion.estado == 'PEND_CONTROL';
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(recepcionDetalleProvider(idRecepcion)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _HeaderCard(recepcion: detalle.recepcion),
                const SizedBox(height: 24),
                const Text(
                  'ÍTEMS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                if (detalle.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Todavía no hay ítems',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  )
                else
                  ...detalle.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ItemTile(
                        item: item,
                        onQuitar: esBorrador
                            ? () => _quitarItem(context, ref, item)
                            : null,
                      ),
                    ),
                  ),
                if (detalle.control != null) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'CONTROL DE CALIDAD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ControlCard(control: detalle.control!),
                ],
                if (esBorrador) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _agregarItem(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 18, color: AppColors.accentDark),
                            SizedBox(width: 6),
                            Text(
                              'Agregar ítem',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentDark),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: detalle.items.isEmpty
                        ? null
                        : () => _confirmar(context, ref, detalle.recepcion),
                    child: const Text('Confirmar recepción'),
                  ),
                ],
                if (esPendienteControl && puedeControlar) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _controlar(context, ref),
                    icon: const Icon(Icons.fact_check_outlined, size: 20),
                    label: const Text('Controlar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alertTx,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.recepcion});

  final Recepcion recepcion;

  @override
  Widget build(BuildContext context) {
    final esPendienteControl = recepcion.estado == 'PEND_CONTROL';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: esPendienteControl ? AppColors.alertBg : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  esPendienteControl ? Icons.warning_amber_rounded : Icons.move_to_inbox_outlined,
                  color: esPendienteControl ? AppColors.alertTx : AppColors.accentDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recepcion.proveedorNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: recepcion.estado),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.warehouse_outlined,
            texto: recepcion.almacenNombre,
          ),
          if (recepcion.ubicacionRecepcionNombre != null)
            _InfoRow(
              icon: Icons.location_on_outlined,
              texto: recepcion.ubicacionRecepcionNombre!,
            ),
          if (recepcion.fechaRecepcion != null)
            _InfoRow(
              icon: Icons.event_outlined,
              texto: formatFecha(recepcion.fechaRecepcion!),
            ),
          if (recepcion.requiereControl)
            _InfoRow(
              icon: Icons.person_outline,
              texto: 'Recepcionó: ${recepcion.receptorUsername ?? '—'}',
            ),
          if (recepcion.observacion != null &&
              recepcion.observacion!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              recepcion.observacion!,
              style: const TextStyle(fontSize: 13, color: AppColors.sub),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 13, color: AppColors.sub),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({required this.control});

  final ControlRecepcion control;

  @override
  Widget build(BuildContext context) {
    final pendiente = control.estado == 'PENDIENTE';
    final positivo = control.resultado == 'POSITIVO';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoRow(
                  icon: Icons.fact_check_outlined,
                  texto: 'Controló: ${control.usuarioControloUsername ?? '—'}',
                ),
              ),
              if (pendiente)
                _MiniBadge(texto: 'Pendiente', bg: AppColors.waBg, fg: AppColors.waTx)
              else if (control.resultado != null)
                _MiniBadge(
                  texto: control.resultado!,
                  bg: positivo ? AppColors.okBg : AppColors.erBg,
                  fg: positivo ? AppColors.okTx : AppColors.erTx,
                ),
            ],
          ),
          if (control.usuarioControladoUsername != null)
            _InfoRow(
              icon: Icons.person_outline,
              texto: 'Recepcionó: ${control.usuarioControladoUsername}',
            ),
          if (control.observacion != null && control.observacion!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              control.observacion!,
              style: const TextStyle(fontSize: 13, color: AppColors.sub),
            ),
          ],
          if (control.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.soft),
            const SizedBox(height: 8),
            ...control.items.map((item) => _ControlItemRow(item: item)),
          ],
        ],
      ),
    );
  }
}

class _ControlItemRow extends StatelessWidget {
  const _ControlItemRow({required this.item});

  final ControlRecepcionItem item;

  @override
  Widget build(BuildContext context) {
    final rechazada = item.cantidadRechazada > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              item.productoNombre,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
          Text(
            'Recibido ${item.cantidadRecibida.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (rechazada) ...[
            const SizedBox(width: 8),
            Text(
              'Rechazado ${item.cantidadRechazada.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.erTx),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.texto, required this.bg, required this.fg});

  final String texto;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onQuitar});

  final RecepcionItem item;
  final VoidCallback? onQuitar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.accentDark, size: 18),
          ),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${item.cantidad.toStringAsFixed(0)} ${item.unidadSimbolo}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    if (item.loteProveedor != null &&
                        item.loteProveedor!.isNotEmpty)
                      Text(
                        'Lote ${item.loteProveedor}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    if (item.fechaVencimiento != null)
                      Text(
                        'Vence ${formatFecha(item.fechaVencimiento!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    if (item.cantidadRechazada > 0)
                      Text(
                        'Rechazado ${item.cantidadRechazada.toStringAsFixed(0)} ${item.unidadSimbolo}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.erTx,
                        ),
                      ),
                  ],
                ),
                if (item.cantidadRechazada > 0 &&
                    item.observacionRechazo != null &&
                    item.observacionRechazo!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.observacionRechazo!,
                    style: const TextStyle(fontSize: 12, color: AppColors.erTx),
                  ),
                ],
              ],
            ),
          ),
          if (onQuitar != null)
            IconButton(
              onPressed: onQuitar,
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.erTx,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (etiqueta, bg, fg) = switch (estado) {
      'BORRADOR' => ('Borrador', AppColors.soft, AppColors.sub),
      'CONFIRMADA' => ('Confirmada', AppColors.inBg, AppColors.inTx),
      'PEND_CONTROL' => ('Pend. control', AppColors.waBg, AppColors.waTx),
      'CONTROLADA' => ('Controlada', AppColors.inBg, AppColors.inTx),
      'INGRESADA' => ('Ingresada', AppColors.okBg, AppColors.okTx),
      'ANULADA' => ('Anulada', AppColors.erBg, AppColors.erTx),
      _ => (estado, AppColors.soft, AppColors.sub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
