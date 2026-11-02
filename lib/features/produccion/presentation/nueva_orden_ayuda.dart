import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé la pantalla" de Nueva producción — se abre desde el
/// menú ⋮ ("¿Cómo funciona?") de `NuevaOrdenScreen`. El contenedor y las
/// pantallas son comunes (`walkthrough_modulo.dart`); acá solo vive el
/// contenido y la demo. Usa el naranja de Producción del menú, igual que
/// `produccion_ayuda.dart`.
Future<void> abrirAyudaNuevaOrden(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFFFEDD5);
const _fuerte = Color(0xFFEA580C);
const _oscuro = Color(0xFFC2410C);

const _modulo = WalkthroughModulo(
  icono: Icons.precision_manufacturing_outlined,
  nombre: 'Nueva producción',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Antes de arrancar, ver qué pide la receta y decir cuánto vas a usar del insumo principal. '
      'Con eso el sistema calcula todo lo demás.',
  pasos: [
    'En "Vas a necesitar" la ⭐ marca el insumo principal: las cantidades son por cada unidad de ese insumo.',
    'Escribí cuánto vas a usar de ese insumo: abajo aparece el estimado de tiempo, lo que sale y la merma.',
    'Si está bien, tocá "Empezar a producir": se descuentan los insumos y arranca el cronómetro.',
  ],
  consejo: 'Revisá bien la cantidad: de ella sale todo lo demás. Si el chip de operarios está en naranja, '
      'la receta necesita más de una persona: conseguí ayuda antes de arrancar.',
  textoFinal: '¡A producir!',
  demo: _DemoNuevaOrden(),
);

typedef _Insumo = ({String nombre, String cantidad});

/// Receta de la demo: "Fetear Pieza de Jamón", con las proporciones de la
/// receta real (3 kg de pieza → 2,79 kg feteado + 0,20 kg de merma, 1 h).
/// El primer insumo es el de referencia (⭐).
const _receta = 'Fetear Pieza de Jamón';
const _insumos = <_Insumo>[
  (nombre: 'Pieza de jamón cocido', cantidad: '3 kg'),
  (nombre: 'Bolsa al vacío', cantidad: '3 un'),
  (nombre: 'Etiqueta', cantidad: '3 un'),
];
const _unidad = 'kg';
const _tipeo = '6';
const _tiempo = '2h 0min';
const _operarios = 1;
const _resultado = 'Feteado de jamón cocido';
const _cantidadResultado = '5.58 kg';
const _merma = 'Puntas de jamón';
const _cantidadMerma = '0.40 kg';
const _codigo = 'PR-0042';

/// Demo — línea de tiempo de cada vuelta (0 a 1):
/// Arriba de todo, el cartel de la receta ("Fetear Pieza de Jamón").
/// - 0,04–0,14 la ⭐ del insumo principal da un saltito.
/// - 0,10–0,22 el dedo va al campo de cantidad; 0,22–0,25 toca (foco).
/// - 0,26–0,40 se tipea la cantidad, un dígito por vez.
/// - 0,42–0,48 "Calculando estimado..."; 0,48–0,60 entra el estimado con
///   rebote y la pantalla sube para mostrar el botón, que se habilita.
/// - 0,62–0,72 el dedo va a "Empezar a producir"; 0,72–0,76 toca.
/// - 0,78–0,86 entra desde la derecha "Producción en curso" con el
///   cronómetro corriendo.
class _DemoNuevaOrden extends StatelessWidget {
  const _DemoNuevaOrden();

