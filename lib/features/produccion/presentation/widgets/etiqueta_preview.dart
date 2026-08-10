import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/produccion_models.dart';

String _fmtFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

String _fmtQty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

bw.Barcode _barcodeDe(String? tipo, {bool forzarQr = false}) {
  if (forzarQr) return bw.Barcode.qrCode();
  switch ((tipo ?? '').toUpperCase()) {
    case 'EAN13':
      return bw.Barcode.ean13();
    case 'EAN8':
      return bw.Barcode.ean8();
    case 'UPC':
      return bw.Barcode.upcA();
    case 'QR':
      return bw.Barcode.qrCode();
    case 'CODE128':
    default:
      return bw.Barcode.code128();
  }
}

Alignment _alignmentDe(String alineacion) {
  switch (alineacion) {
    case AlineacionEtiqueta.centro:
      return Alignment.center;
    case AlineacionEtiqueta.derecha:
      return Alignment.centerRight;
    case AlineacionEtiqueta.izquierda:
    default:
      return Alignment.centerLeft;
  }
}

TextAlign _textAlignDe(String alineacion) {
  switch (alineacion) {
    case AlineacionEtiqueta.centro:
      return TextAlign.center;
    case AlineacionEtiqueta.derecha:
      return TextAlign.right;
    case AlineacionEtiqueta.izquierda:
    default:
      return TextAlign.left;
  }
}

Widget _linea(String texto, String alineacion, TextStyle style) {
  return Align(
    alignment: _alignmentDe(alineacion),
    child: Text(texto, textAlign: _textAlignDe(alineacion), maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
  );
}

Widget _barcodeWidget(String data, String? tipo, String alineacion, {bool forzarQr = false}) {
  return Align(
    alignment: _alignmentDe(alineacion),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: bw.BarcodeWidget(
        barcode: _barcodeDe(tipo, forzarQr: forzarQr),
        data: data,
        height: 40,
        drawText: !forzarQr,
        style: const TextStyle(fontSize: 9),
        errorBuilder: (context, error) => Text(data, style: const TextStyle(fontSize: 10)),
      ),
    ),
  );
}

/// Aproximación visual de cómo va a quedar la etiqueta física — mismo orden
/// de campos y alineación que la plantilla asignada (`EtiquetaTemplate`,
/// catálogo reusable) y misma proporción ancho/alto que el ZPL real
/// (`construirZplEtiqueta`), para poder revisar el layout sin gastar una
/// etiqueta física en cada prueba. No es un render pixel-perfect de lo que
/// hace la impresora (fuente/espaciados de la impresora pueden variar), es
/// una guía de "qué campo va dónde, en qué orden y con qué alineación".
/// **No refleja la rotación 90° real de la impresión** (ver
/// `construirZplEtiqueta` en `impresora_service.dart`) — a propósito, para
/// que la vista previa se lea de la forma más natural en pantalla; solo la
/// impresión física sale rotada.
class EtiquetaPreview extends StatelessWidget {
  const EtiquetaPreview({
    super.key,
    required this.etiqueta,
    required this.plantilla,
    this.pesoManualKg,
    this.anchoMaximo = 300,
  });

  final EtiquetaProduccion etiqueta;
  final EtiquetaTemplate plantilla;

  /// Valor de ejemplo/real para un campo CANTIDAD en modo PESAR.
  final double? pesoManualKg;
  final double anchoMaximo;

  @override
  Widget build(BuildContext context) {
    final relacion = plantilla.anchoMm <= 0 ? 1.0 : plantilla.altoMm / plantilla.anchoMm;
    final ancho = anchoMaximo;
    final alto = ancho * relacion;
    final hoy = DateTime.now();

    final filas = <Widget>[];

    for (final item in plantilla.campos) {
      switch (item.campo) {
        case CampoEtiqueta.producto:
          filas.add(_linea(
            etiqueta.producto,
            item.alineacion,
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black),
          ));
          break;
        case CampoEtiqueta.marca:
          if (etiqueta.marca?.trim().isNotEmpty ?? false) {
            filas.add(_linea(etiqueta.marca!, item.alineacion, const TextStyle(fontSize: 11, color: Colors.black87)));
          }
          break;
        case CampoEtiqueta.lote:
          filas.add(_linea('Lote: ${etiqueta.loteInterno}', item.alineacion, const TextStyle(fontSize: 10.5, color: Colors.black87)));
          break;
        case CampoEtiqueta.codigoBarra:
          if (etiqueta.codigoBarra?.trim().isNotEmpty ?? false) {
            filas.add(_barcodeWidget(etiqueta.codigoBarra!, etiqueta.tipoCodigo, item.alineacion));
          }
          break;
        case CampoEtiqueta.codigoQr:
          if (etiqueta.codigoBarra?.trim().isNotEmpty ?? false) {
            filas.add(_barcodeWidget(etiqueta.codigoBarra!, etiqueta.tipoCodigo, item.alineacion, forzarQr: true));
          }
          break;
        case CampoEtiqueta.cantidad:
          final texto = switch (item.cantidadModo) {
            'FIJO' => (item.cantidadTextoFijo?.trim().isNotEmpty ?? false) ? item.cantidadTextoFijo : null,
            'PESAR' => pesoManualKg != null ? '${_fmtQty(pesoManualKg!)} Kg' : '(a pesar)',
            _ => '${_fmtQty(etiqueta.cantidad)} ${etiqueta.unidad}',
          };
          if (texto != null) {
            filas.add(_linea(texto, item.alineacion, const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.black)));
          }
          break;
        case CampoEtiqueta.fechaEmbalaje:
          filas.add(_linea('Embalado: ${_fmtFecha(hoy)}', item.alineacion, const TextStyle(fontSize: 10.5, color: Colors.black87)));
          break;
        case CampoEtiqueta.fechaVencimiento:
          if (etiqueta.fechaVencimiento != null) {
            filas.add(_linea('Vence: ${_fmtFecha(etiqueta.fechaVencimiento!)}', item.alineacion, const TextStyle(fontSize: 10.5, color: Colors.black87)));
          }
          break;
        case CampoEtiqueta.observacion:
          if (item.observacionTexto?.trim().isNotEmpty ?? false) {
            filas.add(_linea(item.observacionTexto!, item.alineacion, const TextStyle(fontSize: 9.5, color: Colors.black54)));
          }
          break;
        case CampoEtiqueta.rspa:
          if (item.rspaTexto?.trim().isNotEmpty ?? false) {
            filas.add(_linea(item.rspaTexto!, item.alineacion, const TextStyle(fontSize: 9.5, color: Colors.black87)));
          }
          break;
      }
    }

    return Container(
      width: ancho,
      height: alto,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filas),
      ),
    );
  }
}
