import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé el módulo" de Producción — se abre desde el menú ⋮
/// ("¿Cómo funciona?") de `ProduccionHomeScreen`. El contenedor y las pantallas son
/// comunes (`walkthrough_modulo.dart`); acá solo vive el contenido y la demo.
Future<void> abrirAyudaProduccion(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFFFEDD5);
const _fuerte = Color(0xFFEA580C);
const _oscuro = Color(0xFFC2410C);

const _modulo = WalkthroughModulo(
  icono: Icons.precision_manufacturing_outlined,
  nombre: 'Producción',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Registrar lo que se produce en el taller: qué insumos se usaron, cuánto salió, '
      'cuánta merma hubo y cuánto tiempo llevó.',
  pasos: [
    'En "Elegí qué producir" tocá la receta (o buscala por nombre).',
    'Cargá cuánto vas a usar, mirá el estimado y tocá "Empezar a producir": arranca el cronómetro.',
    'Al terminar tocá "Finalizar" y cargá lo que salió de verdad: lo producido y la merma.',
  ],
  consejo: 'Si pausás o cerrás la app, la producción queda arriba en "Retomar": tocala y seguís '
      'donde la dejaste. En ⋮ → "Ver mis producciones" tenés las anteriores.',
  textoFinal: '¡A producir!',
  demo: _DemoProduccion(),
);

typedef _Receta = ({String nombre, String producto, String tiempo});
typedef _Ejemplo = ({List<_Receta> recetas, int elegida, String codigo});

/// Ejemplos de la demo — cada vuelta usa el siguiente juego: 3 recetas y
/// cuál se elige.
const _ejemplos = <_Ejemplo>[
  (
    recetas: [
      (nombre: 'Milanesa de pollo', producto: 'Milanesa de pollo x kg', tiempo: '45min'),
      (nombre: 'Ensalada mixta', producto: 'Bandeja 500 g', tiempo: '20min'),
      (nombre: 'Pan casero', producto: 'Pan x unidad', tiempo: '1h 30min'),
    ],
    elegida: 1,
    codigo: 'PR-0042',
  ),
  (
    recetas: [
      (nombre: 'Fraccionado de arroz', producto: 'Arroz 1 kg', tiempo: '30min'),
      (nombre: 'Carne picada', producto: 'Carne picada x kg', tiempo: '40min'),
      (nombre: 'Kit de limpieza', producto: 'Kit x unidad', tiempo: '15min'),
    ],
    elegida: 0,
    codigo: 'PR-0043',
  ),
];

/// Demo — línea de tiempo de cada vuelta (0 a 1):
/// - 0,06–0,20 el dedo va a una receta; 0,20–0,24 toca.
/// - 0,26–0,38 se abre "Retomar" arriba con la orden "En curso" (entra con
///   rebote) y las recetas bajan; el cronómetro corre.
/// - 0,56 la orden pasa a "Pausada" y el cronómetro se frena.
/// - 0,62–0,72 el dedo va a la orden; 0,72–0,76 toca y vuelve a "En curso".
class _DemoProduccion extends StatelessWidget {
  const _DemoProduccion();

  static const _altoTarjeta = 40.0;
  static const _sepTarjeta = 6.0;
  static const _alturaRetomar = 66.0;
  static const _inicioReloj = 0.30;
  static const _pausa = 0.56;
  static const _reanuda = 0.76;

  static double _yReceta(int i, double desplazo) => 28 + desplazo + i * (_altoTarjeta + _sepTarjeta);

  /// Segundos que muestra el cronómetro: corre en [_inicioReloj, _pausa] y
  /// desde [_reanuda], acelerado para que se note.
  static int _segundos(double t) {
    final corrido = (math.min(t, _pausa) - _inicioReloj).clamp(0.0, 1.0) + math.max(0.0, t - _reanuda);
    return (corrido * 3000).round();
  }

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final ej = _ejemplos[vuelta % _ejemplos.length];
        final abrir = Curves.easeOutCubic.transform(walkthroughTramo(t, 0.26, 0.38));
        final entraOrden = walkthroughTramo(t, 0.28, 0.42);
        final desplazo = _alturaRetomar * abrir;
        final pausada = t >= _pausa && t < _reanuda;
        final saltoEstado = t < _reanuda ? walkthroughTramo(t, _pausa, _pausa + 0.1) : walkthroughTramo(t, _reanuda, _reanuda + 0.1);

