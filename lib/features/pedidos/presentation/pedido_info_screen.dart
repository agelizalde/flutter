import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/pedidos_providers.dart';
import '../domain/pedido_models.dart';
import 'widgets/modificar_eta_sheet.dart';
import 'widgets/modificar_lugar_sheet.dart';
import 'widgets/nuevo_subpedido_sheet.dart';

/// Vista de un pedido — llega por `idPedido` (escaneo contextual, ver
/// `escaner/`) y pide los datos ella misma, mismo patrón que `OcInfoScreen`.
/// Es mayormente de solo lectura salvo por el menú de ajustes del AppBar
/// (ver `_AjustesMenuButton`): agregar un subpedido desde un "Pedido
/// Estándar" del cliente, modificar ETA/lugar de entrega, o anular el
/// pedido — la app de depósito no arma subpedidos desde cero, solo aplica
/// plantillas ya cargadas desde la web.
class PedidoInfoScreen extends ConsumerWidget {
  const PedidoInfoScreen({super.key, required this.idPedido});

  final int idPedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pedidoInfoProvider(idPedido));
    final detalle = async.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(detalle?.codigoPedido ?? 'Pedido'),
        actions: [if (detalle != null) _AjustesMenuButton(detalle: detalle)],
      ),
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

/// Botón "de ajustes" del AppBar — solo aparece si el usuario tiene algún
/// permiso que habilite al menos una de las 4 acciones. Cada opción además
/// se filtra por su propia condición (estado del pedido, o si el cliente
/// tiene algún estándar activo), así que puede terminar vacío igual: en ese
/// caso tampoco se muestra el botón.
class _AjustesMenuButton extends ConsumerWidget {
  const _AjustesMenuButton({required this.detalle});

  final PedidoDetalle detalle;

