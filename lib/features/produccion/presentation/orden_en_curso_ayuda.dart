import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé la pantalla" de Producción en curso — se abre desde
/// el (?) del AppBar de `OrdenEnCursoScreen`. El contenedor y las pantallas
/// son comunes (`walkthrough_modulo.dart`); acá solo vive el contenido y la
/// demo. Sigue con el mismo ejemplo que `nueva_orden_ayuda.dart` ("Fetear
/// Pieza de Jamón", 6 kg) para que se lea como la continuación.
Future<void> abrirAyudaOrdenEnCurso(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFFFEDD5);
const _fuerte = Color(0xFFEA580C);
const _oscuro = Color(0xFFC2410C);

const _modulo = WalkthroughModulo(
  icono: Icons.timer_outlined,
  nombre: 'Producción en curso',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Mientras producís, esta pantalla lleva el tiempo. El aro se va llenando a medida que te '
      'acercás al tiempo estimado.',
  pasos: [
    'El cronómetro corre solo, aunque salgas de la pantalla o cierres la app.',
    'Si tenés que frenar (un descanso, falta algo), tocá "Pausar". Para seguir, "Reanudar".',
    'Cuando terminás, tocá "Finalizar" y cargá lo que usaste, lo que salió y la merma.',
  ],
  consejo: 'Volver atrás NO pausa: si vas a dejar de producir, tocá "Pausar". Si la arrancaste por error, '
      '"Anular producción" (abajo de todo) devuelve los insumos.',
  textoFinal: '¡Entendido!',
  demo: _DemoOrdenEnCurso(),
);

const _codigo = 'PR-0042';
const _insumo = 'Pieza de jamón cocido';
const _resultado = 'Feteado de jamón cocido';
const _merma = 'Puntas de jamón';

/// Demo — línea de tiempo de cada vuelta (0 a 1):
/// - 0–0,32 el cronómetro corre y el aro se llena.
/// - 0,18–0,28 el dedo va a "Pausar"; 0,30–0,34 toca: el aro y el texto
///   pasan a ámbar ("Pausada"), el reloj se frena y el botón dice
///   "Reanudar".
/// - 0,48–0,52 toca "Reanudar" y vuelve a correr.
/// - 0,58–0,68 el dedo va a "Finalizar"; 0,68–0,72 toca.
/// - 0,74–0,82 entra desde la derecha "Finalizar producción" con lo que se
///   usó, lo que salió y la merma.
class _DemoOrdenEnCurso extends StatelessWidget {
  const _DemoOrdenEnCurso();

  static const _baseSegundos = 1840;
  static const _estimadoSegundos = 7200;
  static const _yBotones = 132.0;
  static const _altoBoton = 26.0;
  static const _pPausar = Offset(74, _yBotones + _altoBoton / 2);
  static const _pFinalizar = Offset(196, _yBotones + _altoBoton / 2);