        final pReceta = Offset(150, _yReceta(ej.elegida, 0) + _altoTarjeta / 2);
        const pOrden = Offset(150, 26 + _altoTarjeta / 2);
        const fuera = Offset(250, WalkthroughDemo.alto + 30);
        final Offset dedo;
        if (t < 0.24) {
          dedo = Offset.lerp(fuera, pReceta, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.06, 0.20)))!;
        } else if (t < 0.62) {
          dedo = Offset.lerp(pReceta, fuera, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.24, 0.36)))!;
        } else if (t < 0.76) {
          dedo = Offset.lerp(fuera, pOrden, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.62, 0.72)))!;
        } else {
          dedo = Offset.lerp(pOrden, fuera, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.78, 0.90)))!;
        }
        final tocaReceta = t >= 0.20 && t < 0.24;
        final tocaOrden = t >= 0.72 && t < 0.76;

        return Stack(
          children: [
            if (abrir > 0) ...[
              Positioned(
                left: 14,
                top: 10,
                child: Opacity(opacity: abrir, child: const _Rotulo(icono: Icons.history, texto: 'RETOMAR')),
              ),
              Positioned(
                left: 10,
                right: 10,
                top: 26,
                height: _altoTarjeta,
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(entraOrden) * (tocaOrden ? 0.96 : 1),
                  child: _TarjetaOrden(
                    receta: ej.recetas[ej.elegida].nombre,
                    codigo: ej.codigo,
                    pausada: pausada,
                    segundos: _segundos(t),
                    saltoEstado: saltoEstado,
                  ),
                ),
              ),
            ],
            Positioned(
              left: 14,
              top: 10 + desplazo,
              child: const _Rotulo(icono: Icons.receipt_long_outlined, texto: 'ELEGÍ QUÉ PRODUCIR'),
            ),
            for (final (i, r) in ej.recetas.indexed)
              Positioned(
                left: 10,
                right: 10,
                top: _yReceta(i, desplazo),
                height: _altoTarjeta,
                child: Transform.scale(
                  scale: tocaReceta && i == ej.elegida ? 0.96 : 1,
                  child: _TarjetaReceta(receta: r),
                ),
              ),
            Positioned(
              left: dedo.dx - WalkthroughDedo.radio,
              top: dedo.dy - WalkthroughDedo.radio,
              child: WalkthroughDedo(color: _fuerte, tocando: tocaReceta || tocaOrden),
            ),
          ],
        );
      },
    );
  }
}

/// Réplica chica de `SeccionLabel`.
class _Rotulo extends StatelessWidget {
  const _Rotulo({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 10, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(
          texto,
          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Réplica chica de `RecetaTile`:
///   [ícono] **Receta**                    ⏱ tiempo
///           Producto principal
class _TarjetaReceta extends StatelessWidget {
  const _TarjetaReceta({required this.receta});

  final _Receta receta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.receipt_long_outlined, size: 14, color: AppColors.accentDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receta.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                Text(
                  receta.producto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.timer_outlined, size: 10, color: AppColors.faint),
          const SizedBox(width: 2),
          Text(
            receta.tiempo,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Réplica chica de `OrdenEnCursoTile`, con el cronómetro a la derecha:
///   [▶] **Receta**                        12:40
///       PR-0042 · En curso
class _TarjetaOrden extends StatelessWidget {
  const _TarjetaOrden({
    required this.receta,
    required this.codigo,
    required this.pausada,
    required this.segundos,
    required this.saltoEstado,
  });

  final String receta;
  final String codigo;
  final bool pausada;
  final int segundos;

  /// 0→1 tras pausar/reanudar: el ícono da un saltito.
  final double saltoEstado;

  @override
  Widget build(BuildContext context) {
    final color = pausada ? AppColors.waTx : const Color(0xFF16A34A);
    final bg = pausada ? AppColors.waBg : AppColors.okBg;
    final reloj = '${(segundos ~/ 60).toString().padLeft(2, '0')}:${(segundos % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg, width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Transform.scale(
            scale: 1 + 0.25 * math.sin(math.pi * saltoEstado),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Icon(pausada ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 15, color: color),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                Text(
                  '$codigo · ${pausada ? 'Pausada' : 'En curso'}',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
          Text(
            reloj,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
