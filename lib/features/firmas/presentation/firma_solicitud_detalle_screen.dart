import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../entrega/application/entrega_providers.dart';
import '../application/firmas_providers.dart';
import '../domain/firma_solicitud.dart';
import '../domain/oc_detalle.dart';
import '../domain/oc_diferencia_peso_detalle.dart';
import '../domain/oc_exceso_cantidad_detalle.dart';
import '../domain/op_detalle.dart';

/// Detalle de una solicitud de firma (monto/regla/motivo, más aprobar/
/// rechazar si está PENDIENTE) — equivalente mobile de `SolicitudDetail.jsx`
/// en la web. A diferencia de la web, esta pantalla no tiene una vista
/// propia por cada tipo de documento (la hoja A4 de la OC, por ejemplo, es
/// web-only) salvo para `PEDIDO_ENTREGA` (ver [_EntregaPedidoCard]), `OC`
/// (ver [_OrdenCompraCard]), `OC_DIFERENCIA_PESO` (ver [_DiferenciaPesoCard])
/// y `OC_EXCESO_CANTIDAD` (ver [_ExcesoCantidadCard]), que sí se resuelven
/// seguido desde la app de depósito.
class FirmaSolicitudDetalleScreen extends ConsumerWidget {
  const FirmaSolicitudDetalleScreen({super.key, required this.idFirmaSolicitud});

  final int idFirmaSolicitud;

  Future<void> _aprobar(
    BuildContext context,
    WidgetRef ref,
    FirmaSolicitud solicitud, {
    String label = 'Aprobar',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text('¿Confirmás "$label" para "${solicitud.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(label)),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(firmasRepositoryProvider)
          .aprobar(idFirmaSolicitud: solicitud.idFirmaSolicitud, expectedVersion: solicitud.rowVersion);
      ref.invalidate(firmaSolicitudDetalleProvider(solicitud.idFirmaSolicitud));
      ref.invalidate(firmasPendientesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma aprobada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _rechazar(BuildContext context, WidgetRef ref, FirmaSolicitud solicitud) async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RechazarFirmaSheet(),
    );
    if (motivo == null) return;

    try {
      await ref
          .read(firmasRepositoryProvider)
          .rechazar(idFirmaSolicitud: solicitud.idFirmaSolicitud, expectedVersion: solicitud.rowVersion, motivo: motivo);
      ref.invalidate(firmaSolicitudDetalleProvider(solicitud.idFirmaSolicitud));
      ref.invalidate(firmasPendientesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(firmaSolicitudDetalleProvider(idFirmaSolicitud));

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de firma')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (solicitud) {
          final esEntregaPedido = solicitud.esPedidoEntrega;
          final esOrdenCompra = solicitud.esOrdenCompra;
          final esOrdenPago = solicitud.esOrdenPago;
          final esDiferenciaPeso = solicitud.esDiferenciaPeso;
          final esExcesoCantidad = solicitud.esExcesoCantidad;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(firmaSolicitudDetalleProvider(idFirmaSolicitud));
              if (esEntregaPedido) ref.invalidate(pedidoEntregaResumenProvider(solicitud.idDocumento));
              if (esOrdenCompra) ref.invalidate(ocDetalleProvider(solicitud.idDocumento));
              if (esOrdenPago) ref.invalidate(opDetalleProvider(solicitud.idDocumento));
              if (esDiferenciaPeso) ref.invalidate(ocDiferenciaPesoProvider(solicitud.idDocumento));
              if (esExcesoCantidad) ref.invalidate(ocExcesoCantidadProvider(solicitud.idDocumento));
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (esOrdenCompra)
                  _OrdenCompraHeaderCard(solicitud: solicitud)
                else if (esOrdenPago)
                  _OrdenPagoHeaderCard(solicitud: solicitud)
                else if (esDiferenciaPeso)
                  _DiferenciaPesoHeaderCard(solicitud: solicitud)
                else if (esExcesoCantidad)
                  _ExcesoCantidadHeaderCard(solicitud: solicitud)
                else
                  _HeaderCard(solicitud: solicitud),
                const SizedBox(height: 16),
                if (esEntregaPedido)
                  _EntregaPedidoCard(solicitud: solicitud)
                else if (esOrdenCompra)
                  _OrdenCompraCard(solicitud: solicitud)
                else if (esOrdenPago)
                  _OrdenPagoCard(solicitud: solicitud)
                else if (esDiferenciaPeso)
                  _DiferenciaPesoCard(solicitud: solicitud)
                else if (esExcesoCantidad)
                  _ExcesoCantidadCard(solicitud: solicitud)
                else
                  _DatosCard(solicitud: solicitud),
                if (solicitud.pendiente) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _aprobar(
                      context,
                      ref,
                      solicitud,
                      label: esEntregaPedido ? 'Entregado bien' : 'Aprobar',
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(esEntregaPedido ? 'Entregado bien' : 'Aprobar'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.okTx),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _rechazar(context, ref, solicitud),
                    icon: const Icon(Icons.block, size: 20, color: AppColors.erTx),
                    label: Text(
                      esEntregaPedido ? 'Entregado con errores' : 'Rechazar',
                      style: const TextStyle(color: AppColors.erTx),
                    ),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.erTx)),
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
  const _HeaderCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  solicitud.titulo,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'Solicitud #${solicitud.idFirmaSolicitud}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EstadoBadge(estado: solicitud.estado),
        ],
      ),
    );
  }
}