  /// Reloj acelerado: corre hasta la pausa y desde que se reanuda.
  static int _segundos(double t) {
    final corrido = math.min(t, 0.32) + math.max(0.0, math.min(t, 0.72) - 0.50);
    return _baseSegundos + (corrido * 900).round();
  }

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      // Igual de lenta que la de Nueva producción, para seguir cada toque.
      duracion: const Duration(seconds: 9),
      builder: (context, t, _) {
        final pausada = t >= 0.32 && t < 0.50;
        final segundos = _segundos(t);
        final saltoEstado = t < 0.50 ? walkthroughTramo(t, 0.32, 0.42) : walkthroughTramo(t, 0.50, 0.60);
        final finalizar = Curves.easeOutCubic.transform(walkthroughTramo(t, 0.74, 0.82));

        const fuera = Offset(250, WalkthroughDemo.alto + 30);
        final Offset dedo;
        if (t < 0.56) {
          dedo = Offset.lerp(fuera, _pPausar, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.18, 0.28)))!;
        } else {
          dedo = Offset.lerp(_pPausar, _pFinalizar, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.58, 0.68)))!;
        }
        final tocaPausa = (t >= 0.30 && t < 0.34) || (t >= 0.48 && t < 0.52);
        final tocaFinalizar = t >= 0.68 && t < 0.72;

        return Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              top: 8,
              child: Text(
                _codigo,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.muted),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 24,
              child: Center(
                child: _Aro(
                  segundos: segundos,
                  progreso: segundos / _estimadoSegundos,
                  pausada: pausada,
                  saltoEstado: saltoEstado,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: _yBotones,
              height: _altoBoton,
              child: Row(
                children: [
                  Expanded(
                    child: Transform.scale(
                      scale: tocaPausa ? 0.94 : 1,
                      child: _Boton(
                        icono: pausada ? Icons.play_arrow : Icons.pause,
                        texto: pausada ? 'Reanudar' : 'Pausar',
                        relleno: false,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Transform.scale(
                      scale: tocaFinalizar ? 0.94 : 1,
                      child: const _Boton(icono: Icons.flag_outlined, texto: 'Finalizar', relleno: true),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 14,
              top: 170,
              child: Text(
                'CONSUMO PLANIFICADO',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.muted),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              top: 184,
              height: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  children: [
                    Expanded(child: Text(_insumo, style: TextStyle(fontSize: 9.5, color: AppColors.text))),
                    Text('6.00 kg', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.sub)),
                  ],
                ),
              ),
            ),
            if (finalizar > 0)
              Positioned(
                left: WalkthroughDemo.ancho * (1 - finalizar),
                top: 0,
                width: WalkthroughDemo.ancho,
                height: WalkthroughDemo.alto,
                child: const _Finalizar(),
              ),
            Positioned(
              left: dedo.dx - WalkthroughDedo.radio,
              top: dedo.dy - WalkthroughDedo.radio,
              child: Opacity(
                opacity: 1 - walkthroughTramo(t, 0.72, 0.76),
                child: WalkthroughDedo(color: _fuerte, tocando: tocaPausa || tocaFinalizar),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Réplica chica del aro con el cronómetro: azul produciendo, ámbar en
/// pausa.
class _Aro extends StatelessWidget {
  const _Aro({required this.segundos, required this.progreso, required this.pausada, required this.saltoEstado});

  final int segundos;
  final double progreso;
  final bool pausada;

  /// 0→1 tras pausar/reanudar: el texto de estado da un saltito.
  final double saltoEstado;

  @override
  Widget build(BuildContext context) {
    final color = pausada ? AppColors.waTx : AppColors.accent;
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');

    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: CircularProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              strokeWidth: 5,
              backgroundColor: AppColors.soft,
              color: color,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$m:$s',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Transform.scale(
                scale: 1 + 0.25 * math.sin(math.pi * saltoEstado),
                child: Text(
                  pausada ? 'Pausada' : 'Produciendo...',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({required this.icono, required this.texto, required this.relleno});

  final IconData icono;
  final String texto;
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final fg = relleno ? Colors.white : AppColors.accent;
    return Container(
      decoration: BoxDecoration(
        color: relleno ? AppColors.accent : null,
        borderRadius: BorderRadius.circular(9),
        border: relleno ? null : Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(texto, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Réplica chica de `FinalizarOrdenScreen`: a donde lleva "Finalizar".
class _Finalizar extends StatelessWidget {
  const _Finalizar();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Finalizar producción',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
            ),
            const SizedBox(height: 8),
            const _SeccionCantidad(titulo: '¿CUÁNTO USASTE?', icono: Icons.inventory_2_outlined, nombre: _insumo, valor: '6.00'),
            const _SeccionCantidad(titulo: '¿CUÁNTO PRODUJISTE?', icono: Icons.emoji_events_outlined, nombre: _resultado, valor: '5.58'),
            const _SeccionCantidad(
              titulo: '¿CUÁNTA MERMA HUBO?',
              icono: Icons.local_fire_department_outlined,
              nombre: _merma,
              valor: '0.40',
            ),
            const SizedBox(height: 2),
            Container(
              height: 26,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(9)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 11, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Finalizar producción',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white),
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

class _SeccionCantidad extends StatelessWidget {
  const _SeccionCantidad({required this.titulo, required this.icono, required this.nombre, required this.valor});

  final String titulo;
  final IconData icono;
  final String nombre;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 3),
            child: Row(
              children: [
                Icon(icono, size: 9, color: AppColors.muted),
                const SizedBox(width: 3),
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.text),
                  ),
                ),
                Text(valor, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.accentDark)),
                const SizedBox(width: 3),
                const Text('kg', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
