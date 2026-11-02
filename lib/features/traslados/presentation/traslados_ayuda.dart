import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé el módulo" de Traslados — se abre desde el (?) del
/// AppBar de `TrasladosHomeScreen`. El contenedor y las pantallas son
/// comunes (`walkthrough_modulo.dart`); acá solo vive el contenido y la demo.
Future<void> abrirAyudaTraslados(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFEDE9FE);
const _fuerte = Color(0xFF7C3AED);
const _oscuro = Color(0xFF5B21B6);

const _modulo = WalkthroughModulo(
  icono: Icons.swap_horiz_outlined,
  nombre: 'Traslados',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Mover mercadería de una ubicación a otra y dejar cada producto en su lugar. '
      'Lo que llega de una recepción espera acá hasta que lo acomodes.',
  pasos: [
    'En "Pendientes" está lo que quedó en recepción o reacomodo: tocá "Trasladar".',
    'Poné la cantidad y elegí el destino, o tocá "Usar" para ir a la ubicación recomendada.',
    'Tocá "Ejecutar traslado" y el stock queda en la nueva ubicación.',
  ],
  consejo: 'Para mover algo que no está en Pendientes, tocá "Nuevo traslado": buscá o escaneá el '
      'producto y elegí de qué ubicación sale. Todo lo que moviste queda en "Historial".',
  textoFinal: '¡A trasladar!',
  demo: _DemoTraslado(),
);

typedef _Pendiente = ({String producto, String origen, String cantidad, String destino});

/// Ejemplos de la demo — cada vuelta arranca por el siguiente.
const _ejemplos = <_Pendiente>[
  (producto: 'Leche entera 1L', origen: 'REC-01', cantidad: '24 un', destino: 'A-03-02'),
  (producto: 'Harina 000 1kg', origen: 'REC-02', cantidad: '40 un', destino: 'B-01-03'),
  (producto: 'Agua mineral 2L', origen: 'REAC-01', cantidad: '18 un', destino: 'C-02-01'),
];

/// Línea de tiempo de cada vuelta (0 a 1):
/// - 0–0,15 el dedo va a "Trasladar" del primer pendiente; 0,15–0,19 toca.
/// - 0,22–0,32 sube la hoja del traslado.
/// - 0,32–0,42 el dedo va a "Usar" (ubicación recomendada); 0,42–0,46 toca
///   y el destino se completa con un saltito.
/// - 0,48–0,56 el dedo va a "Ejecutar traslado"; 0,56–0,60 toca.
/// - 0,62–0,70 baja la hoja.
/// - 0,68–0,80 el pendiente sale hacia la derecha con tilde, los demás
///   suben y el contador baja con un saltito.
class _DemoTraslado extends StatelessWidget {
  const _DemoTraslado();

  static const _yTarjetas = 42.0;
  static const _altoTarjeta = 50.0;
  static const _sepTarjeta = 8.0;
  static const _altoHoja = 128.0;

  static const _pTrasladar = Offset(222, _yTarjetas + _altoTarjeta / 2);
  static const _pUsar = Offset(230, WalkthroughDemo.alto - _altoHoja + 73);
  static const _pEjecutar = Offset(150, WalkthroughDemo.alto - _altoHoja + 108);

  static Offset _posDedo(double t) {
    const fuera = Offset(250, WalkthroughDemo.alto + 30);
    Offset mover(Offset a, Offset b, double desde, double hasta) =>
        Offset.lerp(a, b, Curves.easeInOutCubic.transform(walkthroughTramo(t, desde, hasta)))!;

    if (t < 0.22) return mover(fuera, _pTrasladar, 0.0, 0.15);
    if (t < 0.48) return mover(_pTrasladar, _pUsar, 0.32, 0.42);
    if (t < 0.62) return mover(_pUsar, _pEjecutar, 0.48, 0.56);
    return mover(_pEjecutar, fuera, 0.62, 0.78);
  }

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final items = [for (var i = 0; i < 3; i++) _ejemplos[(vuelta + i) % _ejemplos.length]];
        final hoja = t < 0.62 ? walkthroughTramo(t, 0.22, 0.32) : 1 - walkthroughTramo(t, 0.62, 0.70);
        final destino = walkthroughTramo(t, 0.44, 0.54);
        final salida = Curves.easeInCubic.transform(walkthroughTramo(t, 0.68, 0.78));
        final subida = Curves.easeOutCubic.transform(walkthroughTramo(t, 0.72, 0.82));
        final movido = t >= 0.72;
        final saltoContador = movido ? walkthroughTramo(t, 0.72, 0.84) : 0.0;

