import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../picking_operario/domain/picking_models.dart';

/// Detalle de un contenedor escaneado desde el buscador (`/escaner`): a qué
/// subpedido está afectado (cliente/sucursal) y qué productos/cantidades
/// tiene pickeados adentro ahora mismo. Los datos ya vienen resueltos desde
/// `EscaneoContenedor` (un solo viaje al backend, ver
/// `picking_operario_service.py::get_contenedor_detalle_por_codigo`).
class ContenedorDetalleScreen extends StatelessWidget {
  const ContenedorDetalleScreen({super.key, required this.detalle});

  final ContenedorDetalle detalle;

  @override
  Widget build(BuildContext context) {
    final subpedido = detalle.subpedido;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: Text('Cajón ${detalle.identificador}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (subpedido != null) ...[
            const _SectionTitle('SUBPEDIDO ASIGNADO'),
            _SubpedidoCard(subpedido: subpedido),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Este cajón no está asignado a ningún subpedido en este momento.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle('PRODUCTOS (${detalle.items.length})'),
          if (detalle.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(14)),
              child: const Text('El cajón está vacío.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            )
          else
            ...detalle.items.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ItemTile(item: it),
                )),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
      ),
    );
  }
}

class _SubpedidoCard extends StatelessWidget {
  const _SubpedidoCard({required this.subpedido});

  final SubpedidoContenedor subpedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subpedido.tituloDisplay,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  subpedido.estado,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub),
                ),
              ),
            ],
          ),
          if (subpedido.codigoPedido != null) ...[
            const SizedBox(height: 4),
            Text(subpedido.codigoPedido!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final ItemContenedor item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                ),
                if (item.productoCodigo != null) ...[
                  const SizedBox(height: 2),
                  Text(item.productoCodigo!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.cantidad.toStringAsFixed(item.cantidad.truncateToDouble() == item.cantidad ? 0 : 2)} ${item.unidadSimbolo ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accentDark),
          ),
        ],
      ),
    );
  }
}
