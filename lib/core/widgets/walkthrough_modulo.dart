import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Presentación "Conocé el módulo" — patrón común a todos los módulos de la
/// app. Se abre SOLO desde un (?) en el AppBar del módulo (sin "NUEVO" ni
/// registro de vistas).
///
/// Tres pantallas, una idea por pantalla: 1) para qué sirve, 2) cómo
/// funciona (demo animada + 3 pasos), 3) un consejo. Todo usa el color del
/// módulo en el menú (`home_screen.dart`): fondo, números de los pasos y
/// botón. Cada módulo define solo su [WalkthroughModulo] y su demo (armada
/// con [WalkthroughDemo] + [WalkthroughDedo]) — ver
/// `picking_ayuda_screen.dart` y `traslados_ayuda.dart`.
class WalkthroughModulo {
  const WalkthroughModulo({
    required this.icono,
    required this.nombre,
    required this.pastel,
    required this.fuerte,
    required this.oscuro,
    required this.proposito,
    required this.pasos,
    required this.consejo,
    required this.textoFinal,
    required this.demo,
  });

  final IconData icono;
  final String nombre;

  /// Fondo del degradado y cajitas suaves.
  final Color pastel;

  /// Color del módulo en el menú: ícono, ondas, números, puntitos.
  final Color fuerte;

  /// Variante oscura para texto y el botón (blanco encima se lee bien).
  final Color oscuro;

  /// Para qué sirve, en 1–2 oraciones.
  final String proposito;

  /// Exactamente 3 pasos cortos.
  final List<String> pasos;
  final String consejo;

  /// Texto del botón en la última pantalla (ej. "¡A pickear!").
  final String textoFinal;

  /// Demo de la pantalla "Cómo funciona", armada con [WalkthroughDemo].
  final Widget demo;
}

Future<void> abrirWalkthrough(BuildContext context, WalkthroughModulo modulo) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => _WalkthroughScreen(modulo: modulo),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

/// Progreso 0..1 de `t` dentro del tramo [desde, hasta] — para armar la
/// línea de tiempo de las demos.
double walkthroughTramo(double t, double desde, double hasta) =>
    ((t - desde) / (hasta - desde)).clamp(0.0, 1.0);

// ---------------------------------------------------------------------------
// Contenedor
// ---------------------------------------------------------------------------

class _WalkthroughScreen extends StatefulWidget {
  const _WalkthroughScreen({required this.modulo});

  final WalkthroughModulo modulo;

  @override
  State<_WalkthroughScreen> createState() => _WalkthroughScreenState();
}

