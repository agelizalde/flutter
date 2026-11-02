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
import 'pedidos_ayuda.dart';
import 'widgets/nuevo_pedido_sheet.dart';

/// Entrada al módulo "Pedidos" (`/pedidos`, tab del bottom nav): lista los
/// pedidos en curso, desde que el subpedido se confirma hasta que se
/// entrega — una vez `ENTREGADO` deja de figurar (la aprobación de la
/// entrega se hace desde Firmas). Junta DOS fuentes
/// (ver `pedidos_providers.dart`): el seguimiento por subpedido (`GET
/// /pedidos/subpedidos/ver`, la mayoría de los casos) y los pedidos `ACTIVO`
/// que todavía no tienen ningún subpedido (`GET /pedidos/sin-subpedidos`) —
/// sin esto último, un pedido recién creado desde `NuevoPedidoSheet` queda
/// invisible hasta que alguien le arma el primer subpedido desde la web.
/// Buscador libre (server-side, aplica a ambas fuentes). La lista se ordena
/// por urgencia de ETA para que lo vencido/para hoy quede arriba (sin filtro
/// por estado — se sacaron los chips rápidos a pedido del usuario).
class PedidosHomeScreen extends ConsumerStatefulWidget {
  const PedidosHomeScreen({super.key});

  @override
  ConsumerState<PedidosHomeScreen> createState() => _PedidosHomeScreenState();
}

/// Fondo de la pantalla un tono más oscuro que `AppColors.pageBg`: con el
/// gris global las tarjetas blancas se mezclaban con el fondo.
const _fondo = Color(0xFFE9EDF3);

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
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Pedidos'),
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border)),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '¿Cómo funciona?',
            onPressed: () => abrirAyudaPedidos(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: puedeCrear
          ? FloatingActionButton(
              onPressed: _nuevoPedido,
              tooltip: 'Nuevo pedido',
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              // Relleno blanco (el `soft` del tema es igual al fondo gris y
              // el buscador desaparecía) con borde suave para despegarlo.
              decoration: InputDecoration(
                hintText: 'Buscar por código, cliente...',
                prefixIcon: const Icon(Icons.search),
                fillColor: AppColors.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
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
    // Spinner solo en la primera carga: en un refresco (por acción del
    // usuario, ver `RefrescoPorAccion`) se siguen mostrando los datos
    // anteriores hasta que llegan los nuevos, sin parpadeo.
    if (!subpedidosAsync.hasValue && subpedidosAsync.isLoading ||
        !sinSubpedidosAsync.hasValue && sinSubpedidosAsync.isLoading) {
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

    // El backend ya no manda `ENTREGADO`, pero se filtra igual acá por si
    // la app habla con un servidor sin actualizar: lo entregado no figura.
    final enCurso = (subpedidosAsync.value ?? const <SubpedidoSeguimiento>[])
        .where((sp) => sp.estado != 'ENTREGADO')
        .toList();
    final todos = [
      ..._agruparPorPedido(enCurso),
      ..._deSinSubpedidos(sinSubpedidosAsync.value ?? const []),
    ]..sort(_compararPorUrgencia);

    if (todos.isEmpty) {
      return const _EstadoVacio(
        icono: Icons.receipt_long_outlined,
        texto: 'Sin resultados',
      );
    }

    return ListView.separated(
      // Abajo deja lugar para el botón flotante "Nuevo pedido".
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
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

/// Mismo orden que `ESTADOS_SEGUIMIENTO_DEPOSITO` en `pedidos_rout.py` — es
/// el único conjunto de estados que puede llegar
/// en `/pedidos/subpedidos/ver`, así que el índice acá sirve como "rank" de
/// avance para calcular el estado agregado del pedido.
const _ordenEstados = [
  'CONFIRMADO',
  'PICKING',
  'CONTROL',
  'CONTROLADO',
  'EN_CARGA',
  'EN_ENTREGA',
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
    this.vehiculoNombre,
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
    vehiculoNombre: sp.vehiculoNombre,
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
    vehiculoNombre: p.vehiculoNombre,
    eta: p.eta,
  );

  final int idPedido;
  final String codigoPedido;
  final String clienteNombre;
  final String? sucursalNombre;
  final String? sucursalTipoCodigo;
  final String? sucursalTipoNombre;
  final String? lugarEntregaNombre;
  final String? vehiculoNombre;
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
/// vencido < para hoy < con fecha futura < sin ETA.
int _prioridadUrgencia(_PedidoAgrupado p) {
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

/// Separador entre datos de una misma línea de la tarjeta.
const _separador = TextSpan(text: '  ·  ', style: TextStyle(color: AppColors.faint));

/// Dato con ícono chiquito adelante (lugar de entrega, móvil) para la
/// segunda línea de la tarjeta.
List<InlineSpan> _datoConIcono(IconData icono, String texto) => [
  WidgetSpan(
    alignment: PlaceholderAlignment.middle,
    child: Padding(
      padding: const EdgeInsets.only(right: 3),
      child: Icon(icono, size: 13, color: AppColors.faint),
    ),
  ),
  TextSpan(text: texto),
];

/// Tarjeta de un pedido:
///   **Sucursal** · ETA                                   (Estado)
///   Cliente · (ícono) Lugar de entrega · (ícono) Móvil
/// Sin sucursal, el cliente pasa a ser el título (y no se repite abajo). La
/// ETA toma el color de urgencia (rojo vencido, naranja para hoy), igual
/// que la franja de la izquierda.
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

    final tieneSucursal = base.sucursalNombre?.trim().isNotEmpty == true;
    final titulo = tieneSucursal ? base.sucursalNombre! : base.clienteNombre;

    // Segunda línea: cada dato se agrega solo si existe, con separador
    // entre los que quedan.
    final datos = <List<InlineSpan>>[
      if (tieneSucursal) [TextSpan(text: base.clienteNombre)],
      if (base.lugarEntregaNombre != null) _datoConIcono(Icons.place_outlined, base.lugarEntregaNombre!),
      if (base.vehiculoNombre != null) _datoConIcono(Icons.local_shipping_outlined, base.vehiculoNombre!),
      if (pedido.totalSubpedidos > 1) [TextSpan(text: '${pedido.totalSubpedidos} subpedidos')],
    ];
    if (datos.isEmpty) datos.add([TextSpan(text: base.codigoPedido)]);
    final detalle = <InlineSpan>[
      for (var i = 0; i < datos.length; i++) ...[
        if (i > 0) _separador,
        ...datos[i],
      ],
    ];

    // Franja de urgencia a la izquierda (roja = vencido, ámbar = para hoy):
    // permite escanear la lista de un vistazo sin tener que leer la ETA de
    // cada tarjeta. Neutra (transparente) para el resto, así el ancho de la
    // tarjeta no varía entre ítems.
    final franjaUrgencia = urgencia <= 0 ? etaColor : Colors.transparent;

    // La sombra y el borde van en un Container POR FUERA del Material: antes
    // la sombra estaba adentro del clip y no se veía, y la tarjeta se
    // confundía con el fondo.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/pedidos/info/${base.idPedido}'),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: franjaUrgencia),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(_iconoTipoSucursal(base), color: AppColors.accentDark, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text: titulo,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          _separador,
                                          TextSpan(
                                            text: base.eta != null ? formatFechaHora(base.eta!) : 'Sin ETA',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: urgencia <= 0 ? FontWeight.w800 : FontWeight.w600,
                                              color: base.eta != null ? etaColor : AppColors.faint,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: estado.bg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      estado.etiqueta,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: estado.fg),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text.rich(
                                TextSpan(children: detalle),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
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
