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
import 'widgets/nuevo_pedido_sheet.dart';

/// Entrada al módulo "Pedidos" (`/pedidos`, tab del bottom nav): lista los
/// pedidos que el usuario puede seguir, según su permiso — `pedidos.ver`
/// alcanza hasta el momento en que el subpedido se entrega; quien además
/// tiene `pedidos_subpedidos.aprobar_entrega` lo sigue viendo en
/// `ENTREGADO` hasta que la firma de entrega se resuelve. Junta DOS fuentes
/// (ver `pedidos_providers.dart`): el seguimiento por subpedido (`GET
/// /pedidos/subpedidos/ver`, la mayoría de los casos) y los pedidos `ACTIVO`
/// que todavía no tienen ningún subpedido (`GET /pedidos/sin-subpedidos`) —
/// sin esto último, un pedido recién creado desde `NuevoPedidoSheet` queda
/// invisible hasta que alguien le arma el primer subpedido desde la web.
/// Buscador libre (server-side, aplica a ambas fuentes). La lista se ordena
/// por urgencia de ETA para que lo vencido/para hoy quede arriba, salvo lo
/// ya `ENTREGADO` (sin filtro por estado — se sacaron los chips rápidos a
/// pedido del usuario).
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

  Future<void> _nuevoPedido() async {
    final repositorio = ref.read(pedidosRepositoryProvider);
    final creado = await abrirNuevoPedidoSheet(context, repositorio);
    if (creado == null || !mounted) return;
    // La cabecera creada nace `ACTIVO` y sin subpedidos: ya va a aparecer
    // en la lista (grupo "Sin subpedidos"), solo hace falta refrescar esa
    // fuente para que no haga falta un pull-to-refresh manual.
    ref.invalidate(pedidosSinSubpedidosProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pedido ${creado.codigoPedido} creado')),
    );
    context.push('/pedidos/info/${creado.idPedido}');
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;
    final puedeCrear = usuario?.tienePermiso('pedidos.crear') ?? false;

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
    final subpedidosAsync = ref.watch(pedidosSeguimientoProvider(query));
    final sinSubpedidosAsync = ref.watch(pedidosSinSubpedidosProvider(query));

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Pedidos'),
        actions: [
          if (puedeCrear)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: _nuevoPedido,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: AppColors.accent,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo pedido'),
              ),
            ),
        ],
      ),
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
          const SizedBox(height: 4),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(pedidosSeguimientoProvider);
                ref.invalidate(pedidosSinSubpedidosProvider);
              },
              child: _Contenido(
                subpedidosAsync: subpedidosAsync,
                sinSubpedidosAsync: sinSubpedidosAsync,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Junta las dos fuentes (`AsyncValue.when` no tiene combinador de a dos
/// out-of-the-box) y recién ahí arma la lista — mientras cualquiera esté
/// cargando se muestra el spinner, y el primer error que aparezca corta el
/// combinado, igual que haría un solo `.when()`. Ya no filtra por estado
/// agregado (se sacaron los chips rápidos a pedido del usuario): la lista
/// completa siempre se ordena por urgencia de ETA.
class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.subpedidosAsync,
    required this.sinSubpedidosAsync,
  });

  final AsyncValue<List<SubpedidoSeguimiento>> subpedidosAsync;
  final AsyncValue<List<PedidoSinSubpedidos>> sinSubpedidosAsync;

  @override
  Widget build(BuildContext context) {
    if (subpedidosAsync.isLoading || sinSubpedidosAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = subpedidosAsync.error ?? sinSubpedidosAsync.error;
    if (error != null) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Center(
            child: Text(
              describeError(error),
              style: const TextStyle(color: AppColors.erTx),
            ),
          ),
        ],
      );
    }

    final todos = [
      ..._agruparPorPedido(subpedidosAsync.value ?? const []),
      ..._deSinSubpedidos(sinSubpedidosAsync.value ?? const []),
    ]..sort(_compararPorUrgencia);

    if (todos.isEmpty) {
      return const _EstadoVacio(
        icono: Icons.receipt_long_outlined,
        texto: 'Sin resultados',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: todos.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '${todos.length} pedido(s)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
            ),
          );
        }
        return _PedidoTile(pedido: todos[i - 1]);
      },
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: AppColors.faint),
            const SizedBox(height: 12),
            Text(texto, style: const TextStyle(color: AppColors.muted)),
          ],
        ),
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