  static const _yInsumos = 52.0;
  static const _altoFila = 17.0;
  static const _yCantidad = 129.0;
  static const _altoCantidad = 58.0;
  static const _yEstimado = 195.0;
  static const _altoEstimado = 66.0;
  static const _altoBoton = 28.0;
  static const _scroll = 102.0;

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      // Más lenta que el resto (4,2 s): son muchos pasos seguidos y hace
      // falta tiempo para leer cada uno.
      duracion: const Duration(seconds: 10),
      builder: (context, t, _) {
        final saltoEstrella = walkthroughTramo(t, 0.04, 0.14);
        final foco = t >= 0.22;
        final digitos = t < 0.26 ? 0 : (walkthroughTramo(t, 0.26, 0.40) * _tipeo.length).ceil();
        final calculando = t >= 0.42 && t < 0.48;
        final entraEstimado = walkthroughTramo(t, 0.48, 0.60);
        final abrirEstimado = Curves.easeOutCubic.transform(entraEstimado);
        final scroll = _scroll * Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.50, 0.62));
        final yBoton = _yEstimado + (_altoEstimado + 8) * abrirEstimado;
        final habilitado = t >= 0.56;
        final taller = Curves.easeOutCubic.transform(walkthroughTramo(t, 0.78, 0.86));

        const pCantidad = Offset(110, _yCantidad + 38);
        final pBoton = Offset(150, _yEstimado + _altoEstimado + 8 + _altoBoton / 2 - _scroll);
        const fuera = Offset(250, WalkthroughDemo.alto + 30);
        final Offset dedo;
        if (t < 0.25) {
          dedo = Offset.lerp(fuera, pCantidad, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.10, 0.22)))!;
        } else if (t < 0.62) {
          dedo = Offset.lerp(pCantidad, fuera, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.26, 0.38)))!;
        } else {
          dedo = Offset.lerp(fuera, pBoton, Curves.easeInOutCubic.transform(walkthroughTramo(t, 0.62, 0.72)))!;
        }
        final tocaCantidad = t >= 0.22 && t < 0.25;
        final tocaBoton = t >= 0.72 && t < 0.76;

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: -scroll,
              height: 330,
              child: Stack(
                children: [
                  const Positioned(left: 10, right: 10, top: 8, height: 34, child: _TarjetaReceta()),
                  const Positioned(
                    left: 14,
                    top: _yInsumos - 14,
                    child: _Rotulo(icono: Icons.inventory_2_outlined, texto: 'VAS A NECESITAR'),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    top: _yInsumos,
                    child: _TarjetaInsumos(insumos: _insumos, saltoEstrella: saltoEstrella),
                  ),
                  const Positioned(
                    left: 14,
                    top: _yCantidad - 14,
                    child: _Rotulo(icono: Icons.edit_note_outlined, texto: 'CANTIDAD A PRODUCIR'),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    top: _yCantidad,
                    height: _altoCantidad,
                    child: Transform.scale(
                      scale: tocaCantidad ? 0.97 : 1,
                      child: _TarjetaCantidad(
                        referencia: _insumos.first.nombre,
                        unidad: _unidad,
                        valor: _tipeo.substring(0, digitos),
                        foco: foco,
                      ),
                    ),
                  ),
                  if (calculando)
                    const Positioned(
                      left: 14,
                      top: _yEstimado + 4,
                      child: _Calculando(),
                    ),
                  if (entraEstimado > 0)
                    Positioned(
                      left: 10,
                      right: 10,
                      top: _yEstimado,
                      height: _altoEstimado,
                      child: Transform.scale(
                        scale: Curves.elasticOut.transform(entraEstimado),
                        child: const _TarjetaEstimado(),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    right: 10,
                    top: yBoton,
                    height: _altoBoton,
                    child: Transform.scale(
                      scale: tocaBoton ? 0.95 : 1,
                      child: _BotonEmpezar(habilitado: habilitado),
                    ),
                  ),
                ],
              ),
            ),
            if (taller > 0)
              Positioned(
                left: WalkthroughDemo.ancho * (1 - taller),
                top: 0,
                width: WalkthroughDemo.ancho,
                height: WalkthroughDemo.alto,
                child: _Taller(codigo: _codigo, segundos: (walkthroughTramo(t, 0.82, 0.92) * 4).floor()),
              ),
            Positioned(
              left: dedo.dx - WalkthroughDedo.radio,
              top: dedo.dy - WalkthroughDedo.radio,
              child: Opacity(
                opacity: 1 - walkthroughTramo(t, 0.76, 0.80),
                child: WalkthroughDedo(color: _fuerte, tocando: tocaCantidad || tocaBoton),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Réplica chica del cartel de la receta (arriba de todo en la pantalla).
class _TarjetaReceta extends StatelessWidget {
  const _TarjetaReceta();

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
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.receipt_long_outlined, size: 12, color: AppColors.accentDark),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              _receta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
          ),
          const Icon(Icons.timer_outlined, size: 10, color: AppColors.faint),
          const SizedBox(width: 2),
          const Text('1h 0min', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.muted)),
        ],
      ),
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