class _DatosCard extends StatelessWidget {
  const _DatosCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Dato(etiqueta: 'Monto', valor: formatGs(solicitud.monto)),
          const Divider(height: 20, color: AppColors.border),
          _Dato(
            etiqueta: 'Regla aplicada',
            valor: solicitud.reglaNombre ??
                (solicitud.documentoTipoPermisoFallback != null
                    ? 'Ninguna — requiere el permiso "${solicitud.documentoTipoPermisoFallback}"'
                    : '— (no requería firma)'),
          ),
          const Divider(height: 20, color: AppColors.border),
          _Dato(etiqueta: 'Solicitado por', valor: solicitud.solicitanteUsername ?? '—'),
          const Divider(height: 20, color: AppColors.border),
          _Dato(etiqueta: 'Fecha de solicitud', valor: formatFechaHora(solicitud.fechaSolicitud)),
          if (solicitud.idUsuarioResolutor != null) ...[
            const Divider(height: 20, color: AppColors.border),
            _Dato(etiqueta: 'Resuelto por', valor: solicitud.resolutorUsername ?? '—'),
            if (solicitud.fechaResolucion != null) ...[
              const Divider(height: 20, color: AppColors.border),
              _Dato(etiqueta: 'Fecha de resolución', valor: formatFechaHora(solicitud.fechaResolucion!)),
            ],
          ],
          if (solicitud.motivo != null && solicitud.motivo!.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.border),
            _Dato(etiqueta: 'Motivo', valor: solicitud.motivo!),
          ],
        ],
      ),
    );
  }
}

