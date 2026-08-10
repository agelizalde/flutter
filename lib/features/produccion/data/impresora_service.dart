import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../domain/produccion_models.dart';

/// Error de impresión — conexión rechazada/timeout con la impresora de red.
class ImpresoraException implements Exception {
  ImpresoraException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _fmtFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

String _fmtQty(double v) {
  final texto = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
  return texto;
}

/// ZPL no soporta bien `^`/`~` dentro de un campo `^FD` (son los prefijos de
/// comando) — se reemplazan por un espacio para no romper la trama.
String _zplSanitizar(String texto) => texto.replaceAll('^', ' ').replaceAll('~', ' ');

/// Densidad asumida de la impresora (203dpi ≈ 8 dots/mm, la más común en
/// impresoras de etiquetas compactas tipo Honeywell PC42t/PM43 o Zebra
/// ZD/GC de escritorio). Si la impresora real es de 300dpi, este valor
/// tendría que pasar a ~11.8.
const _dotsPorMm = 8.0;

/// Peso relativo de cada campo para el reparto del espacio disponible — un
/// código de barra/QR necesita mucho más espacio que una línea de texto
/// para seguir siendo legible. Mismos valores que el editor de plantillas
/// (ver diseño del auto-ajuste, `EtiquetaDetallePage`/BD.txt).
const _pesoCampo = {
  CampoEtiqueta.producto: 1.3,
  CampoEtiqueta.marca: 1.0,
  CampoEtiqueta.lote: 1.0,
  CampoEtiqueta.cantidad: 1.1,
  CampoEtiqueta.fechaEmbalaje: 0.9,
  CampoEtiqueta.fechaVencimiento: 0.9,
  CampoEtiqueta.observacion: 0.8,
  CampoEtiqueta.rspa: 1.0,
  CampoEtiqueta.codigoBarra: 3.0,
  CampoEtiqueta.codigoQr: 4.0,
};

/// Texto del campo CANTIDAD según su modo — `null` si no hay nada para
/// imprimir (ej. modo PESAR sin peso cargado todavía).
String? _textoCantidad(EtiquetaCampoTemplate item, EtiquetaProduccion etq, {double? pesoManualKg}) {
  switch (item.cantidadModo) {
    case 'FIJO':
      return item.cantidadTextoFijo?.trim().isNotEmpty ?? false ? item.cantidadTextoFijo : null;
    case 'PESAR':
      return pesoManualKg != null ? '${_fmtQty(pesoManualKg)} Kg' : null;
    case 'REAL':
    default:
      return '${_fmtQty(etq.cantidad)} ${etq.unidad}';
  }
}

/// Un campo de la plantilla que efectivamente va a imprimirse, con el texto
/// ya resuelto para los campos de texto (`null` en `texto` para
/// CODIGO_BARRA/CODIGO_QR, que se renderizan aparte).
class _CampoRenderable {
  _CampoRenderable({required this.item, required this.peso, this.texto});

  final EtiquetaCampoTemplate item;
  final double peso;
  final String? texto;
}

List<_CampoRenderable> _camposRenderables(
  EtiquetaTemplate plantilla,
  EtiquetaProduccion etq,
  DateTime hoy, {
  double? pesoManualKg,
}) {
  final out = <_CampoRenderable>[];
  for (final item in plantilla.campos) {
    switch (item.campo) {
      case CampoEtiqueta.producto:
        out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: etq.producto));
        break;
      case CampoEtiqueta.marca:
        if (etq.marca?.trim().isNotEmpty ?? false) {
          out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: etq.marca));
        }
        break;
      case CampoEtiqueta.lote:
        out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: 'Lote: ${etq.loteInterno}'));
        break;
      case CampoEtiqueta.codigoBarra:
      case CampoEtiqueta.codigoQr:
        if (etq.codigoBarra?.trim().isNotEmpty ?? false) {
          out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!));
        }
        break;
      case CampoEtiqueta.cantidad:
        final texto = _textoCantidad(item, etq, pesoManualKg: pesoManualKg);
        if (texto != null) {
          out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: texto));
        }
        break;
      case CampoEtiqueta.fechaEmbalaje:
        out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: 'Embalado: ${_fmtFecha(hoy)}'));
        break;
      case CampoEtiqueta.fechaVencimiento:
        if (etq.fechaVencimiento != null) {
          out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: 'Vence: ${_fmtFecha(etq.fechaVencimiento!)}'));
        }
        break;
      case CampoEtiqueta.observacion:
        if (item.observacionTexto?.trim().isNotEmpty ?? false) {
          out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: item.observacionTexto));
        }
        break;
      case CampoEtiqueta.rspa:
        if (item.rspaTexto?.trim().isNotEmpty ?? false) {
          out.add(_CampoRenderable(item: item, peso: _pesoCampo[item.campo]!, texto: item.rspaTexto));
        }
        break;
    }
  }
  return out;
}

