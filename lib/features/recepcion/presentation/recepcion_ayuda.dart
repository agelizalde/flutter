import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé el módulo" de Recepción — se abre desde el menú ⚙️
/// del hero de `RecepcionHomeScreen` ("¿Cómo funciona?"). El contenedor y
/// las pantallas son comunes (`walkthrough_modulo.dart`); acá solo vive el
/// contenido y la demo.
Future<void> abrirAyudaRecepcion(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFDCFCE7);
const _fuerte = Color(0xFF16A34A);
const _oscuro = Color(0xFF15803D);

const _modulo = WalkthroughModulo(
  icono: Icons.move_to_inbox_outlined,
  nombre: 'Recepción',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Registrar la mercadería que llega al depósito: qué llegó, cuánto, de qué lote y si vino algo mal. '
      'Así el stock entra al sistema tal cual llegó.',
  pasos: [
    'Tocá "Recibir OC" y escaneá el QR de la orden de compra, o elegí el proveedor.',
    'En cada producto cargá cuánto llegó y, si te lo pide, el lote, el vencimiento o el peso.',
    'Tocá "Continuar" y confirmá la recepción: queda registrada y, si hace falta, pasa a control.',
  ],
  consejo: 'Si algo llegó roto o de más, cargalo en "Rechazada" con el motivo. Lo que no llegó '
      'sigue pendiente en la OC para la próxima entrega.',
  textoFinal: '¡A recibir!',
  demo: _DemoRecepcion(),
);

typedef _Item = ({String producto, String cantidad, String lote});
typedef _Oc = ({String codigo, String proveedor, List<_Item> items});

/// Ejemplos de la demo — cada vuelta usa la siguiente OC.
const _ejemplos = <_Oc>[
  (
    codigo: 'OC-00029',
    proveedor: 'Distribuidora Sur',
    items: [
      (producto: 'Leche entera 1L', cantidad: '24 un', lote: 'Lote L2311 · vence 12/2026'),
      (producto: 'Yogur frutilla 200g', cantidad: '48 un', lote: 'Lote Y0907 · vence 01/2027'),
    ],
  ),
  (
    codigo: 'OC-00031',
    proveedor: 'Frigorífico Norte',
    items: [
      (producto: 'Carne picada', cantidad: '18,4 kg', lote: 'Pesado · faena 28/10'),
      (producto: 'Pechuga de pollo', cantidad: '12,1 kg', lote: 'Pesado · vence 15/11'),
    ],
  ),
  (
    codigo: 'OC-00034',
    proveedor: 'Limpieza Total',
    items: [
      (producto: 'Detergente 750ml', cantidad: '36 un', lote: 'Lote D5512'),
      (producto: 'Lavandina 1L', cantidad: '24 un', lote: 'Lote LV201'),
    ],
  ),
];

/// Demo "formulario" — línea de tiempo de cada vuelta (0 a 1):
/// - 0–0,12 el dedo va a "Escanear QR de la OC"; 0,12–0,16 toca.
/// - 0,16–0,32 se abre la cámara y el láser recorre el QR.
/// - 0,32–0,38 aparece la OC con sus ítems sin cargar.
/// - 0,38 / 0,50 el dedo toca la cantidad de cada ítem: se completa con
///   un saltito y aparece el lote.
/// - 0,62–0,70 el dedo va a "Confirmar recepción"; 0,70–0,74 toca.
/// - 0,76–0,86 entra con rebote el sello "Recepción confirmada".
class _DemoRecepcion extends StatelessWidget {
  const _DemoRecepcion();

  static const _tCargas = [0.42, 0.54];
  static const _yItems = 46.0;
  static const _altoItem = 50.0;
  static const _sepItem = 8.0;

  static const _pEscanear = Offset(200, 66);
  static Offset _pCantidad(int i) => Offset(228, _yItems + i * (_altoItem + _sepItem) + _altoItem / 2);
  static const _pConfirmar = Offset(150, 178);

