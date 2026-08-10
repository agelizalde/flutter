import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/recepcion_oc_providers.dart';
import '../domain/orden_compra_models.dart';

String _fmtQty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Vista de solo lectura de una OC — llega por `idOc` y pide los datos
/// ella misma (`ocInfoDetalleProvider`, `GET /recepciones/oc/{id}/info`),
/// mismo patrón que `ProductoDetalleScreen`/`UbicacionProductosScreen`: no
/// depende del `extra` de go_router, que en Flutter Web no sobrevive de
/// forma confiable un rebuild de la ruta. A diferencia de
/// `RecibirOcItemsScreen`, acá no hay ninguna acción: es solo para
/// consultar qué dice la OC.
class OcInfoScreen extends ConsumerWidget {
  const OcInfoScreen({super.key, required this.idOc});

  final int idOc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ocInfoDetalleProvider(idOc));

    return Scaffold(
      appBar: AppBar(title: Text(async.value?.header.codigo ?? 'Orden de compra')),
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
        data: (detalle) => _Contenido(detalle: detalle),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.detalle});

  final OrdenCompraDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final header = detalle.header;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _CabeceraCard(header: header),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'ÍTEMS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.muted,
            ),
          ),
        ),
        if (detalle.items.isEmpty)
          const _Card(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Esta OC no tiene ítems', style: TextStyle(color: AppColors.muted)),
              ),
            ),
          )
        else
          ...detalle.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ItemRow(item: item),
            ),
          ),
      ],
    );
  }
}

class _CabeceraCard extends StatelessWidget {
  const _CabeceraCard({required this.header});

  final OrdenCompraHeader header;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  header.proveedorNombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              _EstadoBadge(estado: header.estado),
            ],
          ),
          const SizedBox(height: 10),
          _FilaDato(icono: Icons.confirmation_number_outlined, texto: header.codigo),
          if (header.almacenDestinoNombre != null)
            _FilaDato(
              icono: Icons.warehouse_outlined,
              texto: header.almacenDestinoNombre!,
            ),
          if (header.fechaEntrega != null)
            _FilaDato(
              icono: Icons.event_outlined,
              texto: 'Entrega estimada: ${formatFecha(header.fechaEntrega!)}',
            ),
          if (header.observaciones != null && header.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              header.observaciones!,
              style: const TextStyle(fontSize: 13, color: AppColors.sub),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
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

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrdenCompraItemDetalle item;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productoNombre,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
          ),
          const Divider(height: 18, color: AppColors.soft),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniCantidad(etiqueta: 'Solicitada', valor: item.cantidadSolicitada, unidad: item.unidadSimbolo),
              _MiniCantidad(etiqueta: 'Recibida', valor: item.cantidadRecibida, unidad: item.unidadSimbolo),
              _MiniCantidad(
                etiqueta: 'Pendiente',
                valor: item.cantidadPendiente,
                unidad: item.unidadSimbolo,
                destacar: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCantidad extends StatelessWidget {
  const _MiniCantidad({
    required this.etiqueta,
    required this.valor,
    required this.unidad,
    this.destacar = false,
  });

  final String etiqueta;
  final double valor;
  final String unidad;
  final bool destacar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        Text(
          '${_fmtQty(valor)} $unidad',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: destacar ? (valor > 0 ? AppColors.waTx : AppColors.okTx) : AppColors.text,
          ),
        ),
      ],
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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
      child: child,
    );
  }
}