/// Longitud aproximada en dots del código de barra/QR renderizado (a lo
/// largo del eje de lectura) — no hay forma exacta de saberlo sin
/// rasterizar, así que se estima a partir de la cantidad de caracteres y el
/// módulo/magnificación elegidos (mismo criterio documentado en el diseño
/// del auto-ajuste: "aproximado", no pixel-perfect).
int _estimarLargoCodigoBarraDots(String data, int moduloWidthDots) => (data.length * 11 + 35) * moduloWidthDots ~/ 2;

int _estimarLargoQrDots(int magnificacion) => magnificacion * 33;

/// Arma el ZPL de una etiqueta según las dimensiones y campos de la
/// PLANTILLA (`EtiquetaTemplate`, catálogo reusable — ver
/// `produccion/etiquetas/BD.txt`), ya no de una config del dispositivo: el
/// tamaño físico (`^PW`/`^LL`) y el reparto de espacio entre campos salen de
/// `plantilla.anchoMm`/`altoMm`, no del rollo cargado en la impresora.
///
/// **Rotación fija 90°** (2026-07-15, a partir de un ZPL real que ya usaba
/// el usuario en producción — el confirmó que TODAS las etiquetas van así,
/// no es una opción por plantilla): el texto se imprime con `^A0R` y los
/// códigos de barra/QR con su variante rotada (`^BxR`/`^BQR`), en vez de la
/// orientación normal (`^A0N`/`^BxN`). Con esta rotación, los campos se
/// apilan de DERECHA A IZQUIERDA a lo largo de `ancho_mm` (`^PW`, eje X) —
/// cada campo ocupa una porción de ese ancho según su peso — mientras que
/// `alto_mm` (`^LL`, eje Y) es el espacio que tiene cada línea de texto para
/// extenderse (`^FB`) o cada código de barra para su longitud. Es al revés
/// de una etiqueta sin rotar, donde el ancho sería el espacio de cada línea
/// y el alto se repartiría entre campos.
///
/// El "auto-ajuste" reparte `ancho_mm` entre los campos activos según un
/// peso por tipo (`_pesoCampo` — un código de barra necesita mucho más
/// espacio que una línea de texto) y calcula tamaño de fuente/altura de
/// barra proporcional a la porción que le toca a cada uno. La alineación
/// (`item.alineacion`) se aplica con `^FB` (field block) para texto, y con
/// un offset `^FO` aproximado para códigos de barra/QR (que no soportan
/// `^FB`).
///
/// [pesoManualKg] es obligatorio si algún campo `CANTIDAD` de la plantilla
/// tiene `cantidadModo == 'PESAR'` — el operario lo carga a mano por cada
/// copia física antes de imprimirla (ver `EtiquetasScreen`), el backend no
/// sabe nada de esto.
String construirZplEtiqueta(
  EtiquetaProduccion etq,
  EtiquetaTemplate plantilla, {
  double? pesoManualKg,
}) {
  final anchoDots = (plantilla.anchoMm * _dotsPorMm).round(); // ^PW — eje de apilado de campos
  final altoDots = (plantilla.altoMm * _dotsPorMm).round(); // ^LL — eje de extensión de cada campo (^FB/largo de barra)
  final margenSpanDots = 20;
  final spanUtilDots = math.max(1, altoDots - margenSpanDots * 2);
  final hoy = DateTime.now();

  final buffer = StringBuffer()
    ..writeln('^XA')
    ..writeln('^CI28') // UTF-8, para que acentos/ñ impriman bien en firmware moderno
    ..writeln('^PW$anchoDots')
    ..writeln('^LL$altoDots');

  final renderables = _camposRenderables(plantilla, etq, hoy, pesoManualKg: pesoManualKg);
  final totalPeso = renderables.fold<double>(0, (s, r) => s + r.peso);
  if (totalPeso <= 0) {
    buffer.writeln('^XZ');
    return buffer.toString();
  }

  final margenApiladoDots = (4 * _dotsPorMm).round();
  final anchoDisponibleDots = math.max(1, anchoDots - margenApiladoDots);
  final unidadAnchoDots = anchoDisponibleDots / totalPeso;

  final fontMinDots = 1.5 * _dotsPorMm;
  final fontMaxDots = 6.0 * _dotsPorMm;

  // Arranca cerca del borde derecho del ancho (^PW) y va restando hacia la
  // izquierda por cada campo — "distribución de derecha a izquierda" del
  // ZPL de referencia.
  var x = anchoDots - (margenApiladoDots / 2).round();

  for (final r in renderables) {
    final bloqueAnchoDots = unidadAnchoDots * r.peso;

    if (r.item.campo == CampoEtiqueta.codigoBarra || r.item.campo == CampoEtiqueta.codigoQr) {
      final forzarQr = r.item.campo == CampoEtiqueta.codigoQr;
      final data = _zplSanitizar(etq.codigoBarra!);
      final barAltoDots = bloqueAnchoDots.clamp(15.0, anchoDisponibleDots.toDouble()).round();

      if (forzarQr) {
        final mag = (barAltoDots / 10).clamp(1, 10).round();
        final largoEstDots = _estimarLargoQrDots(mag);
        final y = _offsetPorAlineacion(r.item.alineacion, margenSpanDots, spanUtilDots, largoEstDots);
        buffer.writeln('^FO$x,$y\n^BQR,2,$mag\n^FDLA,$data^FS');
      } else {
        final moduloWidth = (barAltoDots / 70 * 2).clamp(1, 10).round();
        final largoEstDots = _estimarLargoCodigoBarraDots(data, moduloWidth);
        final y = _offsetPorAlineacion(r.item.alineacion, margenSpanDots, spanUtilDots, largoEstDots);
        buffer.writeln('^FO$x,$y^BY$moduloWidth,3,$barAltoDots');
        buffer.writeln('${_comandoSimbolo(etq.tipoCodigo)}\n^FD$data^FS');
      }
      x -= barAltoDots;
      continue;
    }

    final fontDots = (bloqueAnchoDots * 0.7).clamp(fontMinDots, fontMaxDots).round();
    buffer.writeln('^FO$x,0');
    buffer.writeln('^A0R,$fontDots,$fontDots');
    buffer.writeln('^FB$spanUtilDots,1,0,${_justLetra(r.item.alineacion)},0');
    buffer.writeln('^FD${_zplSanitizar(r.texto ?? '')}^FS');
    x -= bloqueAnchoDots.round();
  }

  buffer.writeln('^XZ');
  return buffer.toString();
}