/// Sentinela para un pedido sin ningún subpedido todavía (ver
/// `PedidoSinSubpedidos`) — no es un estado real de `pedidos_subpedido`,
/// por eso vive separado de `_ordenEstados` (ese sí tiene que reflejar
/// 1:1 lo que puede llegar en `/subpedidos/ver`).
const _estadoSinSubpedidos = 'SIN_SUBPEDIDOS';

/// Datos comunes que necesita `_PedidoTile`, vengan de un subpedido de
/// seguimiento (`SubpedidoSeguimiento`, el caso normal) o de un pedido que
/// todavía no tiene ninguno (`PedidoSinSubpedidos`).
class _PedidoInfo {
  const _PedidoInfo({
    required this.idPedido,
    required this.codigoPedido,
    required this.clienteNombre,
    this.sucursalNombre,
    this.sucursalTipoCodigo,
    this.sucursalTipoNombre,
    this.lugarEntregaNombre,
    this.eta,
  });

  factory _PedidoInfo.deSubpedido(SubpedidoSeguimiento sp) => _PedidoInfo(
    idPedido: sp.idPedido,
    codigoPedido: sp.codigoPedido,
    clienteNombre: sp.clienteNombre,
    sucursalNombre: sp.sucursalNombre,
    sucursalTipoCodigo: sp.sucursalTipoCodigo,
    sucursalTipoNombre: sp.sucursalTipoNombre,
    lugarEntregaNombre: sp.lugarEntregaNombre,
    eta: sp.eta,
  );

  factory _PedidoInfo.dePedido(PedidoSinSubpedidos p) => _PedidoInfo(
    idPedido: p.idPedido,
    codigoPedido: p.codigoPedido,
    clienteNombre: p.clienteNombre,
    sucursalNombre: p.sucursalNombre,
    sucursalTipoCodigo: p.sucursalTipoCodigo,
    sucursalTipoNombre: p.sucursalTipoNombre,
    lugarEntregaNombre: p.lugarEntregaNombre,
    eta: p.eta,
  );

  final int idPedido;
  final String codigoPedido;
  final String clienteNombre;
  final String? sucursalNombre;
  final String? sucursalTipoCodigo;
  final String? sucursalTipoNombre;
  final String? lugarEntregaNombre;
  final DateTime? eta;
}

/// Pedido agrupado para la lista: para tener un estado, TODOS sus
/// subpedidos visibles tienen que estar en ese estado o uno más avanzado —
/// por eso el agregado es el menos avanzado del grupo (el "cuello de
/// botella"), no el más avanzado.
class _PedidoAgrupado {
  const _PedidoAgrupado({
    required this.base,
    required this.estadoAgregado,
    required this.totalSubpedidos,
  });

  final _PedidoInfo base;
  final String estadoAgregado;
  final int totalSubpedidos;
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
        base: _PedidoInfo.deSubpedido(porPedido[idPedido]!.first),
        estadoAgregado: porPedido[idPedido]!
            .map((sp) => sp.estado)
            .reduce(
              (a, b) =>
                  _ordenEstados.indexOf(a) <= _ordenEstados.indexOf(b) ? a : b,
            ),
        totalSubpedidos: porPedido[idPedido]!.length,
      ),
  ];
}

List<_PedidoAgrupado> _deSinSubpedidos(List<PedidoSinSubpedidos> pedidos) => [
  for (final p in pedidos)
    _PedidoAgrupado(
      base: _PedidoInfo.dePedido(p),
      estadoAgregado: _estadoSinSubpedidos,
      totalSubpedidos: 0,
    ),
];

