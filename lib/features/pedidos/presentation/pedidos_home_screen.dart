import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/pedidos_providers.dart';
import '../domain/pedido_models.dart';

/// Entrada al módulo "Pedidos" (`/pedidos`, tab del bottom nav): lista los
/// subpedidos que el usuario puede seguir, según su permiso —
/// `pedidos.ver` alcanza hasta el momento en que el subpedido se entrega;
/// quien además tiene `pedidos_subpedidos.aprobar_entrega` lo sigue viendo
/// en `ENTREGADO` hasta que la firma de entrega se resuelve. El conjunto de
/// estados lo decide el backend (`GET /pedidos/subpedidos/ver`), acá solo
/// se muestra lo que llega, agrupado por pedido, con un buscador libre (sin
/// filtro de estado: se necesitan todos los subpedidos del pedido para
/// calcular el estado agregado).
class PedidosHomeScreen extends ConsumerStatefulWidget {
  const PedidosHomeScreen({super.key});

  @override
  ConsumerState<PedidosHomeScreen> createState() => _PedidosHomeScreenState();
}

class _PedidosHomeScreenState extends ConsumerState<PedidosHomeScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(pedidosBusquedaProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;

    if (usuario != null && !usuario.tienePermiso('pedidos.ver')) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tenés permiso para ver el módulo de pedidos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final query = ref.watch(pedidosBusquedaProvider);
    final async = ref.watch(pedidosSeguimientoProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar por código, cliente...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(pedidosSeguimientoProvider),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    const SizedBox(height: 60),
                    Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
                  ],
                ),
                data: (subpedidos) {
                  final pedidos = _agruparPorPedido(subpedidos);
                  if (pedidos.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.faint),
                        SizedBox(height: 12),
                        Center(child: Text('Sin resultados', style: TextStyle(color: AppColors.muted))),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: pedidos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _PedidoTile(pedido: pedidos[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mismo orden que `ESTADOS_SEGUIMIENTO_DEPOSITO` en `pedidos_rout.py` (más
/// `ENTREGADO` al final) — es el único conjunto de estados que puede llegar
/// en `/pedidos/subpedidos/ver`, así que el índice acá sirve como "rank" de
/// avance para calcular el estado agregado del pedido.
const _ordenEstados = [
  'CONFIRMADO',
  'PICKING',
  'CONTROL',
  'CONTROLADO',
  'EN_CARGA',
  'EN_ENTREGA',
  'ENTREGADO',
];

/// Pedido agrupado para la lista: para tener un estado, TODOS sus
/// subpedidos visibles tienen que estar en ese estado o uno más avanzado —
/// por eso el agregado es el menos avanzado del grupo (el "cuello de
/// botella"), no el más avanzado.
class _PedidoAgrupado {
  const _PedidoAgrupado({required this.base, required this.estadoAgregado});

  final SubpedidoSeguimiento base;
  final String estadoAgregado;
}

List<_PedidoAgrupado> _agruparPorPedido(List<SubpedidoSeguimiento> subpedidos) {
  final porPedido = <int, List<SubpedidoSeguimiento>>{};
  final orden = <int>[];
  for (final sp in subpedidos) {
    if (!porPedido.containsKey(sp.idPedido)) orden.add(sp.idPedido);
    porPedido.putIfAbsent(sp.idPedido, () => []).add(sp);
  }
  return [
    for (final idPedido in orden)
      _PedidoAgrupado(
        base: porPedido[idPedido]!.first,
        estadoAgregado: porPedido[idPedido]!
            .map((sp) => sp.estado)
            .reduce((a, b) => _ordenEstados.indexOf(a) <= _ordenEstados.indexOf(b) ? a : b),
      ),
  ];
}

class _PedidoTile extends StatelessWidget {
  const _PedidoTile({required this.pedido});

  final _PedidoAgrupado pedido;

  @override
  Widget build(BuildContext context) {
    final base = pedido.base;
    final clienteSucursal = base.sucursalNombre != null
        ? '${base.clienteNombre} - ${base.sucursalNombre}'
        : base.clienteNombre;
    final estado = _EstadoVisual.de(pedido.estadoAgregado);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/pedidos/info/${base.idPedido}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.receipt_long_outlined, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clienteSucursal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    if (base.eta != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ETA ${formatFecha(base.eta!)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: estado.bg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  estado.etiqueta,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estado.fg),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
            ],
          ),
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

  static _EstadoVisual de(String estado) {
    switch (estado) {
      case 'CONFIRMADO':
        return const _EstadoVisual('Confirmado', AppColors.inBg, AppColors.inTx);
      case 'PICKING':
        return const _EstadoVisual('En picking', AppColors.waBg, AppColors.waTx);
      case 'CONTROL':
        return const _EstadoVisual('Control', AppColors.waBg, AppColors.waTx);
      case 'CONTROLADO':
        return const _EstadoVisual('Controlado', AppColors.inBg, AppColors.inTx);
      case 'EN_CARGA':
        return const _EstadoVisual('En carga', AppColors.inBg, AppColors.inTx);
      case 'EN_ENTREGA':
        return const _EstadoVisual('En entrega', AppColors.inBg, AppColors.inTx);
      case 'ENTREGADO':
        return const _EstadoVisual('Entregado', AppColors.okBg, AppColors.okTx);
      default:
        return _EstadoVisual(estado, AppColors.soft, AppColors.sub);
    }
  }
}