  Future<void> _nuevoEstandar(BuildContext context, WidgetRef ref) async {
    final repositorio = ref.read(pedidosRepositoryProvider);
    final resultado = await abrirNuevoSubpedidoSheet(
      context,
      repositorio,
      idPedido: detalle.idPedido,
      idCliente: detalle.idCliente,
    );
    if (resultado == null || !context.mounted) return;
    ref.invalidate(pedidoSubpedidosProvider(detalle.idPedido));
    // El pedido pudo haber estado en el grupo "Sin subpedidos" del Home de
    // Pedidos — ahora ya tiene, así que esas fuentes quedan desactualizadas
    // hasta que se refresquen.
    ref.invalidate(pedidosSinSubpedidosProvider);
    ref.invalidate(pedidosSeguimientoProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${resultado.totalSubpedidos} subpedido${resultado.totalSubpedidos != 1 ? 's' : ''} '
          'creado${resultado.totalSubpedidos != 1 ? 's' : ''} desde "${resultado.nombreEstandar}"',
        ),
      ),
    );
  }

  Future<void> _modEta(BuildContext context, WidgetRef ref) async {
    final repositorio = ref.read(pedidosRepositoryProvider);
    final guardado = await abrirModificarEtaSheet(context, repositorio, detalle);
    if (!guardado || !context.mounted) return;
    ref.invalidate(pedidoInfoProvider(detalle.idPedido));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('ETA actualizada')));
  }

  Future<void> _modLugar(BuildContext context, WidgetRef ref) async {
    final repositorio = ref.read(pedidosRepositoryProvider);
    final guardado = await abrirModificarLugarSheet(context, repositorio, detalle);
    if (!guardado || !context.mounted) return;
    ref.invalidate(pedidoInfoProvider(detalle.idPedido));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lugar de entrega actualizado')),
    );
  }

  Future<void> _anular(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular pedido'),
        content: const Text(
          'Se anulan todos los subpedidos activos y se liberan las reservas '
          'de stock asociadas. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      final resultado = await ref
          .read(pedidosRepositoryProvider)
          .anular(idPedido: detalle.idPedido, expectedVersion: detalle.rowVersion);
      if (!context.mounted) return;
      ref.invalidate(pedidoInfoProvider(detalle.idPedido));
      ref.invalidate(pedidoSubpedidosProvider(detalle.idPedido));
      ref.invalidate(pedidosSinSubpedidosProvider);
      ref.invalidate(pedidosSeguimientoProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pedido anulado (${resultado.subpedidosAnulados} subpedido${resultado.subpedidosAnulados != 1 ? 's' : ''})',
          ),
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
    final usuario = ref.watch(authControllerProvider).value;
    final editable = detalle.estado == 'BORRADOR' || detalle.estado == 'ACTIVO';
    final anulable = detalle.estado != 'ANULADO' && detalle.estado != 'FINALIZADO';

    final tieneCrear = usuario?.tienePermiso('pedidos.crear') ?? false;
    // Solo se pide la lista de estándares del cliente si el usuario podría
    // llegar a usarla — evita el GET de más para quien ni siquiera tiene
    // `pedidos.crear`.
    var tieneEstandarActivo = false;
    if (tieneCrear && editable) {
      final estandares = ref.watch(
        pedidoEstandaresActivosProvider(detalle.idCliente),
      );
      tieneEstandarActivo = estandares.value?.isNotEmpty ?? false;
    }

    final puedeNuevoEstandar = tieneCrear && editable && tieneEstandarActivo;
    final puedeEditar = usuario?.tienePermiso('pedidos.editar') ?? false;
    final puedeModEta = puedeEditar && editable;
    final puedeModLugar = puedeEditar && editable;
    final puedeAnular = puedeEditar && anulable;

    final items = <PopupMenuEntry<String>>[
      if (puedeNuevoEstandar)
        const PopupMenuItem(
          value: 'nuevo_estandar',
          child: _MenuItemRow(icono: Icons.star_outline, texto: 'Nuevo estándar'),
        ),
      if (puedeModEta)
        const PopupMenuItem(
          value: 'mod_eta',
          child: _MenuItemRow(icono: Icons.event_outlined, texto: 'Mod. ETA'),
        ),
      if (puedeModLugar)
        const PopupMenuItem(
          value: 'mod_lugar',
          child: _MenuItemRow(
            icono: Icons.place_outlined,
            texto: 'Mod. Lugar',
          ),
        ),
      if (puedeAnular) ...[
        if (puedeNuevoEstandar || puedeModEta || puedeModLugar)
          const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'anular',
          child: _MenuItemRow(
            icono: Icons.cancel_outlined,
            texto: 'Anular pedido',
            color: AppColors.erTx,
          ),
        ),
      ],
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      icon: const Icon(Icons.settings_outlined),
      itemBuilder: (context) => items,
      onSelected: (value) {
        switch (value) {
          case 'nuevo_estandar':
            _nuevoEstandar(context, ref);
          case 'mod_eta':
            _modEta(context, ref);
          case 'mod_lugar':
            _modLugar(context, ref);
          case 'anular':
            _anular(context, ref);
        }
      },
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  const _MenuItemRow({required this.icono, required this.texto, this.color});

  final IconData icono;
  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 18, color: color ?? AppColors.text),
        const SizedBox(width: 12),
        Text(texto, style: TextStyle(color: color ?? AppColors.text)),
      ],
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.detalle});

  final PedidoDetalle detalle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subpedidosAsync = ref.watch(
      pedidoSubpedidosProvider(detalle.idPedido),
    );

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
            child: Text(
              describeError(e),
              style: const TextStyle(color: AppColors.erTx),
            ),
          ),
          data: (subpedidos) => subpedidos.isEmpty
              ? const _Card(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Este pedido no tiene subpedidos',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                )
              : Column(
                  children: subpedidos
                      .map(
                        (sp) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _SubpedidoRow(
                            subpedido: sp,
                            codigoPedido: detalle.codigoPedido,
                          ),
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              _EstadoBadge(estado: detalle.estado),
            ],
          ),
          const SizedBox(height: 10),
          _FilaDato(
            icono: Icons.confirmation_number_outlined,
            texto: detalle.codigoPedido,
          ),
          if (detalle.clienteSucursalNombre != null)
            _FilaDato(
              icono: Icons.store_outlined,
              texto: detalle.clienteSucursalNombre!,
            ),
          if (detalle.eta != null)
            _FilaDato(
              icono: Icons.event_outlined,
              texto: 'ETA: ${formatFechaHora(detalle.eta!)}',
            ),
          if (detalle.vehiculoNombre != null)
            _FilaDato(
              icono: Icons.local_shipping_outlined,
              texto: detalle.vehiculoNombre!,
            ),
          if (detalle.observaciones != null &&
              detalle.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              detalle.observaciones!,
              style: const TextStyle(fontSize: 13, color: AppColors.sub),
            ),
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
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${subpedido.tipoNombre} ($codigoPedido)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.sub,
        ),
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
