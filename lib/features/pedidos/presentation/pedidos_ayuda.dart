import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé el módulo" de Pedidos — se abre desde el (?) del
/// AppBar de `PedidosHomeScreen`. El contenedor y las pantallas son comunes
/// (`walkthrough_modulo.dart`); acá solo vive el contenido y la demo.
/// Pedidos no tiene tarjeta en el menú (es pestaña del bottom nav), así que
/// usa el azul de la app.
Future<void> abrirAyudaPedidos(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFDBEAFE);
const _fuerte = AppColors.accent;
const _oscuro = AppColors.accentDark;

const _modulo = WalkthroughModulo(
  icono: Icons.receipt_long_outlined,
  nombre: 'Pedidos',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Seguir cada pedido desde que se confirma hasta que se entrega: para quién es, '
      'cuándo tiene que salir y en qué paso está.',
  pasos: [
    'La lista arranca por lo más urgente: en rojo lo vencido y en naranja lo que es para hoy.',
    'Tocá un pedido para ver sus subpedidos o cambiar la ETA y el lugar de entrega.',
    'Con el botón + (abajo a la derecha) creás un pedido nuevo: cliente, sucursal y ETA.',
  ],
  consejo: 'Usá el buscador para encontrar un pedido por código o cliente. '
      'Cuando un pedido se entrega, deja de aparecer en la lista.',
  textoFinal: '¡Entendido!',
  demo: _DemoPedidos(),
);

/// Urgencia de la ETA: 0 = vencido, 1 = hoy, 2 = más adelante.
typedef _Pedido = ({String sucursal, String eta, int urgencia, String cliente, String lugar, String movil});

/// Ejemplos de la demo — cada vuelta usa el siguiente juego: 3 pedidos en
/// la lista (ordenados por urgencia) + el que se crea con "+".
const _ejemplos = <List<_Pedido>>[
  [
    (sucursal: 'Remolcador Itá', eta: 'Ayer 17:00', urgencia: 0, cliente: 'Naviera Sur', lugar: 'Puerto Villeta', movil: 'Móvil 3'),
    (sucursal: 'Oficina Central', eta: 'Hoy 14:00', urgencia: 1, cliente: 'Agro Norte', lugar: 'Depósito Luque', movil: 'Móvil 1'),
    (sucursal: 'Sucursal Centro', eta: '12/11 09:00', urgencia: 2, cliente: 'Hotel Palmas', lugar: 'Cocina', movil: 'Móvil 2'),
    (sucursal: 'Barcaza 7', eta: '14/11 08:00', urgencia: 2, cliente: 'Fluvial SA', lugar: 'Puerto Seguro', movil: 'Móvil 4'),
  ],
  [
    (sucursal: 'Remolcador Paraná', eta: 'Hoy 08:00', urgencia: 0, cliente: 'Río Cargo', lugar: 'Muelle 2', movil: 'Móvil 2'),
    (sucursal: 'Planta Norte', eta: 'Hoy 16:30', urgencia: 1, cliente: 'Lácteos Sur', lugar: 'Andén 4', movil: 'Móvil 5'),
    (sucursal: 'Oficina Este', eta: '13/11 10:00', urgencia: 2, cliente: 'Constructora Alfa', lugar: 'Obra Mburucuyá', movil: 'Móvil 1'),
    (sucursal: 'Hotel Costa', eta: '15/11 07:00', urgencia: 2, cliente: 'Costa Hoteles', lugar: 'Recepción', movil: 'Móvil 3'),
  ],
];

typedef _Estado = ({String etiqueta, Color bg, Color fg});

const _estados = <_Estado>[
  (etiqueta: 'Confirmado', bg: AppColors.inBg, fg: AppColors.inTx),
  (etiqueta: 'En picking', bg: AppColors.waBg, fg: AppColors.waTx),
  (etiqueta: 'Controlado', bg: AppColors.inBg, fg: AppColors.inTx),
  (etiqueta: 'En entrega', bg: AppColors.inBg, fg: AppColors.inTx),
  (etiqueta: 'Entregado', bg: AppColors.okBg, fg: AppColors.okTx),
];
const _sinSubpedidos = (etiqueta: 'Sin subpedidos', bg: AppColors.alertBg, fg: AppColors.alertTx);

/// Demo — línea de tiempo de cada vuelta (0 a 1):
/// - 0,14 / 0,28 / 0,42 / 0,56 el primer pedido avanza de estado (la
///   píldora da un saltito): En picking → Controlado → En entrega → Entregado.
/// - 0,62–0,72 el entregado sale de la lista hacia la derecha; los demás
///   suben y el contador baja.
/// - 0,66–0,78 el dedo va al "+"; 0,78–0,82 toca.
/// - 0,84–0,94 entra con rebote el pedido nuevo ("Sin subpedidos") y el
///   contador vuelve a subir.
class _DemoPedidos extends StatelessWidget {
  const _DemoPedidos();