/// Datos de la entrega para una solicitud `PEDIDO_ENTREGA` (ver
/// `firmas_config_default.py`) — pide `PedidoEntregaResumen` aparte porque
/// `/firmas/solicitudes/{id}` es intencionalmente genérico (ver
/// `firmas_solicitudes.py::_base_select`) y no trae nada de la entrega en
/// sí; `solicitud.idDocumento` es el `id_pedido_subpedido` que se está
/// resolviendo.
class _EntregaPedidoCard extends ConsumerWidget {
  const _EntregaPedidoCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pedidoEntregaResumenProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (resumen) {
          final sub = resumen.subpedido;
          final observacion = sub.observacion?.trim();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Dato(etiqueta: 'Cliente - sucursal', valor: resumen.clienteSucursalDisplay),
              const Divider(height: 20, color: AppColors.border),
              _Dato(etiqueta: 'Tipo de subpedido', valor: sub.tipoNombre ?? '—'),
              const Divider(height: 20, color: AppColors.border),
              _Dato(
                etiqueta: 'ETA de la entrega',
                valor: sub.entregoFecha != null ? formatFechaHora(sub.entregoFecha!) : 'Aún no entregado',
              ),
              const Divider(height: 20, color: AppColors.border),
              _Dato(etiqueta: 'Quién entregó', valor: sub.entregoNombre ?? '—'),
              const Divider(height: 20, color: AppColors.border),
              _Dato(
                etiqueta: 'Rechazos o devoluciones',
                valor: sub.tieneRechazosDevoluciones ? 'Sí hubo' : 'No hubo',
              ),
              const Divider(height: 20, color: AppColors.border),
              _Dato(
                etiqueta: 'Observación de la entrega',
                valor: (observacion == null || observacion.isEmpty) ? 'Sin observaciones' : observacion,
              ),
              if (solicitud.idUsuarioResolutor != null) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Resuelto por', valor: solicitud.resolutorUsername ?? '—'),
                if (solicitud.fechaResolucion != null) ...[
                  const Divider(height: 20, color: AppColors.border),
                  _Dato(etiqueta: 'Fecha de resolución', valor: formatFechaHora(solicitud.fechaResolucion!)),
                ],
              ],
              if (solicitud.motivo != null && solicitud.motivo!.isNotEmpty) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Motivo', valor: solicitud.motivo!),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Header de una solicitud `OC`: "OC - {proveedor}" + "{código} -
/// {solicitante} - {fecha}" (pedido explícito del usuario, distinto del
/// header genérico de [_HeaderCard]) — el badge de estado sigue siendo el
/// de la solicitud de firma, no el de la OC en sí.
class _OrdenCompraHeaderCard extends ConsumerWidget {
  const _OrdenCompraHeaderCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocDetalleProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final header = detalle.header;
          final codigo = header.codigo ?? 'OC #${header.idOc}';
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OC - ${header.proveedorNombre}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$codigo - ${header.solicitanteDisplay} - ${formatFecha(header.fechaEmision)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: solicitud.estado),
            ],
          );
        },
      ),
    );
  }
}

/// Header de una solicitud `OP`: "Orden de Pago" / "{proveedor} -
/// {crédito/contado/anticipo, en rojo}" / "{código} - {solicitante} -
/// {fecha}" (pedido explícito del usuario, mismo patrón que
/// [_OrdenCompraHeaderCard]) — "Solicitante" toma el de la solicitud de
/// firma (quién la envió a firma), no un campo propio de la OP.
class _OrdenPagoHeaderCard extends ConsumerWidget {
  const _OrdenPagoHeaderCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(opDetalleProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final header = detalle.header;
          final codigo = header.codigo ?? 'OP #${header.idOrdenPago}';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ORDEN DE PAGO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            header.proveedorNombre,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '- ${header.formaPagoDisplay}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.erTx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$codigo - ${solicitud.solicitanteUsername ?? '—'} - ${formatFecha(header.fechaEmision)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: solicitud.estado),
            ],
          );
        },
      ),
    );
  }
}

