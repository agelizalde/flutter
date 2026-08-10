import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/traslados_providers.dart';
import '../domain/traslado_models.dart';

/// Solo lectura — esta app únicamente ejecuta traslados ya CONFIRMADOs
/// (`POST /traslados/ejecutar`), así que no hay acciones de
/// confirmar/anular que mostrar acá (esos verbos solo aplican al flujo
/// legacy borrador→confirmar que no se implementó, ver
/// `traslados_repository.dart`).
class TrasladoDetalleScreen extends ConsumerWidget {
  const TrasladoDetalleScreen({super.key, required this.idTraspaso});

  final int idTraspaso;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trasladoDetalleProvider(idTraspaso));

    return Scaffold(
      appBar: AppBar(title: const Text('Traslado')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (detalle) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(trasladoDetalleProvider(idTraspaso)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _HeaderCard(traslado: detalle.traslado),
                const SizedBox(height: 24),
                Text(
                  'ÍTEMS (${detalle.items.length})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                if (detalle.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Sin ítems', style: TextStyle(color: AppColors.muted))),
                  )
                else
                  ...detalle.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ItemTile(item: item),
                    ),
                  ),
                if (detalle.movimientos.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'MOVIMIENTOS DE STOCK (${detalle.movimientos.length})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  ...detalle.movimientos.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MovimientoTile(movimiento: m),
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
  const _HeaderCard({required this.traslado});

  final Traslado traslado;

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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.swap_horiz_outlined, color: AppColors.accentDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  traslado.codigo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: traslado.estado),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.warehouse_outlined, texto: traslado.almacenNombre),
          if (traslado.fechaTraspaso != null)
            _InfoRow(icon: Icons.event_outlined, texto: formatFecha(traslado.fechaTraspaso!)),
          if (traslado.usuarioCreacionUsername != null)
            _InfoRow(icon: Icons.person_outline, texto: 'Hizo el traslado: ${traslado.usuarioCreacionUsername}'),
          if (traslado.observaciones != null && traslado.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(traslado.observaciones!, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
          ],
          if (traslado.motivoAnulacion != null && traslado.motivoAnulacion!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo de anulación: ${traslado.motivoAnulacion}',
              style: const TextStyle(fontSize: 13, color: AppColors.erTx),
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
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13, color: AppColors.sub))),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final TrasladoItem item;

  @override
  Widget build(BuildContext context) {
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
              Expanded(
                child: Text(
                  item.productoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                ),
              ),
              Text(
                '${item.cantidad.toStringAsFixed(0)} ${item.unidadSimbolo}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.text),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lote ${item.loteInterno}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.ubicacionOrigenNombre} (${item.ubicacionOrigenCodigo})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.sub),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(Icons.arrow_forward, size: 14, color: AppColors.faint),
              ),
              Expanded(
                child: Text(
                  '${item.ubicacionDestinoNombre} (${item.ubicacionDestinoCodigo})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  const _MovimientoTile({required this.movimiento});

  final TrasladoMovimiento movimiento;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movimiento.productoNombre,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${movimiento.ubicacionOrigenNombre ?? '—'} → ${movimiento.ubicacionDestinoNombre ?? '—'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            movimiento.cantidad.toStringAsFixed(0),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
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
      'CONFIRMADO' => ('Confirmado', AppColors.okBg, AppColors.okTx),
      'ANULADO' => ('Anulado', AppColors.erBg, AppColors.erTx),
      _ => (estado, AppColors.soft, AppColors.sub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(etiqueta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