  static const _cambios = [0.14, 0.28, 0.42, 0.56];
  static const _yTarjetas = 30.0;
  static const _altoTarjeta = 48.0;
  static const _sepTarjeta = 6.0;
  static const _pFab = Offset(236, 182);

  static double _ySlot(double slot) => _yTarjetas + slot * (_altoTarjeta + _sepTarjeta);

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final pedidos = _ejemplos[vuelta % _ejemplos.length];
        final paso = _cambios.where((k) => t >= k).length;
        final ultimoCambio = paso > 0 ? _cambios[paso - 1] : -1.0;
        final saltoEstado = paso > 0 ? walkthroughTramo(t, ultimoCambio, ultimoCambio + 0.1) : 1.0;

        final salida = Curves.easeInCubic.transform(walkthroughTramo(t, 0.62, 0.72));
        final subida = Curves.easeOutCubic.transform(walkthroughTramo(t, 0.66, 0.76));
        final nuevo = walkthroughTramo(t, 0.84, 0.94);
        final cantidad = t < 0.68 ? 3 : (t < 0.86 ? 2 : 3);
        final saltoContador = t < 0.68
            ? 1.0
            : t < 0.86
            ? walkthroughTramo(t, 0.68, 0.8)
            : walkthroughTramo(t, 0.86, 0.96);

        const fuera = Offset(250, WalkthroughDemo.alto + 30);
        final dedo = t < 0.82
            ? Offset.lerp(fuera, _pFab, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.66, 0.78)))!
            : Offset.lerp(_pFab, fuera, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.84, 0.96)))!;
        final tocaFab = t >= 0.78 && t < 0.82;

        return Stack(
          children: [
            Positioned(
              left: 14,
              top: 10,
              child: Transform.scale(
                scale: 1 + 0.2 * math.sin(math.pi * saltoContador),
                alignment: Alignment.centerLeft,
                child: Text(
                  '$cantidad pedidos',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
              ),
            ),
            // El primero: avanza de estado y, entregado, sale de la lista.
            Positioned(
              left: 10 + 260 * salida,
              right: 10 - 260 * salida,
              top: _ySlot(0),
              height: _altoTarjeta,
              child: Opacity(
                opacity: 1 - salida,
                child: _TarjetaPedido(
                  pedido: pedidos[0],
                  estado: _estados[paso],
                  saltoEstado: saltoEstado,
                ),
              ),
            ),
            for (var i = 1; i < 3; i++)
              Positioned(
                left: 10,
                right: 10,
                top: _ySlot(i - subida),
                height: _altoTarjeta,
                child: _TarjetaPedido(pedido: pedidos[i], estado: _estados[0], saltoEstado: 1),
              ),
            if (nuevo > 0)
              Positioned(
                left: 10,
                right: 10,
                top: _ySlot(2),
                height: _altoTarjeta,
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(nuevo),
                  child: _TarjetaPedido(pedido: pedidos[3], estado: _sinSubpedidos, saltoEstado: 1),
                ),
              ),
            Positioned(
              left: _pFab.dx - 18,
              top: _pFab.dy - 18,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 90),
                scale: tocaFab ? 0.88 : 1,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _fuerte,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: _fuerte.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: dedo.dx - WalkthroughDedo.radio,
              top: dedo.dy - WalkthroughDedo.radio,
              child: WalkthroughDedo(color: _fuerte, tocando: tocaFab),
            ),
          ],
        );
      },
    );
  }
}

/// Réplica chica de la tarjeta real de `PedidosHomeScreen`:
///   **Sucursal** · ETA                    (Estado)
///   Cliente · Lugar de entrega · Móvil
class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({required this.pedido, required this.estado, required this.saltoEstado});

  final _Pedido pedido;
  final _Estado estado;

  /// 0→1 tras un cambio de estado: la píldora da un saltito.
  final double saltoEstado;

  @override
  Widget build(BuildContext context) {
    final etaColor = switch (pedido.urgencia) {
      0 => AppColors.erTx,
      1 => AppColors.alertTx,
      _ => AppColors.muted,
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(width: 3, color: pedido.urgencia <= 1 ? etaColor : Colors.transparent),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: pedido.sucursal,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                              ),
                              const TextSpan(text: ' · ', style: TextStyle(color: AppColors.faint)),
                              TextSpan(
                                text: pedido.eta,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: etaColor),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 1 + 0.25 * math.sin(math.pi * saltoEstado),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: estado.bg, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            estado.etiqueta,
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: estado.fg),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: pedido.cliente),
                        const TextSpan(text: ' · ', style: TextStyle(color: AppColors.faint)),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.place_outlined, size: 10, color: AppColors.faint),
                        ),
                        TextSpan(text: pedido.lugar),
                        const TextSpan(text: ' · ', style: TextStyle(color: AppColors.faint)),
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(Icons.local_shipping_outlined, size: 10, color: AppColors.faint),
                        ),
                        TextSpan(text: ' ${pedido.movil}'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