/// Cuerpo de una solicitud `OP`: un renglón por producto (de los ítems de OC
/// tocados por las facturas aplicadas a esta OP) con cantidad recibida y
/// precio unitario, tocable para ver el histórico de precios (mismo popup
/// que [_OrdenCompraCard]). Footer con el total a pagar (`monto_total` de la
/// OP, no la suma de líneas — puede diferir por notas de crédito aplicadas).
class _OrdenPagoCard extends ConsumerWidget {
  const _OrdenPagoCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  void _mostrarUltimosPrecios(BuildContext context, OpDetalleItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.productoNombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(ocUltimasComprasProvider(item.idProducto));
              return async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
                ),
                data: (compras) {
                  if (compras.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Sin compras previas registradas.', style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < compras.length; i++) ...[
                        _FilaUltimaCompra(compra: compras[i]),
                        if (i != compras.length - 1) const Divider(height: 20, color: AppColors.border),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(opDetalleProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final header = detalle.header;
          final simbolo = header.monedaSimbolo;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRODUCTOS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              if (detalle.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Sin productos asociados.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                )
              else
                for (var i = 0; i < detalle.items.length; i++) ...[
                  _OpItemTile(
                    item: detalle.items[i],
                    monedaSimbolo: simbolo,
                    onTap: () => _mostrarUltimosPrecios(context, detalle.items[i]),
                  ),
                  if (i != detalle.items.length - 1) const Divider(height: 20, color: AppColors.border),
                ],
              const Divider(height: 28, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total a pagar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                  Text(
                    _formatMonto(header.montoTotal, simbolo),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.text),
                  ),
                ],
              ),
              if (solicitud.idUsuarioResolutor != null) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Resuelto por', valor: solicitud.resolutorUsername ?? '—'),
                if (solicitud.fechaResolucion != null) ...[
                  const Divider(height: 20, color: AppColors.border),
                  _Dato(etiqueta: 'Fecha de resolución', valor: formatFechaHora(solicitud.fechaResolucion!)),
                ],
              ],
              if (solicitud.motivo != null && solicitud.motivo!.isNotEmpty) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Motivo', valor: solicitud.motivo!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OpItemTile extends StatelessWidget {
  const _OpItemTile({required this.item, required this.monedaSimbolo, required this.onTap});

  final OpDetalleItem item;
  final String monedaSimbolo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productoNombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCantidad(item.cantidadRecibida)} ${item.unidadSimbolo}  ×  ${_formatMonto(item.precioUnitario, monedaSimbolo)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatMonto(item.totalLinea, monedaSimbolo),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

/// Header de una solicitud `OC_DIFERENCIA_PESO`: "DIFERENCIA DE PESO EN
/// RECEPCIÓN" / "OC - {proveedor} - {receptor}" / "{código} - {solicitante}
/// - {fecha}" (mismo pedido explícito del usuario que [_OrdenCompraHeaderCard],
/// adaptado a este tipo). El conteo de bultos ya coincidía con lo pedido —
/// quien carga la recepción es la misma persona que figura como
/// "solicitante" de la firma, así que "Receptor" y "Solicitante" muestran el
/// mismo usuario (no hay dos roles distintos en los datos).
class _DiferenciaPesoHeaderCard extends ConsumerWidget {
  const _DiferenciaPesoHeaderCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocDiferenciaPesoProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final header = detalle.header;
          final receptor = header.solicitanteUsername ?? '—';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIFERENCIA DE PESO EN RECEPCIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OC - ${header.proveedorNombre} - $receptor',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${header.ocCodigoDisplay} - ${header.solicitanteUsername ?? '—'} - ${formatFechaHora(header.solicitadoEn)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: solicitud.estado),
            ],
          );
        },
      ),
    );
  }
}

