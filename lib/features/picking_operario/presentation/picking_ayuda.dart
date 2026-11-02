import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé el módulo" de Picking — se abre desde el (?) del
/// AppBar de `PickingHomeScreen`. El contenedor y las pantallas son comunes
/// (`walkthrough_modulo.dart`); acá solo vive el contenido y la demo.
///
/// Es estático: no lee config del almacén, así que no menciona reglas que
/// dependen de Ajustes -> Operaciones -> Picking.
Future<void> abrirAyudaPicking(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFE0F2FE);
const _fuerte = Color(0xFF0EA5E9);
const _oscuro = Color(0xFF0369A1);

const _modulo = WalkthroughModulo(
  icono: Icons.shopping_basket_outlined,
  nombre: 'Picking',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito:
      'Juntar en el depósito los productos de cada pedido. La app te dice qué buscar, dónde está y cuánto llevar.',
  pasos: [
    'Elegí un pedido y la zona donde vas a pickear.',
    'Escaneá el cajón y después cada producto que ponés adentro.',
    'Confirmá la cantidad y, al terminar, tocá "Terminar picking".',
  ],
  consejo: 'Si encontrás menos de lo pedido, cargá lo que hay: el resto queda como tarea pendiente. '
      'Y si te equivocaste, en la tarea completada tocá "Devolver".',
  textoFinal: '¡A pickear!',
  demo: _DemoPicking(),
);

typedef _Tarea = ({String producto, String ubicacion, String cantidad});

/// Ejemplos de la demo — cada vuelta usa el siguiente juego.
const _ejemplos = <List<_Tarea>>[
  [
    (producto: 'Leche entera 1L', ubicacion: 'A-03-02', cantidad: '12 un'),
    (producto: 'Arroz largo fino 1kg', ubicacion: 'A-05-01', cantidad: '6 un'),
    (producto: 'Aceite de girasol 900ml', ubicacion: 'A-01-04', cantidad: '4 un'),
  ],
  [
    (producto: 'Yogur frutilla 200g', ubicacion: 'F-02-01', cantidad: '24 un'),
    (producto: 'Queso paraguay', ubicacion: 'F-04-03', cantidad: '2,35 kg'),
    (producto: 'Manteca 200g', ubicacion: 'F-01-02', cantidad: '10 un'),
  ],
  [
    (producto: 'Detergente 750ml', ubicacion: 'L-01-01', cantidad: '8 un'),
    (producto: 'Papel higiénico x4', ubicacion: 'L-03-02', cantidad: '15 un'),
    (producto: 'Lavandina 1L', ubicacion: 'L-02-04', cantidad: '6 un'),
  ],
];

/// Demo "lista": el dedo toca cada tarea en 0,18 / 0,42 / 0,66 de la
/// vuelta, el círculo pasa a tilde con rebote, aparece "Pickeado" y sube el
/// contador.
class _DemoPicking extends StatelessWidget {
  const _DemoPicking();

  static const _toques = [0.18, 0.42, 0.66];
  static const _yFilas = 50.0;
  static const _altoFila = 46.0;
  static const _sepFila = 6.0;

  static double _centroFila(int i) => _yFilas + i * (_altoFila + _sepFila) + _altoFila / 2;

  /// Posición del dedo: entra desde abajo, para en cada fila y sale.
  static Offset _posDedo(double t) {
    const x = 205.0;
    const fuera = Offset(x + 30, WalkthroughDemo.alto + 30);
    final puntos = [for (var i = 0; i < 3; i++) Offset(x, _centroFila(i))];
    Offset mover(Offset a, Offset b, double desde, double hasta) =>
        Offset.lerp(a, b, Curves.easeInOutCubic.transform(walkthroughTramo(t, desde, hasta)))!;

    if (t < 0.15) return mover(fuera, puntos[0], 0.0, 0.15);
    if (t < 0.39) return mover(puntos[0], puntos[1], 0.24, 0.39);
    if (t < 0.63) return mover(puntos[1], puntos[2], 0.48, 0.63);
    return mover(puntos[2], fuera, 0.74, 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final tareas = _ejemplos[vuelta % _ejemplos.length];
        final hechas = _toques.where((k) => t >= k + 0.03).length;
        final ultimoToque = hechas > 0 ? _toques[hechas - 1] + 0.03 : -1.0;
        final saltoContador = hechas > 0 ? walkthroughTramo(t, ultimoToque, ultimoToque + 0.12) : 1.0;
        final dedo = _posDedo(t);
        final tocando = _toques.any((k) => t >= k && t < k + 0.04);

        return Stack(
          children: [
            Positioned(
              left: 14,
              right: 14,
              top: 12,
              child: Row(
                children: [
                  const Text(
                    'PENDIENTES',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
                  ),
                  const Spacer(),
                  Transform.scale(
                    scale: 1 + 0.25 * math.sin(math.pi * saltoContador),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: hechas == 3 ? _fuerte : _pastel,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$hechas/3',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: hechas == 3 ? Colors.white : _oscuro,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < 3; i++)
              Positioned(
                left: 12,
                right: 12,
                top: _yFilas + i * (_altoFila + _sepFila),
                height: _altoFila,
                child: _FilaTarea(
                  tarea: tareas[i],
                  check: walkthroughTramo(t, _toques[i] + 0.03, _toques[i] + 0.15),
                  presionada: t >= _toques[i] && t < _toques[i] + 0.04,
                ),
              ),
            Positioned(
              left: dedo.dx - WalkthroughDedo.radio,
              top: dedo.dy - WalkthroughDedo.radio,
              child: WalkthroughDedo(color: _fuerte, tocando: tocando),
            ),
          ],
        );
      },
    );
  }
}

class _FilaTarea extends StatelessWidget {
  const _FilaTarea({required this.tarea, required this.check, required this.presionada});

  final _Tarea tarea;

  /// 0 = pendiente, 0→1 = el círculo pasa a tilde (con rebote).
  final double check;
  final bool presionada;

  @override
  Widget build(BuildContext context) {
    final hecha = check > 0;
    final escala = hecha ? Curves.elasticOut.transform(check) : 1.0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: presionada ? 0.97 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: hecha ? _pastel : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: escala,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hecha ? _fuerte : Colors.transparent,
                  border: Border.all(color: hecha ? _fuerte : AppColors.borderStrong, width: 2),
                ),
                child: hecha ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tarea.producto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hecha ? 'Pickeado: ${tarea.cantidad}' : '${tarea.ubicacion} · ${tarea.cantidad}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: hecha ? FontWeight.w700 : FontWeight.w400,
                      color: hecha ? _oscuro : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