  static Offset _posDedo(double t) {
    const fuera = Offset(250, WalkthroughDemo.alto + 30);
    Offset mover(Offset a, Offset b, double desde, double hasta) =>
        Offset.lerp(a, b, Curves.easeInOutCubic.transform(walkthroughTramo(t, desde, hasta)))!;

    if (t < 0.2) return mover(fuera, _pEscanear, 0.0, 0.12);
    if (t < 0.32) return fuera;
    if (t < 0.46) return mover(fuera, _pCantidad(0), 0.32, 0.42);
    if (t < 0.58) return mover(_pCantidad(0), _pCantidad(1), 0.46, 0.54);
    if (t < 0.76) return mover(_pCantidad(1), _pConfirmar, 0.60, 0.70);
    return mover(_pConfirmar, fuera, 0.78, 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final oc = _ejemplos[vuelta % _ejemplos.length];
        final camara = t < 0.32 ? walkthroughTramo(t, 0.16, 0.20) : 1 - walkthroughTramo(t, 0.32, 0.36);
        final enOc = t >= 0.32;
        final tocaEscanear = t >= 0.12 && t < 0.16;
        final tocaCantidad = _tCargas.any((k) => t >= k && t < k + 0.04);
        final tocaConfirmar = t >= 0.70 && t < 0.74;
        final sello = walkthroughTramo(t, 0.76, 0.86);
        final dedo = _posDedo(t);
        final dedoVisible = !(t >= 0.18 && t < 0.32);

        return Stack(
          children: [
            if (!enOc) _PantallaInicio(tocaEscanear: tocaEscanear),
            if (enOc)
              Opacity(
                opacity: walkthroughTramo(t, 0.32, 0.38),
                child: _PantallaOc(
                  oc: oc,
                  cargas: [for (final k in _tCargas) walkthroughTramo(t, k + 0.02, k + 0.12)],
                  tocaConfirmar: tocaConfirmar,
                  confirmada: sello > 0,
                ),
              ),
            if (camara > 0) Positioned.fill(child: Opacity(opacity: camara, child: _Camara(t: t))),
            if (sello > 0)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.white.withValues(alpha: 0.55 * sello.clamp(0.0, 1.0)),
                  child: Center(
                    child: Transform.scale(
                      scale: Curves.elasticOut.transform(sello),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _fuerte,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(color: _fuerte.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Recepción confirmada',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (dedoVisible)
              Positioned(
                left: dedo.dx - WalkthroughDedo.radio,
                top: dedo.dy - WalkthroughDedo.radio,
                child: WalkthroughDedo(color: _fuerte, tocando: tocaEscanear || tocaCantidad || tocaConfirmar),
              ),
          ],
        );
      },
    );
  }
}

class _PantallaInicio extends StatelessWidget {
  const _PantallaInicio({required this.tocaEscanear});

  final bool tocaEscanear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RECIBIR OC',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
          ),
          const SizedBox(height: 10),
          AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: tocaEscanear ? 0.96 : 1,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: _fuerte, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, size: 24, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Escanear QR de la OC',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
            child: const Row(
              children: [
                Icon(Icons.store_outlined, size: 20, color: AppColors.muted),
                SizedBox(width: 10),
                Text('Elegir proveedor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Camara extends StatelessWidget {
  const _Camara({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final laser = walkthroughTramo(t, 0.18, 0.30);
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.qr_code_2, size: 72, color: Colors.white)),
              ),
              Positioned(
                left: 6,
                right: 6,
                top: 8 + 92 * laser,
                child: Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    boxShadow: [BoxShadow(color: Color(0x88EF4444), blurRadius: 8, spreadRadius: 1)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantallaOc extends StatelessWidget {
  const _PantallaOc({
    required this.oc,
    required this.cargas,
    required this.tocaConfirmar,
    required this.confirmada,
  });

  final _Oc oc;

  /// Progreso 0..1 de la carga de cada ítem (0 = sin cargar).
  final List<double> cargas;
  final bool tocaConfirmar;
  final bool confirmada;

  @override
  Widget build(BuildContext context) {
    final todoCargado = cargas.every((c) => c > 0);

    return Stack(
      children: [
        Positioned(
          left: 14,
          right: 14,
          top: 12,
          child: Row(
            children: [
              Text(oc.codigo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  oc.proveedor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < oc.items.length; i++)
          Positioned(
            left: 12,
            right: 12,
            top: _DemoRecepcion._yItems + i * (_DemoRecepcion._altoItem + _DemoRecepcion._sepItem),
            height: _DemoRecepcion._altoItem,
            child: _FilaItem(item: oc.items[i], carga: cargas[i]),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: 164,
          height: 28,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: tocaConfirmar ? 0.95 : 1,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: todoCargado ? _oscuro : AppColors.borderStrong,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Confirmar recepción',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaItem extends StatelessWidget {
  const _FilaItem({required this.item, required this.carga});

  final _Item item;
  final double carga;

  @override
  Widget build(BuildContext context) {
    final cargado = carga > 0;

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: cargado ? _pastel : AppColors.surface,
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
                Opacity(
                  opacity: cargado ? walkthroughTramo(carga, 0.3, 1) : 1,
                  child: Text(
                    cargado ? item.lote : 'Pedido: ${item.cantidad}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: cargado ? FontWeight.w700 : FontWeight.w400,
                      color: cargado ? _oscuro : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Transform.scale(
            scale: cargado ? Curves.elasticOut.transform(carga) : 1,
            child: Container(
              width: 60,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cargado ? _fuerte : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cargado ? _fuerte : AppColors.borderStrong),
              ),
              child: Text(
                cargado ? item.cantidad : '—',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: cargado ? Colors.white : AppColors.faint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
