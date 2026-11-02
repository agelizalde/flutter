import 'produccion_models.dart';

String _fmtFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

String _fmtQty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Texto que imprime un elemento de texto del diseño (`EtiquetaElemento`,
/// tipo 'dato' o 'texto') para una etiqueta real — mismo criterio que
/// `valorElemento` del diseñador web: `prefijo` + valor del dato. `null` si
/// no hay nada para imprimir (dato vacío, o CANTIDAD a pesar sin peso
/// todavía). Con [vistaPrevia] la cantidad a pesar sin peso se muestra como
/// "(a pesar)" en vez de omitirse.
String? textoElementoEtiqueta(
  EtiquetaElemento el,
  EtiquetaProduccion etq, {
  double? pesoManualKg,
  DateTime? hoy,
  bool vistaPrevia = false,
}) {
  String? limpio(String? v) => (v?.trim().isNotEmpty ?? false) ? v : null;
  if (el.tipo == 'texto') return limpio(el.texto);
  if (el.tipo != 'dato') return null;

  String? valor;
  switch (el.campo) {
    case CampoEtiqueta.producto:
      valor = limpio(etq.producto);
      break;
    case CampoEtiqueta.marca:
      valor = limpio(etq.marca);
      break;
    case CampoEtiqueta.lote:
      valor = limpio(etq.loteInterno);
      break;
    case CampoEtiqueta.cantidad:
      switch (el.cantidadModo) {
        case 'FIJO':
          valor = limpio(el.cantidadTextoFijo);
          break;
        case 'PESAR':
          valor = pesoManualKg != null ? '${_fmtQty(pesoManualKg)} Kg' : (vistaPrevia ? '(a pesar)' : null);
          break;
        default:
          valor = '${_fmtQty(etq.cantidad)} ${etq.unidad}';
      }
      break;
    case CampoEtiqueta.fechaEmbalaje:
      valor = _fmtFecha(hoy ?? DateTime.now());
      break;
    case CampoEtiqueta.fechaVencimiento:
      valor = etq.fechaVencimiento != null ? _fmtFecha(etq.fechaVencimiento!) : null;
      break;
    case CampoEtiqueta.observacion:
    case CampoEtiqueta.rspa:
      return limpio(el.texto);
  }
  if (valor == null) return null;
  return '${el.prefijo ?? ''}$valor';
}

/// La plantilla pide pesar cada paquete (CANTIDAD en modo PESAR), ya sea en
/// el diseño o en la lista de campos del auto-ajuste.
bool plantillaPidePeso(EtiquetaTemplate plantilla) {
  if (plantilla.layout != null) {
    return plantilla.elementosVisibles.any((e) => e.campo == CampoEtiqueta.cantidad && e.cantidadModo == 'PESAR');
  }
  return plantilla.campos.any((c) => c.campo == CampoEtiqueta.cantidad && c.cantidadModo == 'PESAR');
}
