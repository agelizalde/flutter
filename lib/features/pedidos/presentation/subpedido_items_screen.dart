import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/pedidos_providers.dart';
import '../domain/pedido_models.dart';

/// Ítems de un subpedido — se llega tocando una fila de subpedido en
/// `PedidoInfoScreen`, mismo alcance que la tabla de ítems de la web
/// (`ItemsTable.jsx` en `/ventas/pedidos/:id`): producto, cantidad y estado.
/// De solo lectura salvo la única acción de estado que soporta esta app:
/// confirmar un subpedido en BORRADOR (ver `_confirmar`) — el resto del menú
/// (por ahora solo "Descargar") sigue sin implementar.
class SubpedidoItemsScreen extends ConsumerStatefulWidget {
  const SubpedidoItemsScreen({
    super.key,
    required this.idPedidoSubpedido,
    this.idPedido,
    this.tipoNombre,
    this.estadoSubpedido,
    this.rowVersion,
  });

  final int idPedidoSubpedido;

  /// Pedido dueño de este subpedido — sin esto no se puede invalidar
  /// `pedidoSubpedidosProvider`/`pedidoInfoProvider` al confirmar, así que
  /// `PedidoInfoScreen` seguiría mostrando el subpedido en BORRADOR (con
  /// datos cacheados) al volver atrás hasta que algo más refresque esos
  /// providers.
  final int? idPedido;
  final String? tipoNombre;
  final String? estadoSubpedido;

  /// `row_version` del subpedido — `expected_version` para `POST .../confirmar`
  /// (control de concurrencia optimista). Llega desde el `SubpedidoResumen`
  /// que manda `PedidoInfoScreen` por `extra`; sin él no se puede confirmar.
  final int? rowVersion;

  @override
  ConsumerState<SubpedidoItemsScreen> createState() =>
      _SubpedidoItemsScreenState();
}

