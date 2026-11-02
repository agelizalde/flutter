import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación de "Solicitar control de stock" — se abre desde el (?) del
/// AppBar de `SolicitarControlScreen`. Explica solo esta sección (pedirle a
/// otro que cuente); el resto de Ajuste de stock está en
/// `ajuste_stock_ayuda.dart`. Mismos colores que el módulo.
Future<void> abrirAyudaSolicitarControl(BuildContext context) => abrirWalkthrough(context, _modulo);

const _pastel = Color(0xFFE2E8F0);
const _fuerte = Color(0xFF475569);
const _oscuro = Color(0xFF334155);
const _listo = Color(0xFF16A34A);

const _modulo = WalkthroughModulo(
  icono: Icons.person_add_alt_1_outlined,
  nombre: 'Solicitar control',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Pedirle a otra persona del depósito que cuente una ubicación. '
      'Vos no contás nada: solo elegís dónde, por qué y quién.',
  pasos: [
    'Buscá la ubicación que querés hacer contar.',
    'Elegí el motivo y a quién se lo asignás. Si querés, dejale una nota.',
    'Tocá "Enviar solicitud": le aparece en "Mis solicitudes" y queda pendiente hasta que la cuente.',
  ],
  consejo: 'Usá la observación para contar qué te llamó la atención (ej. "faltan cajas al fondo"). '
      'Si no encontrás a alguien en la lista, todavía no está habilitado para recibir controles en este depósito.',
  textoFinal: '¡Entendido!',
  demo: _DemoSolicitar(),
);

typedef _Ejemplo = ({String ubicacion, String motivo, List<String> usuarios, int elegido});

/// Ejemplos de la demo — cada vuelta arranca por el siguiente.
const _ejemplos = <_Ejemplo>[
  (ubicacion: 'A-03-02', motivo: 'Conteo físico', usuarios: ['Juan Pérez', 'María Gómez'], elegido: 0),
  (ubicacion: 'B-01-03', motivo: 'Rotura', usuarios: ['Carlos Benítez', 'Ana Rojas'], elegido: 1),
  (ubicacion: 'C-02-01', motivo: 'Vencimiento', usuarios: ['Lucía Martínez', 'Diego Acosta'], elegido: 0),
];

/// Línea de tiempo de cada vuelta (0 a 1):
/// - 0–0,08 la ubicación ya elegida entra con rebote.
/// - 0,04–0,16 el dedo va a una persona de "Asignar a"; 0,16 toca, queda
///   marcada con tilde y la otra se desvanece.
/// - 0,30–0,42 va a "Enviar solicitud"; 0,42 toca y queda "Solicitud enviada".
/// - 0,56–0,66 baja desde arriba lo que le llega a la persona: la tarea
///   PENDIENTE en "Mis solicitudes".
class _DemoSolicitar extends StatelessWidget {
  const _DemoSolicitar();

  static double _yUsuario(int i) => 104 + i * 30.0;
  static const _pEnviar = Offset(135, 184);
  static const _fuera = Offset(250, WalkthroughDemo.alto + 30);

  static Offset _posDedo(double t, Offset pUsuario) {
    Offset mover(Offset a, Offset b, double desde, double hasta) =>
        Offset.lerp(a, b, Curves.easeInOutCubic.transform(walkthroughTramo(t, desde, hasta)))!;

    if (t < 0.30) return mover(_fuera, pUsuario, 0.04, 0.16);
    if (t < 0.48) return mover(pUsuario, _pEnviar, 0.30, 0.42);
    return mover(_pEnviar, _fuera, 0.48, 0.62);
  }

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final ej = _ejemplos[vuelta % _ejemplos.length];
        final elegido = t >= 0.17;
        final marca = Curves.elasticOut.transform(walkthroughTramo(t, 0.17, 0.29));
        final otraSeVa = Curves.easeOutCubic.transform(walkthroughTramo(t, 0.20, 0.30));
        final enviado = t >= 0.46;
        final llegada = Curves.easeOutBack.transform(walkthroughTramo(t, 0.56, 0.66));

        final tocaUsuario = t >= 0.16 && t < 0.20;
        final tocaEnviar = t >= 0.42 && t < 0.46;
        final dedo = _posDedo(t, Offset(200, _yUsuario(ej.elegido) + 13));

        return Stack(
          children: [
            Positioned(
              left: 12,
              top: 12,
              child: Transform.scale(
                scale: Curves.elasticOut.transform(walkthroughTramo(t, 0, 0.10)),
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: _fuerte, borderRadius: BorderRadius.circular(9)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        ej.ubicacion,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(left: 14, top: 46, child: _Rotulo('MOTIVO')),
            Positioned(
              left: 12,
              right: 12,
              top: 60,
              height: 26,
              child: Container(
                padding: const EdgeInsets.only(left: 10, right: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(ej.motivo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            const Positioned(left: 14, top: 92, child: _Rotulo('ASIGNAR A')),
            for (var i = 0; i < 2; i++)
              Positioned(
                left: 12,
                right: 12,
                top: _yUsuario(i),
                height: 26,
                child: Opacity(
                  opacity: i != ej.elegido ? 1 - otraSeVa : 1,
                  child: _FilaUsuario(
                    nombre: ej.usuarios[i],
                    marca: i == ej.elegido && elegido ? marca : 0,
                    presionada: i == ej.elegido && tocaUsuario,
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              top: 170,
              height: 28,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 90),
                scale: tocaEnviar ? 0.95 : 1,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: enviado ? _listo : (elegido ? _oscuro : AppColors.borderStrong),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (enviado) ...[
                        Transform.scale(
                          scale: Curves.elasticOut.transform(walkthroughTramo(t, 0.46, 0.58)),
                          child: const Icon(Icons.check_circle, size: 15, color: Colors.white),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        enviado ? 'Solicitud enviada' : 'Enviar solicitud',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (llegada > 0)
              Positioned(
                left: 10,
                right: 10,
                top: -50 + 58 * llegada,
                height: 44,
                child: _AvisoPendiente(nombre: ej.usuarios[ej.elegido], ubicacion: ej.ubicacion),
              ),
            Positioned(
              left: dedo.dx - WalkthroughDedo.radio,
              top: dedo.dy - WalkthroughDedo.radio,
              child: WalkthroughDedo(color: _fuerte, tocando: tocaUsuario || tocaEnviar),
            ),
          ],
        );
      },
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({required this.nombre, required this.marca, required this.presionada});

  final String nombre;

  /// 0 = sin elegir, 0→1 = se marca con rebote.
  final double marca;
  final bool presionada;

  @override
  Widget build(BuildContext context) {
    final elegida = marca > 0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: presionada ? 0.95 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: elegida ? _pastel : AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: elegida ? _fuerte : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: _fuerte, shape: BoxShape.circle),
              child: Text(
                nombre[0],
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
            const SizedBox(width: 7),
            Text(nombre, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.text)),
            const Spacer(),
            if (elegida)
              Transform.scale(
                scale: marca,
                child: const Icon(Icons.check_circle, size: 16, color: _fuerte),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lo que ve la persona asignada: la tarea pendiente en "Mis solicitudes".
class _AvisoPendiente extends StatelessWidget {
  const _AvisoPendiente({required this.nombre, required this.ubicacion});

  final String nombre;
  final String ubicacion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.fact_check_outlined, size: 15, color: _oscuro),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mis solicitudes · ${nombre.split(' ').first}',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                Text(
                  'Contar $ubicacion',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: AppColors.waBg, borderRadius: BorderRadius.circular(999)),
            child: const Text(
              'PENDIENTE',
              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: AppColors.waTx, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