/// Réplica chica de la tarjeta "Vas a necesitar" (`_FilaInsumo`).
class _TarjetaInsumos extends StatelessWidget {
  const _TarjetaInsumos({required this.insumos, required this.saltoEstrella});

  final List<_Insumo> insumos;

  /// 0→1: la ⭐ del insumo principal da un saltito.
  final double saltoEstrella;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final (i, insumo) in insumos.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            SizedBox(
              height: _DemoNuevaOrden._altoFila,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    if (i == 0)
                      Transform.scale(
                        scale: 1 + 0.6 * math.sin(math.pi * saltoEstrella),
                        child: const Icon(Icons.star, size: 10, color: AppColors.accent),
                      )
                    else
                      const SizedBox(width: 10, child: Icon(Icons.circle, size: 4, color: AppColors.faint)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        insumo.nombre,
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ),
                    Text(
                      insumo.cantidad,
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.sub),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Réplica chica de la tarjeta "Cantidad a producir" (borde de acento).
class _TarjetaCantidad extends StatelessWidget {
  const _TarjetaCantidad({required this.referencia, required this.unidad, required this.valor, required this.foco});

  final String referencia;
  final String unidad;
  final String valor;
  final bool foco;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Cuánto vas a usar de $referencia?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: foco ? AppColors.accent : AppColors.border, width: foco ? 1.6 : 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  valor.isEmpty ? '0' : valor,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: valor.isEmpty ? AppColors.faint : AppColors.accentDark,
                  ),
                ),
                if (foco) Container(width: 1.4, height: 16, margin: const EdgeInsets.only(left: 1), color: AppColors.accent),
                const Spacer(),
                Text(
                  unidad,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Calculando extends StatelessWidget {
  const _Calculando();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
        SizedBox(width: 6),
        Text('Calculando estimado...', style: TextStyle(fontSize: 9.5, color: AppColors.muted)),
      ],
    );
  }
}

/// Réplica chica de `_PreviewCartel`: tiempo y operarios, lo que sale y la
/// merma esperada.
class _TarjetaEstimado extends StatelessWidget {
  const _TarjetaEstimado();

  @override
  Widget build(BuildContext context) {
    const etiqueta = TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: AppColors.muted);
    const valor = TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.text);

    Widget dato(String e, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(e, maxLines: 1, overflow: TextOverflow.ellipsis, style: etiqueta),
        Text(v, style: valor),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A2563EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, size: 10, color: AppColors.accentDark),
              SizedBox(width: 4),
              Text('El sistema estima', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.accentDark)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: dato('Tiempo', _tiempo)),
              Expanded(child: dato('Operarios', '$_operarios')),
              Expanded(flex: 2, child: dato(_resultado, _cantidadResultado)),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(Icons.local_fire_department_outlined, size: 9, color: AppColors.waTx),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  'Merma · $_merma',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.5, color: AppColors.sub),
                ),
              ),
              Text(
                _cantidadMerma,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.waTx),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Réplica chica de "Empezar a producir": gris hasta que hay estimado.
class _BotonEmpezar extends StatelessWidget {
  const _BotonEmpezar({required this.habilitado});

  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final fg = habilitado ? Colors.white : AppColors.faint;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: habilitado ? AppColors.accent : AppColors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_arrow, size: 13, color: fg),
          const SizedBox(width: 4),
          Text('Empezar a producir', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// Réplica chica de `OrdenEnCursoScreen`: a donde lleva "Empezar a
/// producir".
class _Taller extends StatelessWidget {
  const _Taller({required this.codigo, required this.segundos});

  final String codigo;
  final int segundos;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Text(codigo, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.muted)),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: 0.04 + segundos * 0.02,
                    strokeWidth: 5,
                    backgroundColor: AppColors.soft,
                    color: AppColors.accent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '00:0$segundos',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    const Text(
                      'Produciendo...',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pause, size: 11, color: AppColors.accent),
                        SizedBox(width: 3),
                        Text('Pausar', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.accent)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 26,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(9)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flag_outlined, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Finalizar', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