/// Cuerpo de una solicitud `OC_DIFERENCIA_PESO`: un renglón por producto con
/// cantidad pedida (peso teórico) vs. a recibir (peso real, resaltado en
/// rojo porque es el valor que hay que autorizar), tocable para ver cuánto
/// se pidió en la OC / a qué precio / cuál era el total de ese producto.
/// Footer con el total de la OC tachado (antes de esta corrección) y el
/// total nuevo (ver cálculo en `obtener_diferencia_peso`,
/// `recepcion_diferencia_peso_service.py` — no modifica la OC en sí, es solo
/// lo que quedaría si se autoriza el peso cargado).
class _DiferenciaPesoCard extends ConsumerWidget {
  const _DiferenciaPesoCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  void _mostrarDetalleProducto(BuildContext context, OcDiferenciaPesoItem item, String monedaSimbolo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.productoNombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Dato(
              etiqueta: 'Cantidad pedida en la OC',
              valor: item.ocCantidadSolicitada != null
                  ? '${_formatCantidad(item.ocCantidadSolicitada!)} ${item.unidadNombre}'
                  : '—',
            ),
            const Divider(height: 20, color: AppColors.border),
            _Dato(
              etiqueta: 'Precio unitario',
              valor: item.ocPrecioUnitario != null ? _formatMonto(item.ocPrecioUnitario!, monedaSimbolo) : '—',
            ),
            const Divider(height: 20, color: AppColors.border),
            _Dato(
              etiqueta: 'Total de ese producto',
              valor: item.totalLineaTeorico != null ? _formatMonto(item.totalLineaTeorico!, monedaSimbolo) : '—',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocDiferenciaPesoProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final header = detalle.header;
          final simbolo = header.monedaSimbolo;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRODUCTOS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < detalle.items.length; i++) ...[
                _DiferenciaPesoItemTile(
                  item: detalle.items[i],
                  unidadNombre: detalle.items[i].unidadNombre,
                  onTap: () => _mostrarDetalleProducto(context, detalle.items[i], simbolo),
                ),
                if (i != detalle.items.length - 1) const Divider(height: 20, color: AppColors.border),
              ],
              const Divider(height: 28, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
                  Row(
                    children: [
                      Text(
                        _formatMonto(header.totalAnterior, simbolo),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatMonto(header.totalNuevo, simbolo),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.text),
                      ),
                    ],
                  ),
                ],
              ),
              if (solicitud.idUsuarioResolutor != null) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Resuelto por', valor: solicitud.resolutorUsername ?? '—'),
                if (solicitud.fechaResolucion != null) ...[
                  const Divider(height: 20, color: AppColors.border),
                  _Dato(etiqueta: 'Fecha de resolución', valor: formatFechaHora(solicitud.fechaResolucion!)),
                ],
              ],
              if (solicitud.motivo != null && solicitud.motivo!.isNotEmpty) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Motivo', valor: solicitud.motivo!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DiferenciaPesoItemTile extends StatelessWidget {
  const _DiferenciaPesoItemTile({required this.item, required this.unidadNombre, required this.onTap});

  final OcDiferenciaPesoItem item;
  final String unidadNombre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productoNombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Pedido: ${_formatCantidad(item.cantidadTeoricaBase)} $unidadNombre',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'A recibir: ${_formatCantidad(item.cantidadRealBase)} $unidadNombre',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.erTx),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

/// Header de una solicitud `OC_EXCESO_CANTIDAD`: "DIFERENCIA DE CANTIDAD EN
/// RECEPCIÓN" / "OC - {proveedor} - {receptor}" / "{código} - {solicitante}
/// - {fecha}" — mismo patrón explícito que [_DiferenciaPesoHeaderCard], ver
/// comentario ahí sobre "Receptor"/"Solicitante" siendo el mismo usuario.
class _ExcesoCantidadHeaderCard extends ConsumerWidget {
  const _ExcesoCantidadHeaderCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocExcesoCantidadProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final header = detalle.header;
          final receptor = header.solicitanteUsername ?? '—';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIFERENCIA DE CANTIDAD EN RECEPCIÓN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OC - ${header.proveedorNombre} - $receptor',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${header.ocCodigoDisplay} - ${header.solicitanteUsername ?? '—'} - ${formatFechaHora(header.solicitadoEn)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: solicitud.estado),
            ],
          );
        },
      ),
    );
  }
}

