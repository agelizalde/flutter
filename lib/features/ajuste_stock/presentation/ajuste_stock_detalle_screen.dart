import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';

class AjusteStockDetalleScreen extends ConsumerWidget {
  const AjusteStockDetalleScreen({super.key, required this.idAjusteStock});

  final int idAjusteStock;

  Future<void> _confirmar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar conteo'),
        content: const Text(
          'Esto cierra el conteo (ya no se puede editar) y queda listo para aplicar al stock real. ¿Confirmar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(ajusteStockRepositoryProvider).confirmar(idAjusteStock);
      ref.invalidate(ajusteStockDetalleProvider(idAjusteStock));
      ref.invalidate(ajustesStockListadoProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _aplicar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar ajuste'),
        content: const Text(
          'Esto va a sumar/restar stock real en base a las diferencias contadas. No se puede deshacer. ¿Aplicar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.erTx),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(ajusteStockRepositoryProvider).aplicar(idAjusteStock);
      ref.invalidate(ajusteStockDetalleProvider(idAjusteStock));
      ref.invalidate(ajustesStockListadoProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajuste aplicado, el stock ya está actualizado')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _anular(BuildContext context, WidgetRef ref, int rowVersion) async {
    final motivoController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular ajuste'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Esta acción no se puede deshacer.'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(hintText: 'Motivo (opcional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.erTx),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(ajusteStockRepositoryProvider).anular(
        idAjusteStock: idAjusteStock,
        expectedVersion: rowVersion,
        motivo: motivoController.text.trim().isEmpty ? null : motivoController.text.trim(),
      );
      ref.invalidate(ajusteStockDetalleProvider(idAjusteStock));
      ref.invalidate(ajustesStockListadoProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ajusteStockDetalleProvider(idAjusteStock));
    final usuario = ref.watch(authControllerProvider).value;
    final puedeConfirmar = usuario?.tienePermiso('ajuste_stock.confirmar') ?? false;
    final puedeAplicar = usuario?.tienePermiso('ajuste_stock.aplicar') ?? false;
    final puedeAnular = usuario?.tienePermiso('ajuste_stock.anular') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajuste de stock')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (detalle) {
          final ajuste = detalle.ajuste;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ajusteStockDetalleProvider(idAjusteStock)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _HeaderCard(ajuste: ajuste),
                const SizedBox(height: 16),
                _ResumenCard(ajuste: ajuste),
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
                if (ajuste.puedeConfirmar && puedeConfirmar) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _confirmar(context, ref),
                    icon: const Icon(Icons.lock_outline, size: 20),
                    label: const Text('Confirmar conteo'),
                  ),
                ],
                if (ajuste.puedeAplicar && puedeAplicar) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _aplicar(context, ref),
                    icon: const Icon(Icons.published_with_changes, size: 20),
                    label: const Text('Aplicar al stock'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.okTx),
                  ),
                ],
                if (ajuste.puedeAnular && puedeAnular) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _anular(context, ref, ajuste.rowVersion),
                    icon: const Icon(Icons.block, size: 20, color: AppColors.erTx),
                    label: const Text('Anular', style: TextStyle(color: AppColors.erTx)),
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
  const _HeaderCard({required this.ajuste});

  final AjusteStock ajuste;

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
                child: const Icon(Icons.fact_check_outlined, color: AppColors.accentDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ajuste.codigo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              ),
              const SizedBox(width: 8),
              _EstadoBadge(estado: ajuste.estado),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(icon: Icons.location_on_outlined, texto: '${ajuste.ubicacionNombre} (${ajuste.ubicacionCodigo}) · ${ajuste.almacenNombre}'),
          _InfoRow(icon: Icons.label_outline, texto: 'Motivo: ${labelMotivoAjuste(ajuste.motivoCategoria)}'),
          _InfoRow(
            icon: Icons.tune,
            texto: ajuste.modoAjuste == 'POR_LOTE' ? 'Conteo por lote' : 'Conteo por producto',
          ),
          if (ajuste.fechaConteo != null)
            _InfoRow(icon: Icons.event_outlined, texto: 'Conteo: ${formatFecha(ajuste.fechaConteo!)}'),
          if (ajuste.usuarioConteoUsername != null)
            _InfoRow(icon: Icons.person_outline, texto: 'Contó: ${ajuste.usuarioConteoUsername}'),
          if (ajuste.fechaAplicacion != null)
            _InfoRow(icon: Icons.published_with_changes, texto: 'Aplicado: ${formatFecha(ajuste.fechaAplicacion!)}'),
          if (ajuste.usuarioAplicacionUsername != null)
            _InfoRow(icon: Icons.person_outline, texto: 'Aplicó: ${ajuste.usuarioAplicacionUsername}'),
          if (ajuste.observaciones != null && ajuste.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(ajuste.observaciones!, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
          ],
          if (ajuste.motivoAnulacion != null && ajuste.motivoAnulacion!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo de anulación: ${ajuste.motivoAnulacion}',
              style: const TextStyle(fontSize: 13, color: AppColors.erTx),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResumenCard extends StatelessWidget {
  const _ResumenCard({required this.ajuste});

  final AjusteStock ajuste;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            etiqueta: 'Con diferencia',
            valor: '${ajuste.totalDiferencias}/${ajuste.totalItems}',
            color: ajuste.totalDiferencias > 0 ? AppColors.waTx : AppColors.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            etiqueta: 'Sobrante',
            valor: '+${ajuste.totalSobrante.toStringAsFixed(0)}',
            color: AppColors.okTx,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            etiqueta: 'Faltante',
            valor: '-${ajuste.totalFaltante.toStringAsFixed(0)}',
            color: AppColors.erTx,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.etiqueta, required this.valor, required this.color});

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
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

  final AjusteStockItem item;

  @override
  Widget build(BuildContext context) {
    final colorDiferencia = item.esSobrante
        ? AppColors.okTx
        : item.esFaltante
            ? AppColors.erTx
            : AppColors.muted;
    final signo = item.cantidadDiferencia > 0 ? '+' : '';

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
          Text(
            item.productoNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
          ),
          if (item.loteInterno != null) ...[
            const SizedBox(height: 2),
            Text('Lote ${item.loteInterno}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MiniCantidad(etiqueta: 'Sistema', valor: item.cantidadSistema, unidad: item.unidadSimbolo),
              _MiniCantidad(etiqueta: 'Contado', valor: item.cantidadContada, unidad: item.unidadSimbolo),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Diferencia', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text(
                    '$signo${item.cantidadDiferencia.toStringAsFixed(0)} ${item.unidadSimbolo}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colorDiferencia),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCantidad extends StatelessWidget {
  const _MiniCantidad({required this.etiqueta, required this.valor, required this.unidad});

  final String etiqueta;
  final double valor;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        Text(
          '${valor.toStringAsFixed(0)} $unidad',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
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
    final (etiqueta, bg, fg) = switch (estado) {
      'BORRADOR' => ('Borrador', AppColors.soft, AppColors.sub),
      'CONFIRMADO' => ('Confirmado', AppColors.inBg, AppColors.inTx),
      'APLICADO' => ('Aplicado', AppColors.okBg, AppColors.okTx),
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