class _WalkthroughScreenState extends State<_WalkthroughScreen> {
  final _controller = PageController();
  int _pagina = 0;
  static const _total = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_pagina == _total - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.modulo;
    final ultima = _pagina == _total - 1;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [m.pastel, AppColors.pageBg],
            stops: const [0, 0.65],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: m.oscuro),
                    child: const Text('Saltar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (p) => setState(() => _pagina = p),
                  children: [
                    _PantallaProposito(modulo: m, activa: _pagina == 0),
                    _PantallaComoFunciona(modulo: m, activa: _pagina == 1),
                    _PantallaConsejo(modulo: m, activa: _pagina == 2),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    for (var i = 0; i < _total; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _pagina ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _pagina ? m.fuerte : AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _siguiente,
                      style: FilledButton.styleFrom(
                        backgroundColor: m.oscuro,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Text(
                        ultima ? m.textoFinal : 'Siguiente',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animación de entrada y cascada
// ---------------------------------------------------------------------------

/// Base de cada pantalla: arranca la animación de entrada (1,4 s) la
/// primera vez que la pantalla queda activa en el `PageView`.
abstract class _PantallaState<T extends StatefulWidget> extends State<T> with TickerProviderStateMixin {
  late final entrada = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  bool get activa;

  @override
  void initState() {
    super.initState();
    if (activa) entrada.forward();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (activa && entrada.isDismissed) entrada.forward();
  }

  @override
  void dispose() {
    entrada.dispose();
    super.dispose();
  }
}

/// Elemento que entra en cascada: sube 24 px con fundido, demorado según
/// su [orden].
class _Cascada extends StatelessWidget {
  const _Cascada({required this.entrada, required this.orden, required this.child});

  final Animation<double> entrada;
  final int orden;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inicio = math.min(0.25 + orden * 0.1, 0.6);
    final anim = CurvedAnimation(
      parent: entrada,
      curve: Interval(inicio, math.min(inicio + 0.4, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - anim.value)), child: child),
      ),
      child: child,
    );
  }
}

/// Lo que "llega" entra con rebote.
Animation<double> _rebote(AnimationController entrada) =>
    CurvedAnimation(parent: entrada, curve: const Interval(0, 0.6, curve: Curves.elasticOut));

// ---------------------------------------------------------------------------
// Pantalla 1 · Para qué sirve
// ---------------------------------------------------------------------------

class _PantallaProposito extends StatefulWidget {
  const _PantallaProposito({required this.modulo, required this.activa});

  final WalkthroughModulo modulo;
  final bool activa;

  @override
  State<_PantallaProposito> createState() => _PantallaPropositoState();
}

class _PantallaPropositoState extends _PantallaState<_PantallaProposito> {
  late final _loop = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  bool get activa => widget.activa;

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.modulo;
    final rebote = _rebote(entrada);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: 240,
            height: 240,
            child: AnimatedBuilder(
              animation: Listenable.merge([_loop, rebote]),
              builder: (context, _) {
                final t = _loop.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final fase in const [0.0, 0.5]) _Onda(t: (t + fase) % 1, color: m.fuerte),
                    for (var i = 0; i < 5; i++)
                      Transform.translate(
                        offset: Offset.fromDirection(2 * math.pi * (t + i / 5), 100),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: m.fuerte.withValues(alpha: 0.35 + 0.13 * i),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(0, 6 * math.sin(2 * math.pi * t)),
                      child: Transform.scale(
                        scale: rebote.value,
                        child: Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            color: m.fuerte,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: m.fuerte.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Icon(m.icono, size: 54, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 28),
        _Cascada(
          entrada: entrada,
          orden: 0,
          child: Text(
            'CONOCÉ EL MÓDULO',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: m.oscuro, letterSpacing: 1.4),
          ),
        ),
        const SizedBox(height: 8),
        _Cascada(
          entrada: entrada,
          orden: 1,
          child: Text(
            m.nombre,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 12),
        _Cascada(
          entrada: entrada,
          orden: 2,
          child: Text(
            m.proposito,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.45, color: AppColors.sub),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Onda extends StatelessWidget {
  const _Onda({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116 + 110 * t,
      height: 116 + 110 * t,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.22 * (1 - t)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pantalla 2 · Cómo funciona
// ---------------------------------------------------------------------------

class _PantallaComoFunciona extends StatefulWidget {
  const _PantallaComoFunciona({required this.modulo, required this.activa});

  final WalkthroughModulo modulo;
  final bool activa;

  @override
  State<_PantallaComoFunciona> createState() => _PantallaComoFuncionaState();
}

class _PantallaComoFuncionaState extends _PantallaState<_PantallaComoFunciona> {
  @override
  bool get activa => widget.activa;

  @override
  Widget build(BuildContext context) {
    final m = widget.modulo;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        const SizedBox(height: 8),
        _Cascada(
          entrada: entrada,
          orden: 0,
          child: const Text(
            'Cómo funciona',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 18),
        _Cascada(entrada: entrada, orden: 1, child: Center(child: m.demo)),
        const SizedBox(height: 22),
        for (var i = 0; i < m.pasos.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _Cascada(
              entrada: entrada,
              orden: 2 + i,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: m.fuerte, shape: BoxShape.circle),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(m.pasos[i], style: const TextStyle(fontSize: 15, height: 1.35, color: AppColors.sub)),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pantalla 3 · Consejo
// ---------------------------------------------------------------------------

class _PantallaConsejo extends StatefulWidget {
  const _PantallaConsejo({required this.modulo, required this.activa});

  final WalkthroughModulo modulo;
  final bool activa;

  @override
  State<_PantallaConsejo> createState() => _PantallaConsejoState();
}

class _PantallaConsejoState extends _PantallaState<_PantallaConsejo> {
  late final _vaiven = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  bool get activa => widget.activa;

  @override
  void dispose() {
    _vaiven.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.modulo;
    final rebote = _rebote(entrada);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        const SizedBox(height: 40),
        Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_vaiven, rebote]),
            builder: (context, _) => Transform.scale(
              scale: rebote.value,
              child: Transform.rotate(
                angle: 0.14 * math.sin(2 * math.pi * _vaiven.value),
                alignment: Alignment.topCenter,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: m.fuerte.withValues(alpha: 0.25), blurRadius: 28, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.lightbulb, size: 58, color: Color(0xFFF59E0B)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        _Cascada(
          entrada: entrada,
          orden: 0,
          child: Text(
            'UN CONSEJO',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: m.oscuro, letterSpacing: 1.4),
          ),
        ),
        const SizedBox(height: 12),
        _Cascada(
          entrada: entrada,
          orden: 1,
          child: Text(
            m.consejo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
        ),
        const SizedBox(height: 28),
        _Cascada(
          entrada: entrada,
          orden: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: m.pastel, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.help_outline, size: 18, color: m.oscuro),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Podés volver a ver esto con el botón "?"',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: m.oscuro),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas para armar las demos
// ---------------------------------------------------------------------------

/// "Pantallita" de 270×210 (fondo, borde y sombra) que corre [builder] con
/// un `t` de 0 a 1 cada 4,2 s; `vuelta` sube en cada repetición para que la
/// demo use otro ejemplo. En 0,92–1 todo se desvanece antes de empezar de
/// nuevo. Los textos no escalan con el tamaño de letra del sistema (es un
/// dibujo a escala).
class WalkthroughDemo extends StatefulWidget {
  const WalkthroughDemo({super.key, required this.builder});

  static const ancho = 270.0;
  static const alto = 210.0;

  final Widget Function(BuildContext context, double t, int vuelta) builder;

  @override
  State<WalkthroughDemo> createState() => _WalkthroughDemoState();
}

class _WalkthroughDemoState extends State<WalkthroughDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _vuelta++);
        _anim.forward(from: 0);
      }
    })
    ..forward();
  int _vuelta = 0;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: WalkthroughDemo.ancho,
        height: WalkthroughDemo.alto,
        decoration: BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.ink.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => Opacity(
              opacity: 1 - walkthroughTramo(_anim.value, 0.92, 1),
              child: widget.builder(context, _anim.value, _vuelta),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dedo de las demos: círculo blanco de 28 px que se achica un 25% al
/// tocar. Se posiciona con `Positioned(left: x - WalkthroughDedo.radio, ...)`.
class WalkthroughDedo extends StatelessWidget {
  const WalkthroughDedo({super.key, required this.color, this.tocando = false});

  static const radio = 14.0;

  final Color color;
  final bool tocando;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: tocando ? 0.75 : 1,
      child: Container(
        width: radio * 2,
        height: radio * 2,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
          boxShadow: [
            BoxShadow(color: AppColors.ink.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
      ),
    );
  }
}