/// Cuerpo de una solicitud `OC_EXCESO_CANTIDAD`: un renglón por producto con
/// cantidad pedida (saldo pendiente de la OC) vs. a recibir (lo que se está
/// cargando ahora, resaltado en rojo porque es el valor que hay que
/// autorizar), tocable para ver cuánto se pidió en la OC / a qué precio /
/// cuál era el total de ese producto. Footer con el total de la OC tachado
/// (antes de esta corrección) y el total nuevo (ver cálculo en
/// `obtener_exceso`, `recepcion_oc_actualizacion_service.py` — a diferencia
/// de la diferencia de peso, acá aprobar SÍ actualiza `cantidad_solicitada`
/// del ítem de OC).
class _ExcesoCantidadCard extends ConsumerWidget {
  const _ExcesoCantidadCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  void _mostrarDetalleProducto(BuildContext context, OcExcesoCantidadItem item, String monedaSimbolo) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.productoNombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Dato(
              etiqueta: 'Cantidad pedida en la OC',
              valor: '${_formatCantidad(item.cantidadOcOriginal)} ${item.unidadNombre}',
            ),
            const Divider(height: 20, color: AppColors.border),
            _Dato(
              etiqueta: 'Precio unitario',
              valor: item.ocPrecioUnitario != null ? _formatMonto(item.ocPrecioUnitario!, monedaSimbolo) : '—',
            ),
            const Divider(height: 20, color: AppColors.border),
            _Dato(
              etiqueta: 'Total de ese producto',
              valor: item.totalLineaOriginal != null ? _formatMonto(item.totalLineaOriginal!, monedaSimbolo) : '—',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocExcesoCantidadProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final header = detalle.header;
          final simbolo = header.monedaSimbolo;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRODUCTOS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < detalle.items.length; i++) ...[
                _ExcesoCantidadItemTile(
                  item: detalle.items[i],
                  onTap: () => _mostrarDetalleProducto(context, detalle.items[i], simbolo),
                ),
                if (i != detalle.items.length - 1) const Divider(height: 20, color: AppColors.border),
              ],
              const Divider(height: 28, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
                  Row(
                    children: [
                      Text(
                        _formatMonto(header.totalAnterior, simbolo),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatMonto(header.totalNuevo, simbolo),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.text),
                      ),
                    ],
                  ),
                ],
              ),
              if (solicitud.idUsuarioResolutor != null) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Resuelto por', valor: solicitud.resolutorUsername ?? '—'),
                if (solicitud.fechaResolucion != null) ...[
                  const Divider(height: 20, color: AppColors.border),
                  _Dato(etiqueta: 'Fecha de resolución', valor: formatFechaHora(solicitud.fechaResolucion!)),
                ],
              ],
              if (solicitud.motivo != null && solicitud.motivo!.isNotEmpty) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Motivo', valor: solicitud.motivo!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ExcesoCantidadItemTile extends StatelessWidget {
  const _ExcesoCantidadItemTile({required this.item, required this.onTap});

  final OcExcesoCantidadItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productoNombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Pedido: ${_formatCantidad(item.saldoPendiente)} ${item.unidadNombre}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'A recibir: ${_formatCantidad(item.cantidadRecibidaActual)} ${item.unidadNombre}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.erTx),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