/// Urgencia según ETA, para ordenar la lista con lo más apremiante arriba:
/// vencido < para hoy < con fecha futura < sin ETA. Lo ya `ENTREGADO` no
/// necesita atención, así que se manda al fondo sin importar su ETA.
int _prioridadUrgencia(_PedidoAgrupado p) {
  if (p.estadoAgregado == 'ENTREGADO') return 3;
  final eta = p.base.eta;
  if (eta == null) return 2;
  final hoy = DateTime.now();
  final diasHastaEta = DateTime(
    eta.year,
    eta.month,
    eta.day,
  ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  if (diasHastaEta < 0) return -1;
  if (diasHastaEta == 0) return 0;
  return 1;
}

int _compararPorUrgencia(_PedidoAgrupado a, _PedidoAgrupado b) {
  final rank = _prioridadUrgencia(a).compareTo(_prioridadUrgencia(b));
  if (rank != 0) return rank;
  final etaA = a.base.eta;
  final etaB = b.base.eta;
  if (etaA == null || etaB == null) return 0;
  return etaA.compareTo(etaB);
}

/// Ícono del recuadro a la izquierda de cada tarjeta, según el tipo de
/// sucursal del cliente (`clientes_sucursal_tipo` — hoy "Oficina"/"OFI" y
/// "Remolcador", pero el set es editable desde Ajustes, así que se matchea
/// por substring en vez de un enum cerrado). Sin sucursal o tipo
/// desconocido, un ícono neutro de "lugar de entrega".
IconData _iconoTipoSucursal(_PedidoInfo base) {
  final tipo =
      ((base.sucursalTipoCodigo ?? '') + (base.sucursalTipoNombre ?? ''))
          .toUpperCase();
  if (tipo.contains('REMOLCADOR')) return Icons.local_shipping_outlined;
  if (tipo.contains('OFI')) return Icons.business_outlined;
  return Icons.storefront_outlined;
}

/// Arma "Sucursal · ETA · Lugar de entrega" como spans (no un solo string)
/// para poder resaltar la ETA con su color de urgencia sin perder el resto
/// en gris — se recorta con ellipsis como una sola línea, así que el orden
/// importa: lo más urgente va primero.
List<InlineSpan> _metaSpans(_PedidoInfo base, int urgencia, Color etaColor) {
  const separador = TextSpan(
    text: '  ·  ',
    style: TextStyle(color: AppColors.faint),
  );
  final partes = <InlineSpan>[];

  if (base.sucursalNombre != null) {
    partes.add(
      TextSpan(
        text: base.sucursalNombre,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
      ),
    );
  }
  if (base.eta != null) {
    if (partes.isNotEmpty) partes.add(separador);
    partes.add(
      TextSpan(
        text: formatFechaHora(base.eta!),
        style: TextStyle(
          fontWeight: urgencia <= 0 ? FontWeight.w700 : FontWeight.w600,
          color: etaColor,
        ),
      ),
    );
  }
  if (base.lugarEntregaNombre != null) {
    if (partes.isNotEmpty) partes.add(separador);
    partes.add(
      TextSpan(
        text: base.lugarEntregaNombre,
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
  if (partes.isEmpty) {
    partes.add(
      TextSpan(
        text: base.codigoPedido,
        style: const TextStyle(color: AppColors.muted),
      ),
    );
  }
  return partes;
}

class _PedidoTile extends StatelessWidget {
  const _PedidoTile({required this.pedido});

  final _PedidoAgrupado pedido;

  @override
  Widget build(BuildContext context) {
    final base = pedido.base;
    final estado = _EstadoVisual.de(pedido.estadoAgregado);
    final urgencia = _prioridadUrgencia(pedido);
    final etaColor = urgencia == -1
        ? AppColors.erTx
        : urgencia == 0
        ? AppColors.alertTx
        : AppColors.muted;
    final segundaLinea = pedido.totalSubpedidos > 1
        ? '${base.clienteNombre}  ·  ${pedido.totalSubpedidos} subpedidos'
        : base.clienteNombre;

    // Franja de urgencia a la izquierda (roja = vencido, ámbar = para hoy):
    // permite escanear la lista de un vistazo sin tener que leer la ETA de
    // cada tarjeta. Neutra (transparente) para el resto, así el ancho de la
    // tarjeta no varía entre ítems.
    final franjaUrgencia = urgencia <= 0 ? etaColor : Colors.transparent;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/pedidos/info/${base.idPedido}'),
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: franjaUrgencia),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconoTipoSucursal(base),
                            color: AppColors.accentDark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: _metaSpans(base, urgencia, etaColor),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: estado.bg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      estado.etiqueta,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: estado.fg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                segundaLinea,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
      case _estadoSinSubpedidos:
        return const _EstadoVisual(
          'Sin subpedidos',
          AppColors.alertBg,
          AppColors.alertTx,
        );
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
      case 'CONTROLADO':
        return const _EstadoVisual(
          'Controlado',
          AppColors.inBg,
          AppColors.inTx,
        );
      case 'EN_CARGA':
        return const _EstadoVisual('En carga', AppColors.inBg, AppColors.inTx);
      case 'EN_ENTREGA':
        return const _EstadoVisual(
          'En entrega',
          AppColors.inBg,
          AppColors.inTx,
        );
      case 'ENTREGADO':
        return const _EstadoVisual('Entregado', AppColors.okBg, AppColors.okTx);
      default:
        return _EstadoVisual(estado, AppColors.soft, AppColors.sub);
    }
  }
}