/// `^FB` (field block) espera la justificación como letra: L/C/R — el
/// parámetro funciona igual con texto rotado (`^A0R`), solo cambia la
/// dirección visual en la que se lee, no la sintaxis del comando.
String _justLetra(String alineacion) {
  switch (alineacion) {
    case AlineacionEtiqueta.centro:
      return 'C';
    case AlineacionEtiqueta.derecha:
      return 'R';
    case AlineacionEtiqueta.izquierda:
    default:
      return 'L';
  }
}

/// Offset dentro del span disponible (eje `alto_mm`/`^LL`) para un código de
/// barra/QR según su alineación — estos comandos no soportan `^FB`, así que
/// la alineación se aproxima corriendo el punto de origen `^FO` según el
/// largo estimado del símbolo.
int _offsetPorAlineacion(String alineacion, int margenSpanDots, int spanUtilDots, int largoContenidoDots) {
  switch (alineacion) {
    case AlineacionEtiqueta.centro:
      return margenSpanDots + math.max(0, ((spanUtilDots - largoContenidoDots) / 2).round());
    case AlineacionEtiqueta.derecha:
      return margenSpanDots + math.max(0, spanUtilDots - largoContenidoDots);
    case AlineacionEtiqueta.izquierda:
    default:
      return margenSpanDots;
  }
}

/// Cada tipo de símbolo usa un comando ZPL distinto (`^BE`=EAN13,
/// `^B8`=EAN8, `^BU`=UPC-A, `^BC`=Code128), en su variante rotada (`R`) para
/// que coincida con `^A0R` — ver rotación fija documentada en
/// `construirZplEtiqueta`. Code128 es el fallback: puede codificar
/// cualquier texto/número, por eso se usa también para `INTERNO`/`OTRO`/
/// tipo desconocido.
String _comandoSimbolo(String? tipo) {
  switch ((tipo ?? '').toUpperCase()) {
    case 'EAN13':
      return '^BER,,Y,N';
    case 'EAN8':
      return '^B8R,,Y,N';
    case 'UPC':
      return '^BUR,,Y,N';
    case 'CODE128':
    default:
      return '^BCR,,Y,N,N';
  }
}

/// Envía comandos ZPL crudos a una impresora de etiquetas por red, vía
/// socket TCP al puerto RAW estándar de impresión (9100, "JetDirect") —
/// mismo mecanismo que usan Zebra/la mayoría de las impresoras de
/// etiquetas industriales (incluidas las Honeywell configuradas en modo de
/// emulación ZPL). No requiere ningún plugin nativo de Bluetooth/USB.
class ImpresoraService {
  Future<void> probarConexion({required String ip, required int puerto}) async {
    final socket = await _conectar(ip: ip, puerto: puerto);
    await socket.close();
  }

  Future<void> imprimirEtiqueta({
    required String ip,
    required int puerto,
    required EtiquetaProduccion etiqueta,
    required EtiquetaTemplate plantilla,
    double? pesoManualKg,
  }) async {
    final zpl = construirZplEtiqueta(etiqueta, plantilla, pesoManualKg: pesoManualKg);
    final socket = await _conectar(ip: ip, puerto: puerto);
    try {
      socket.add(utf8.encode(zpl));
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  Future<Socket> _conectar({required String ip, required int puerto}) async {
    try {
      return await Socket.connect(ip, puerto, timeout: const Duration(seconds: 5));
    } on SocketException catch (e) {
      throw ImpresoraException(
        'No se pudo conectar con la impresora en $ip:$puerto (${e.osError?.message ?? e.message})',
      );
    } on Object {
      throw ImpresoraException('No se pudo conectar con la impresora en $ip:$puerto');
    }
  }
}
