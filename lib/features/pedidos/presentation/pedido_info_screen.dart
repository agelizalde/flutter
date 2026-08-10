import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/pedidos_providers.dart';
import '../domain/pedido_models.dart';

/// Vista de solo lectura de un pedido — llega por `idPedido` (escaneo
/// contextual, ver `escaner/`) y pide los datos ella misma, mismo patrón
/// que `OcInfoScreen`: acá no hay ninguna acción, es solo para consultar
/// estado y subpedidos.
class PedidoInfoScreen extends ConsumerWidget {
  const PedidoInfoScreen({super.key, required this.idPedido});

  final int idPedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pedidoInfoProvider(idPedido));

    return Scaffold(
      appBar: AppBar(title: Text(async.value?.codigoPedido ?? 'Pedido')),
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

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.detalle});

  final PedidoDetalle detalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subpedidosAsync = ref.watch(pedidoSubpedidosProvider(detalle.idPedido));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _CabeceraCard(detalle: detalle),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'SUBPEDIDOS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.muted,
            ),
          ),
        ),
        subpedidosAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
          ),
          data: (subpedidos) => subpedidos.isEmpty
              ? const _Card(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Este pedido no tiene subpedidos', style: TextStyle(color: AppColors.muted)),
                    ),
                  ),
                )
              : Column(
                  children: subpedidos
                      .map(
                        (sp) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SubpedidoRow(subpedido: sp, codigoPedido: detalle.codigoPedido),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _CabeceraCard extends StatelessWidget {
  const _CabeceraCard({required this.detalle});

  final PedidoDetalle detalle;

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
                  detalle.clienteNombre,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              ),
              _EstadoBadge(estado: detalle.estado),
            ],
          ),
          const SizedBox(height: 10),
          _FilaDato(icono: Icons.confirmation_number_outlined, texto: detalle.codigoPedido),
          if (detalle.clienteSucursalNombre != null)
            _FilaDato(icono: Icons.store_outlined, texto: detalle.clienteSucursalNombre!),
          if (detalle.eta != null)
            _FilaDato(icono: Icons.event_outlined, texto: 'ETA: ${formatFecha(detalle.eta!)}'),
          if (detalle.vehiculoNombre != null)
            _FilaDato(icono: Icons.local_shipping_outlined, texto: detalle.vehiculoNombre!),
          if (detalle.observaciones != null && detalle.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(detalle.observaciones!, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
          ],
        ],
      ),
    );
  }
}

class _SubpedidoRow extends StatelessWidget {
  const _SubpedidoRow({required this.subpedido, required this.codigoPedido});

  final SubpedidoResumen subpedido;
  final String codigoPedido;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(
          '/pedidos/subpedido/${subpedido.idPedidoSubpedido}/items',
          extra: subpedido,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${subpedido.tipoNombre} ($codigoPedido)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: subpedido.estado),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
            ],
          ),
        ),
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
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13, color: AppColors.sub))),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(999)),
      child: Text(estado, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}