/// Cuerpo de una solicitud `OC`: ítems (producto/cantidad/precio unitario/
/// total, tocable para ver el histórico de precios) + total al pie. Pide el
/// mismo [ocDetalleProvider] que [_OrdenCompraHeaderCard] (Riverpod
/// deduplica la llamada, misma family key).
class _OrdenCompraCard extends ConsumerWidget {
  const _OrdenCompraCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  void _mostrarUltimosPrecios(BuildContext context, OcDetalleItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.productoNombre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer(
            builder: (context, ref, _) {
              final async = ref.watch(ocUltimasComprasProvider(item.idProducto));
              return async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
                ),
                data: (compras) {
                  if (compras.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Sin compras previas registradas.', style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < compras.length; i++) ...[
                        _FilaUltimaCompra(compra: compras[i]),
                        if (i != compras.length - 1) const Divider(height: 20, color: AppColors.border),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocDetalleProvider(solicitud.idDocumento));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
        data: (detalle) {
          final simbolo = detalle.header.monedaSimbolo;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ÍTEMS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < detalle.items.length; i++) ...[
                _OcItemTile(
                  item: detalle.items[i],
                  monedaSimbolo: simbolo,
                  onTap: () => _mostrarUltimosPrecios(context, detalle.items[i]),
                ),
                if (i != detalle.items.length - 1) const Divider(height: 20, color: AppColors.border),
              ],
              const Divider(height: 28, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
                  Text(
                    _formatMonto(detalle.header.totalNetoImporte, simbolo),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.text),
                  ),
                ],
              ),
              if (solicitud.idUsuarioResolutor != null) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Resuelto por', valor: solicitud.resolutorUsername ?? '—'),
                if (solicitud.fechaResolucion != null) ...[
                  const Divider(height: 20, color: AppColors.border),
                  _Dato(etiqueta: 'Fecha de resolución', valor: formatFechaHora(solicitud.fechaResolucion!)),
                ],
              ],
              if (solicitud.motivo != null && solicitud.motivo!.isNotEmpty) ...[
                const Divider(height: 20, color: AppColors.border),
                _Dato(etiqueta: 'Motivo', valor: solicitud.motivo!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OcItemTile extends StatelessWidget {
  const _OcItemTile({required this.item, required this.monedaSimbolo, required this.onTap});

  final OcDetalleItem item;
  final String monedaSimbolo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productoNombre,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatCantidad(item.cantidadSolicitada)} ${item.unidadSimbolo}  ×  ${_formatMonto(item.precioUnitario, monedaSimbolo)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatMonto(item.totalLinea, monedaSimbolo),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

class _FilaUltimaCompra extends StatelessWidget {
  const _FilaUltimaCompra({required this.compra});

  final OcUltimaCompra compra;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatFecha(compra.fechaEmision),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(height: 2),
              Text(compra.proveedorNombre, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        Text(
          _formatMonto(compra.precioUnitario, compra.monedaSimbolo),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
      ],
    );
  }
}

/// Formato genérico "{símbolo} 150.000" / "{símbolo} 150.000,50" — igual a
/// `formatGs` de `core/utils/parsing.dart` pero con símbolo de moneda
/// dinámico (`moneda_simbolo` de la OC), que puede no ser guaraníes.
String _formatMonto(double valor, String simbolo) {
  final negativo = valor < 0;
  final absoluto = valor.abs();
  final parteEntera = absoluto.truncate();
  final enteroStr = parteEntera.toString();

  final buffer = StringBuffer();
  for (var i = 0; i < enteroStr.length; i++) {
    if (i > 0 && (enteroStr.length - i) % 3 == 0) buffer.write('.');
    buffer.write(enteroStr[i]);
  }

  final signo = negativo ? '-' : '';
  final esEntero = absoluto == parteEntera.toDouble();
  if (esEntero) return '$simbolo $signo${buffer.toString()}';

  final decimales = ((absoluto - parteEntera) * 100).round().toString().padLeft(2, '0');
  return '$simbolo $signo${buffer.toString()},$decimales';
}

String _formatCantidad(double valor) {
  final redondeado = double.parse(valor.toStringAsFixed(3));
  return redondeado == redondeado.roundToDouble() ? redondeado.toStringAsFixed(0) : redondeado.toString();
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
      ],
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (etiqueta, bg, fg) = switch (estado) {
      'PENDIENTE' => ('Pendiente', AppColors.waBg, AppColors.waTx),
      'APROBADO' => ('Aprobado', AppColors.okBg, AppColors.okTx),
      'RECHAZADO' => ('Rechazado', AppColors.erBg, AppColors.erTx),
      'ANULADA' => ('Anulada', AppColors.soft, AppColors.sub),
      'NO_REQUERIDA' => ('No requerida', AppColors.soft, AppColors.sub),
      _ => (estado, AppColors.soft, AppColors.sub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(etiqueta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _RechazarFirmaSheet extends StatefulWidget {
  const _RechazarFirmaSheet();

  @override
  State<_RechazarFirmaSheet> createState() => _RechazarFirmaSheetState();
}

class _RechazarFirmaSheetState extends State<_RechazarFirmaSheet> {
  final _motivoController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _motivoController.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'El motivo es obligatorio para rechazar');
      return;
    }
    Navigator.of(context).pop(motivo);
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Rechazar solicitud',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              const Text('El motivo es obligatorio.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 16),
              TextField(
                controller: _motivoController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Motivo del rechazo'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.erTx),
                child: const Text('Confirmar rechazo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
