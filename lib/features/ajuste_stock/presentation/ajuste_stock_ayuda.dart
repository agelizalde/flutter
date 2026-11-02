import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/walkthrough_modulo.dart';

/// Presentación "Conocé el módulo" de Ajuste de stock — se abre desde el (?)
/// del AppBar de `AjusteStockHomeScreen`. El contenedor y las pantallas son
/// comunes (`walkthrough_modulo.dart`); acá solo vive el contenido y las
/// demos. A pedido del usuario hay una pantalla "Cómo funciona" por cada
/// opción de "Nuevo ajuste": por ubicación, por producto y merma.
Future<void> abrirAyudaAjusteStock(BuildContext context) => abrirWalkthrough(context, _modulo);

// Color del módulo en el menú (`home_screen.dart`): slate 0xFF475569.
const _pastel = Color(0xFFE2E8F0);
const _fuerte = Color(0xFF475569);
const _oscuro = Color(0xFF334155);
const _listo = Color(0xFF16A34A);
const _resta = Color(0xFFDC2626);

const _modulo = WalkthroughModulo(
  icono: Icons.rule_outlined,
  nombre: 'Ajuste de stock',
  pastel: _pastel,
  fuerte: _fuerte,
  oscuro: _oscuro,
  proposito: 'Corregir el stock del sistema para que coincida con lo que hay en el depósito: '
      'contando una ubicación, contando un producto o sacando lo que se rompió o venció.',
  tipos: [
    WalkthroughTipo(
      titulo: 'Control por ubicación',
      icono: Icons.location_on_outlined,
      pasos: [
        'Escaneá o buscá la ubicación que vas a contar.',
        'Contá cada producto y anotá cuánto hay: el sistema no te muestra cuánto debería haber.',
        'Si encontrás algo que no figura, tocá "Agregar producto". Al final, "Crear ajuste".',
      ],
      demo: _DemoUbicacion(),
    ),
    WalkthroughTipo(
      titulo: 'Control por producto',
      icono: Icons.inventory_2_outlined,
      pasos: [
        'Elegí o escaneá el producto que vas a contar.',
        'Aparecen todas las ubicaciones donde está: contá cuánto hay en cada una.',
        'Si está en otro lugar, tocá "Agregar ubicación". Se crea un ajuste por ubicación.',
      ],
      demo: _DemoProducto(),
    ),
    WalkthroughTipo(
      titulo: 'Mermar producto',
      icono: Icons.recycling_outlined,
      pasos: [
        'Elegí el producto y la ubicación de donde sale.',
        'Elegí la causa (rotura, vencimiento, consumo interno…) y poné la cantidad.',
        'Tocá "Mermar" y se descuenta al instante. Si es vencimiento, sale del lote que vence antes.',
      ],
      demo: _DemoMerma(),
    ),
  ],
  consejo: 'Contá siempre lo que ves, sin adivinar. Si te equivocaste, desde el detalle del ajuste '
      'lo podés anular dentro de la primera hora. Todo queda en "Historial".',
  textoFinal: '¡A contar!',
);

// ---------------------------------------------------------------------------
// Recorrido del dedo
// ---------------------------------------------------------------------------

const _fuera = Offset(250, WalkthroughDemo.alto + 30);

/// Posición del dedo: arranca fuera de la pantallita y recorre cada tramo
/// `(desde, hasta, destino)` en orden; el último vuelve a [_fuera].
Offset _ruta(double t, List<(double, double, Offset)> tramos) {
  var pos = _fuera;
  for (final (desde, hasta, destino) in tramos) {
    pos = Offset.lerp(pos, destino, Curves.easeInOutCubic.transform(walkthroughTramo(t, desde, hasta)))!;
  }
  return pos;
}

bool _toca(double t, double desde) => t >= desde && t < desde + 0.04;

/// Lo que "llega" (cantidad, tilde, contador) entra con rebote.
double _pop(double t, double desde, [double dura = 0.10]) =>
    Curves.elasticOut.transform(walkthroughTramo(t, desde, desde + dura));

// ---------------------------------------------------------------------------
// Demo 1 · Control por ubicación
// ---------------------------------------------------------------------------

typedef _Conteo = ({String nombre, String cantidad});