        final tocaTrasladar = t >= 0.15 && t < 0.19;
        final tocaUsar = t >= 0.42 && t < 0.46;
        final tocaEjecutar = t >= 0.56 && t < 0.60;
        final dedo = _posDedo(t);

        return Stack(
          children: [
            Positioned(
              left: 14,
              right: 14,
              top: 12,
              child: Row(
                children: [
                  const Text(
                    'PENDIENTES DE ACOMODAR',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                  ),
                  const Spacer(),
                  Transform.scale(
                    scale: 1 + 0.25 * math.sin(math.pi * saltoContador),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        movido ? '2' : '3',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _oscuro),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < 3; i++)
              Positioned(
                left: 12 + (i == 0 ? 260 * salida : 0),
                right: 12 - (i == 0 ? 260 * salida : 0),
                top: _yTarjetas + i * (_altoTarjeta + _sepTarjeta) - (i > 0 ? (_altoTarjeta + _sepTarjeta) * subida : 0),
                height: _altoTarjeta,
                child: Opacity(
                  opacity: i == 0 ? 1 - salida : 1,
                  child: _TarjetaPendiente(
                    item: items[i],
                    hecha: i == 0 && t >= 0.66,
                    presionada: i == 0 && tocaTrasladar,
                  ),
                ),
              ),
            if (hoja > 0) ...[
              Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.30 * hoja))),
              Positioned(
                left: 0,
                right: 0,
                height: _altoHoja,
                top: WalkthroughDemo.alto - _altoHoja * Curves.easeOutCubic.transform(hoja),
                child: _HojaTraslado(
                  item: items[0],
                  destino: destino,
                  tocaUsar: tocaUsar,
                  tocaEjecutar: tocaEjecutar,
                ),
              ),
            ],
            Positioned(
              left: dedo.dx - WalkthroughDedo.radio,
              top: dedo.dy - WalkthroughDedo.radio,
              child: WalkthroughDedo(color: _fuerte, tocando: tocaTrasladar || tocaUsar || tocaEjecutar),
            ),
          ],
        );
      },
    );
  }
}

class _TarjetaPendiente extends StatelessWidget {
  const _TarjetaPendiente({required this.item, required this.hecha, required this.presionada});

  final _Pendiente item;
  final bool hecha;
  final bool presionada;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: hecha ? _pastel : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 1),
                Text(
                  hecha ? 'Movido a ${item.destino}' : '${item.origen} · ${item.cantidad}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: hecha ? FontWeight.w700 : FontWeight.w400,
                    color: hecha ? _oscuro : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (hecha)
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(color: _fuerte, shape: BoxShape.circle),
              child: const Icon(Icons.check, size: 15, color: Colors.white),
            )
          else
            AnimatedScale(
              duration: const Duration(milliseconds: 90),
              scale: presionada ? 0.88 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _fuerte, borderRadius: BorderRadius.circular(999)),
                child: const Text(
                  'Trasladar',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HojaTraslado extends StatelessWidget {
  const _HojaTraslado({
    required this.item,
    required this.destino,
    required this.tocaUsar,
    required this.tocaEjecutar,
  });

  final _Pendiente item;

  /// 0 = sin destino, 0→1 = se completa con la ubicación recomendada.
  final double destino;
  final bool tocaUsar;
  final bool tocaEjecutar;

  @override
  Widget build(BuildContext context) {
    final conDestino = destino > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.producto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                ),
                Text(item.cantidad, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sub)),
              ],
            ),
          ),
          Positioned(
            top: 34,
            left: 14,
            right: 14,
            child: Row(
              children: [
                _Chip(texto: item.origen, relleno: AppColors.surface, color: AppColors.sub),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 14, color: AppColors.faint),
                ),
                Transform.scale(
                  scale: conDestino ? Curves.elasticOut.transform(destino) : 1,
                  child: _Chip(
                    texto: conDestino ? item.destino : 'Destino',
                    relleno: conDestino ? _fuerte : AppColors.surface,
                    color: conDestino ? Colors.white : AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 58,
            left: 12,
            right: 12,
            height: 30,
            child: Container(
              padding: const EdgeInsets.only(left: 10, right: 6),
              decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: _oscuro),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Recomendada: ${item.destino}',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _oscuro),
                    ),
                  ),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 90),
                    scale: tocaUsar ? 0.85 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
                      child: const Text('Usar', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _oscuro)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 95,
            left: 12,
            right: 12,
            height: 28,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 90),
              scale: tocaEjecutar ? 0.95 : 1,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: conDestino ? _oscuro : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Ejecutar traslado',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.relleno, required this.color});

  final String texto;
  final Color relleno;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: relleno,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}