class _SubpedidoItemsScreenState extends ConsumerState<SubpedidoItemsScreen> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  // Estado local del subpedido — arranca con lo que llegó por navegación y
  // se actualiza en memoria al confirmar, para que el badge del appbar y el
  // botón de acción reflejen el cambio sin tener que volver a pedir el
  // pedido completo (esta pantalla no tiene un provider de cabecera propio).
  late String? _estado = widget.estadoSubpedido;
  bool _confirmando = false;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar subpedido'),
        content: const Text(
          'Se crean las reservas de stock de todos los ítems. Los que no '
          'tengan stock disponible quedan marcados para esperar reposición. '
          '¿Confirmar?',
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
    if (confirmar != true || widget.rowVersion == null) return;

    setState(() => _confirmando = true);
    try {
      final repo = ref.read(pedidosRepositoryProvider);
      final resultado = await repo.confirmarSubpedido(
        idPedidoSubpedido: widget.idPedidoSubpedido,
        expectedVersion: widget.rowVersion!,
      );

      // Regla de fulfillment simplificada para esta app: todo ítem que la
      // confirmación dejó sin stock (cantidad_pendiente > 0) se marca
      // "esperar" automáticamente, sin pedirle al usuario que elija entre
      // combinar/sustituir/compra externa/eliminar como hace la web.
      if (resultado.idsItemsSinStock.isNotEmpty) {
        await repo.aplicarDecisionEsperar(
          idPedidoSubpedido: widget.idPedidoSubpedido,
          idsItems: resultado.idsItemsSinStock,
        );
      }

      if (!mounted) return;
      setState(() => _estado = resultado.nuevoEstado);
      ref.invalidate(subpedidoItemsProvider(widget.idPedidoSubpedido));
      // `PedidoInfoScreen` sigue montado debajo (autoDispose no lo libera
      // mientras siga escuchando) con el `SubpedidoResumen` viejo cacheado
      // (BORRADOR) — sin invalidar acá, al volver atrás con la flecha se ve
      // el estado desactualizado hasta que algo más dispare un refresco.
      if (widget.idPedido != null) {
        ref.invalidate(pedidoSubpedidosProvider(widget.idPedido!));
        ref.invalidate(pedidoInfoProvider(widget.idPedido!));
      }

      final cantSinStock = resultado.idsItemsSinStock.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cantSinStock == 0
                ? 'Subpedido confirmado'
                : 'Subpedido confirmado — $cantSinStock ítem${cantSinStock != 1 ? 's' : ''} '
                      'en espera de stock',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(subpedidoItemsProvider(widget.idPedidoSubpedido));
    final usuario = ref.watch(authControllerProvider).value;
    final puedeConfirmar =
        (usuario?.tienePermiso('pedidos.editar') ?? false) &&
        _estado == 'BORRADOR' &&
        widget.rowVersion != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tipoNombre ?? 'Ítems del subpedido'),
        actions: [
          if (_estado != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: _EstadoBadge(estado: _estado!)),
            ),
          PopupMenuButton<String>(
            onSelected: (_) => ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Próximamente'))),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'descargar', child: Text('Descargar')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: puedeConfirmar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton.icon(
                  onPressed: _confirmando ? null : _confirmar,
                  icon: _confirmando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    _confirmando ? 'Confirmando...' : 'Confirmar subpedido',
                  ),
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: TextField(
              controller: _busquedaController,
              onChanged: (v) =>
                  setState(() => _busqueda = v.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: async.when(
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
              data: (items) {
                final filtrados = _busqueda.isEmpty
                    ? items
                    : items
                          .where(
                            (i) =>
                                i.productoNombre.toLowerCase().contains(
                                  _busqueda,
                                ) ||
                                (i.codigoInterno?.toLowerCase().contains(
                                      _busqueda,
                                    ) ??
                                    false),
                          )
                          .toList();

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Este subpedido no tiene ítems',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  );
                }
                if (filtrados.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ItemTile(item: filtrados[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});

  final SubpedidoItemResumen item;

  @override
  Widget build(BuildContext context) {
    final cantidadTexto = item.cantidad == item.cantidad.truncate()
        ? item.cantidad.truncate().toString()
        : item.cantidad.toStringAsFixed(2);
    final unidad = item.unidadSimbolo ?? item.unidadNombre;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.text,
                  ),
                ),
                if (item.codigoInterno != null &&
                    item.codigoInterno!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.codigoInterno!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
                if (item.observacion != null &&
                    item.observacion!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.observacion!,
                    style: const TextStyle(fontSize: 12, color: AppColors.sub),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                unidad != null ? '$cantidadTexto $unidad' : cantidadTexto,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              _EstadoBadge(estado: item.estado),
            ],
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
    final visual = _EstadoVisual.de(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: visual.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visual.etiqueta,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: visual.fg,
        ),
      ),
    );
  }
}

class _EstadoVisual {
  const _EstadoVisual(this.etiqueta, this.bg, this.fg);

  final String etiqueta;
  final Color bg;
  final Color fg;

  /// Mismo mapeo que `ESTADOS_ITEM`/`ESTADOS_SUBPEDIDO` en
  /// `pedidosApi.js` (web) — cubre además `CONTROL_PARCIAL`, que ahí falta
  /// y cae al fallback genérico.
  static _EstadoVisual de(String estado) {
    switch (estado) {
      case 'PENDIENTE':
        return const _EstadoVisual('Pendiente', AppColors.soft, AppColors.sub);
      case 'RESERVA_PARCIAL':
        return const _EstadoVisual(
          'Res. parcial',
          AppColors.waBg,
          AppColors.waTx,
        );
      case 'RESERVADO':
        return const _EstadoVisual('Reservado', AppColors.inBg, AppColors.inTx);
      case 'PICKING_PARCIAL':
        return const _EstadoVisual(
          'Pick. parcial',
          AppColors.waBg,
          AppColors.waTx,
        );
      case 'PICKEADO':
        return const _EstadoVisual('Pickeado', AppColors.okBg, AppColors.okTx);
      case 'CONTROL_PARCIAL':
        return const _EstadoVisual(
          'Ctrl. parcial',
          AppColors.waBg,
          AppColors.waTx,
        );
      case 'CONTROLADO':
        return const _EstadoVisual(
          'Controlado',
          AppColors.inBg,
          AppColors.inTx,
        );
      case 'EXPEDIDO':
        return const _EstadoVisual('Expedido', AppColors.inBg, AppColors.inTx);
      case 'ENTREGADO':
        return const _EstadoVisual('Entregado', AppColors.okBg, AppColors.okTx);
      // Estados de subpedido (badge del appbar) que no son de ítem.
      case 'CONFIRMADO':
        return const _EstadoVisual(
          'Confirmado',
          AppColors.inBg,
          AppColors.inTx,
        );
      case 'PICKING':
        return const _EstadoVisual(
          'En picking',
          AppColors.waBg,
          AppColors.waTx,
        );
      case 'CONTROL':
        return const _EstadoVisual('Control', AppColors.waBg, AppColors.waTx);
      case 'EN_CARGA':
        return const _EstadoVisual('En carga', AppColors.inBg, AppColors.inTx);
      case 'EN_ENTREGA':
        return const _EstadoVisual(
          'En entrega',
          AppColors.inBg,
          AppColors.inTx,
        );
      case 'ANULADO':
        return const _EstadoVisual('Anulado', AppColors.erBg, AppColors.erTx);
      default:
        return _EstadoVisual(estado, AppColors.soft, AppColors.sub);
    }
  }
}