const _ejemplosUbicacion = <({String ubicacion, List<_Conteo> productos})>[
  (
    ubicacion: 'A-03-02',
    productos: [
      (nombre: 'Leche entera 1L', cantidad: '22'),
      (nombre: 'Yogur frutilla 1L', cantidad: '15'),
      (nombre: 'Manteca 200g', cantidad: '8'),
    ],
  ),
  (
    ubicacion: 'B-01-03',
    productos: [
      (nombre: 'Harina 000 1kg', cantidad: '40'),
      (nombre: 'Azúcar 1kg', cantidad: '31'),
      (nombre: 'Arroz 1kg', cantidad: '26'),
    ],
  ),
  (
    ubicacion: 'C-02-01',
    productos: [
      (nombre: 'Agua mineral 2L', cantidad: '18'),
      (nombre: 'Gaseosa cola 1,5L', cantidad: '12'),
      (nombre: 'Jugo naranja 1L', cantidad: '9'),
    ],
  ),
];

/// Línea de tiempo de cada vuelta (0 a 1):
/// - 0–0,10 el dedo va al escáner; 0,10 toca y aparece la ubicación con
///   rebote y sus productos en cascada, con la cantidad vacía (a ciegas).
/// - 0,26 / 0,37 / 0,48 el dedo va a cada cantidad; al tocar se completa.
/// - 0,59–0,67 va a "Crear ajuste"; 0,67 toca y queda "Ajuste aplicado".
class _DemoUbicacion extends StatelessWidget {
  const _DemoUbicacion();

  static const _pEscaner = Offset(240, 24);
  static double _yFila(int i) => 48 + i * 36.0;
  static Offset _pCampo(int i) => Offset(226, _yFila(i) + 15);
  static const _pCrear = Offset(135, 180);

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final ej = _ejemplosUbicacion[vuelta % _ejemplosUbicacion.length];
        final escaneada = t >= 0.14;
        final hecho = t >= 0.72;
        final dedo = _ruta(t, [
          (0.00, 0.10, _pEscaner),
          (0.26, 0.32, _pCampo(0)),
          (0.37, 0.43, _pCampo(1)),
          (0.48, 0.54, _pCampo(2)),
          (0.59, 0.67, _pCrear),
          (0.74, 0.88, _fuera),
        ]);

        return Stack(
          children: [
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              height: 28,
              child: Row(
                children: [
                  if (escaneada)
                    Transform.scale(
                      scale: _pop(t, 0.14),
                      alignment: Alignment.centerLeft,
                      child: _Etiqueta(icono: Icons.location_on, texto: ej.ubicacion),
                    )
                  else
                    const Text(
                      'Escaneá una ubicación',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.faint),
                    ),
                  const Spacer(),
                  _BotonEscaner(presionado: _toca(t, 0.10)),
                ],
              ),
            ),
            for (var i = 0; i < 3; i++)
              Positioned(
                left: 12,
                right: 12,
                top: _yFila(i),
                height: 30,
                child: _Cascadita(
                  t: walkthroughTramo(t, 0.16 + i * 0.03, 0.24 + i * 0.03),
                  child: _Fila(
                    texto: ej.productos[i].nombre,
                    cantidad: ej.productos[i].cantidad,
                    llenado: t >= 0.33 + i * 0.11 ? _pop(t, 0.33 + i * 0.11) : 0,
                    presionado: _toca(t, 0.32 + i * 0.11),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              top: 166,
              height: 30,
              child: Opacity(
                opacity: escaneada ? 1 : 0.4,
                child: _BotonPrincipal(
                  texto: 'Crear ajuste',
                  textoHecho: 'Ajuste aplicado',
                  hecho: hecho ? _pop(t, 0.72, 0.14) : 0,
                  presionado: _toca(t, 0.67),
                ),
              ),
            ),
            _Dedo(posicion: dedo, tocando: [0.10, 0.32, 0.43, 0.54, 0.67].any((d) => _toca(t, d))),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 2 · Control por producto
// ---------------------------------------------------------------------------

const _ejemplosProducto = <({String producto, List<_Conteo> ubicaciones})>[
  (
    producto: 'Leche entera 1L',
    ubicaciones: [
      (nombre: 'A-03-02', cantidad: '22'),
      (nombre: 'B-02-04', cantidad: '10'),
      (nombre: 'C-01-01', cantidad: '6'),
    ],
  ),
  (
    producto: 'Harina 000 1kg',
    ubicaciones: [
      (nombre: 'B-01-03', cantidad: '40'),
      (nombre: 'B-01-04', cantidad: '12'),
      (nombre: 'REAC-01', cantidad: '5'),
    ],
  ),
  (
    producto: 'Agua mineral 2L',
    ubicaciones: [
      (nombre: 'C-02-01', cantidad: '18'),
      (nombre: 'C-03-02', cantidad: '24'),
      (nombre: 'A-01-01', cantidad: '4'),
    ],
  ),
];

/// Línea de tiempo de cada vuelta (0 a 1):
/// - 0–0,10 el dedo va al escáner; 0,10 toca y aparece el producto con
///   rebote y las 2 ubicaciones donde está, con la cantidad vacía.
/// - 0,26 / 0,37 el dedo completa cada cantidad.
/// - 0,48–0,54 va a "Agregar ubicación"; 0,54 toca y entra una ubicación
///   NUEVA (ya contada) que empuja el enlace hacia abajo.
/// - 0,64–0,72 va a "Crear ajuste"; 0,72 toca y queda "3 ajustes aplicados"
///   (uno por ubicación).
class _DemoProducto extends StatelessWidget {
  const _DemoProducto();

  static const _pEscaner = Offset(240, 24);
  static double _yFila(int i) => 46 + i * 34.0;
  static Offset _pCampo(int i) => Offset(226, _yFila(i) + 14);
  static const _pCrear = Offset(135, 186);

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final ej = _ejemplosProducto[vuelta % _ejemplosProducto.length];
        final elegido = t >= 0.14;
        final nueva = Curves.easeOutCubic.transform(walkthroughTramo(t, 0.57, 0.65));
        final yAgregar = _yFila(2) + 4 + 34 * nueva;
        final pAgregar = Offset(70, _yFila(2) + 12);
        final hecho = t >= 0.77;
        final dedo = _ruta(t, [
          (0.00, 0.10, _pEscaner),
          (0.26, 0.32, _pCampo(0)),
          (0.37, 0.43, _pCampo(1)),
          (0.48, 0.54, pAgregar),
          (0.64, 0.72, _pCrear),
          (0.78, 0.92, _fuera),
        ]);

        return Stack(
          children: [
            Positioned(
              left: 12,
              right: 12,
              top: 10,
              height: 28,
              child: Row(
                children: [
                  if (elegido)
                    Flexible(
                      child: Transform.scale(
                        scale: _pop(t, 0.14),
                        alignment: Alignment.centerLeft,
                        child: _Etiqueta(icono: Icons.inventory_2, texto: ej.producto),
                      ),
                    )
                  else
                    const Text(
                      'Elegí un producto',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.faint),
                    ),
                  const Spacer(),
                  _BotonEscaner(presionado: _toca(t, 0.10)),
                ],
              ),
            ),
            for (var i = 0; i < 2; i++)
              Positioned(
                left: 12,
                right: 12,
                top: _yFila(i),
                height: 28,
                child: _Cascadita(
                  t: walkthroughTramo(t, 0.16 + i * 0.03, 0.24 + i * 0.03),
                  child: _Fila(
                    texto: ej.ubicaciones[i].nombre,
                    icono: Icons.location_on_outlined,
                    cantidad: ej.ubicaciones[i].cantidad,
                    llenado: t >= 0.33 + i * 0.11 ? _pop(t, 0.33 + i * 0.11) : 0,
                    presionado: _toca(t, 0.32 + i * 0.11),
                  ),
                ),
              ),
            if (nueva > 0)
              Positioned(
                left: 12,
                right: 12,
                top: _yFila(2),
                height: 28,
                child: Opacity(
                  opacity: nueva,
                  child: Transform.translate(
                    offset: Offset(0, -10 * (1 - nueva)),
                    child: _Fila(
                      texto: ej.ubicaciones[2].nombre,
                      icono: Icons.location_on_outlined,
                      cantidad: ej.ubicaciones[2].cantidad,
                      llenado: _pop(t, 0.60),
                      nueva: true,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 14,
              top: yAgregar,
              child: _Cascadita(
                t: walkthroughTramo(t, 0.22, 0.30),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 90),
                  scale: _toca(t, 0.54) ? 0.9 : 1,
                  child: const Row(
                    children: [
                      Icon(Icons.add_location_alt_outlined, size: 14, color: _oscuro),
                      SizedBox(width: 4),
                      Text(
                        'Agregar ubicación',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _oscuro),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 172,
              height: 28,
              child: Opacity(
                opacity: elegido ? 1 : 0.4,
                child: _BotonPrincipal(
                  texto: 'Crear ajuste',
                  textoHecho: '3 ajustes aplicados',
                  hecho: hecho ? _pop(t, 0.77, 0.14) : 0,
                  presionado: _toca(t, 0.72),
                ),
              ),
            ),
            _Dedo(posicion: dedo, tocando: [0.10, 0.32, 0.43, 0.54, 0.72].any((d) => _toca(t, d))),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Demo 3 · Mermar producto
// ---------------------------------------------------------------------------

const _causas = ['Rotura', 'Vencimiento', 'Consumo'];

const _ejemplosMerma = <({String producto, String ubicacion, int stock, int cantidad, int causa})>[
  (producto: 'Yogur frutilla 1L', ubicacion: 'A-03-02', stock: 24, cantidad: 3, causa: 1),
  (producto: 'Huevos x30', ubicacion: 'B-02-01', stock: 40, cantidad: 2, causa: 0),
  (producto: 'Café molido 500g', ubicacion: 'C-01-04', stock: 15, cantidad: 1, causa: 2),
];

/// Línea de tiempo de cada vuelta (0 a 1):
/// - 0–0,12 el dedo va a la causa; 0,12 toca y el chip se marca.
/// - 0,20–0,30 va a la cantidad; 0,30 toca y aparece con rebote.
/// - 0,46–0,56 va a "Mermar"; 0,56 toca.
/// - 0,62 sube un "−N" rojo desde el stock, que baja con un saltito, y el
///   botón queda "Merma aplicada".
class _DemoMerma extends StatelessWidget {
  const _DemoMerma();

  static const _anchoChip = (WalkthroughDemo.ancho - 24 - 12) / 3;
  static Offset _pCausa(int i) => Offset(12 + _anchoChip / 2 + i * (_anchoChip + 6), 92);
  static const _pCantidad = Offset(220, 135);
  static const _pMermar = Offset(135, 178);

  @override
  Widget build(BuildContext context) {
    return WalkthroughDemo(
      builder: (context, t, vuelta) {
        final ej = _ejemplosMerma[vuelta % _ejemplosMerma.length];
        final conCausa = t >= 0.13;
        final conCantidad = t >= 0.31;
        final mermado = t >= 0.64;
        final resta = walkthroughTramo(t, 0.62, 0.82);
        final dedo = _ruta(t, [
          (0.00, 0.12, _pCausa(ej.causa)),
          (0.20, 0.30, _pCantidad),
          (0.46, 0.56, _pMermar),
          (0.62, 0.78, _fuera),
        ]);

        return Stack(
          children: [
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              height: 44,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ej.producto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                          ),
                          const SizedBox(height: 1),
                          Text(ej.ubicacion, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: mermado ? 1 + 0.25 * math.sin(math.pi * walkthroughTramo(t, 0.64, 0.76)) : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          'Stock ${mermado ? ej.stock - ej.cantidad : ej.stock}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _oscuro),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (resta > 0 && resta < 1)
              Positioned(
                right: 26,
                top: 18 - 22 * Curves.easeOutCubic.transform(resta),
                child: Opacity(
                  opacity: 1 - resta,
                  child: Text(
                    '−${ej.cantidad}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _resta),
                  ),
                ),
              ),
            const Positioned(
              left: 14,
              top: 64,
              child: Text(
                'CAUSA',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1),
              ),
            ),
            for (var i = 0; i < _causas.length; i++)
              Positioned(
                left: 12 + i * (_anchoChip + 6),
                top: 80,
                width: _anchoChip,
                height: 24,
                child: _ChipCausa(
                  texto: _causas[i],
                  marcado: conCausa && i == ej.causa ? _pop(t, 0.13) : 0,
                  presionado: i == ej.causa && _toca(t, 0.12),
                ),
              ),
            Positioned(
              left: 12,
              right: 12,
              top: 120,
              height: 30,
              child: _Fila(
                texto: 'Cantidad a mermar',
                cantidad: '${ej.cantidad}',
                llenado: conCantidad ? _pop(t, 0.31) : 0,
                presionado: _toca(t, 0.30),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: 164,
              height: 30,
              child: Opacity(
                opacity: conCausa && conCantidad ? 1 : 0.4,
                child: _BotonPrincipal(
                  texto: 'Mermar',
                  textoHecho: 'Merma aplicada',
                  hecho: mermado ? _pop(t, 0.64, 0.14) : 0,
                  presionado: _toca(t, 0.56),
                ),
              ),
            ),
            _Dedo(posicion: dedo, tocando: [0.12, 0.30, 0.56].any((d) => _toca(t, d))),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Piezas comunes de las demos
// ---------------------------------------------------------------------------

class _Dedo extends StatelessWidget {
  const _Dedo({required this.posicion, required this.tocando});

  final Offset posicion;
  final bool tocando;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: posicion.dx - WalkthroughDedo.radio,
      top: posicion.dy - WalkthroughDedo.radio,
      child: WalkthroughDedo(color: _fuerte, tocando: tocando),
    );
  }
}

/// Entrada en cascada dentro de la demo: sube 10 px con fundido.
class _Cascadita extends StatelessWidget {
  const _Cascadita({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final v = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: _fuerte, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonEscaner extends StatelessWidget {
  const _BotonEscaner({required this.presionado});

  final bool presionado;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: presionado ? 0.85 : 1,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: _pastel, borderRadius: BorderRadius.circular(9)),
        child: const Icon(Icons.qr_code_scanner, size: 16, color: _oscuro),
      ),
    );
  }
}

/// Fila "cosa a contar + cantidad". La cantidad arranca vacía (a ciegas) y
/// [llenado] 0→1 la hace aparecer con rebote; al completarse la fila se
/// tiñe de pastel.
class _Fila extends StatelessWidget {
  const _Fila({
    required this.texto,
    required this.cantidad,
    required this.llenado,
    this.icono,
    this.presionado = false,
    this.nueva = false,
  });

  final String texto;
  final String cantidad;
  final double llenado;
  final IconData? icono;
  final bool presionado;
  final bool nueva;

  @override
  Widget build(BuildContext context) {
    final lleno = llenado > 0;

    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: lleno ? _pastel : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: AppColors.muted),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          if (nueva) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: _fuerte, borderRadius: BorderRadius.circular(5)),
              child: const Text(
                'NUEVA',
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
              ),
            ),
          ],
          const Spacer(),
          AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: presionado ? 0.9 : 1,
            child: Container(
              width: 56,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: presionado || lleno ? _fuerte : AppColors.border, width: 1.2),
              ),
              child: lleno
                  ? Transform.scale(
                      scale: llenado,
                      child: Text(
                        cantidad,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _oscuro),
                      ),
                    )
                  : const Text('—', style: TextStyle(fontSize: 11, color: AppColors.faint)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipCausa extends StatelessWidget {
  const _ChipCausa({required this.texto, required this.marcado, required this.presionado});

  final String texto;

  /// 0 = sin marcar, 0→1 = se marca con rebote.
  final double marcado;
  final bool presionado;

  @override
  Widget build(BuildContext context) {
    final activo = marcado > 0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: presionado ? 0.9 : (activo ? 0.9 + 0.1 * marcado : 1),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? _fuerte : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: activo ? _fuerte : AppColors.border),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: activo ? Colors.white : AppColors.sub,
          ),
        ),
      ),
    );
  }
}

/// Botón de acción de la demo; [hecho] 0→1 lo pasa a verde con tilde.
class _BotonPrincipal extends StatelessWidget {
  const _BotonPrincipal({
    required this.texto,
    required this.textoHecho,
    required this.hecho,
    required this.presionado,
  });

  final String texto;
  final String textoHecho;
  final double hecho;
  final bool presionado;

  @override
  Widget build(BuildContext context) {
    final listo = hecho > 0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: presionado ? 0.95 : 1,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: listo ? _listo : _oscuro,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (listo) ...[
              Transform.scale(scale: hecho, child: const Icon(Icons.check_circle, size: 15, color: Colors.white)),
              const SizedBox(width: 5),
            ],
            Text(
              listo ? textoHecho : texto,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
