/// Parseo defensivo de respuestas del backend: la mayoría de los endpoints
/// de stock devuelven `Decimal` de MySQL serializado como número JSON, pero
/// algunos (`/stock/kpis`, `/stock/valorizacion`) lo devuelven como string
/// explícito (ver `stock_service.py`). Aceptar ambos evita crashes si el
/// backend cambia la serialización de un endpoint puntual.
double parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  return parseDouble(value);
}

DateTime? parseDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

String formatFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year}';
}

/// "dd/mm/aa - hh.mm hs" — usado donde la hora del dato importa (ej. ETA de
/// un pedido), a diferencia de `formatFecha` que es solo fecha.
String formatFechaHora(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  final a = (fecha.year % 100).toString().padLeft(2, '0');
  final h = fecha.hour.toString().padLeft(2, '0');
  final min = fecha.minute.toString().padLeft(2, '0');
  return '$d/$m/$a - $h.$min hs';
}

/// Formato guaraníes: "Gs. 150.000" si es entero (el caso normal — el Gs no
/// tiene submúltiplo de uso corriente), o "Gs. 150.000,50" si de verdad
/// tiene centavos (ej. un precio cargado con decimales). Sin paquete `intl`
/// (no es dependencia del proyecto) — separador de miles armado a mano.
String formatGs(double valor) {
  final negativo = valor < 0;
  final absoluto = valor.abs();
  final parteEntera = absoluto.truncate();
  final enteroStr = parteEntera.toString();

  final buffer = StringBuffer();
  for (var i = 0; i < enteroStr.length; i++) {
    if (i > 0 && (enteroStr.length - i) % 3 == 0) buffer.write('.');
    buffer.write(enteroStr[i]);
  }

  final signo = negativo ? '-' : '';
  final esEntero = absoluto == parteEntera.toDouble();
  if (esEntero) {
    return 'Gs. $signo${buffer.toString()}';
  }

  final decimales = ((absoluto - parteEntera) * 100).round().toString().padLeft(
    2,
    '0',
  );
  return 'Gs. $signo${buffer.toString()},$decimales';
}

/// Formatea una cantidad de stock según si su unidad de medida es
/// `pesable` (`unidades.pesable` — kg, litros, etc.): solo esas unidades
/// pueden mostrar parte decimal, el resto siempre se redondea a entero
/// aunque el dato de origen traiga ruido de coma flotante. Redondea a 3
/// decimales antes de decidir si hay parte fraccionaria real, para no
/// mostrar basura tipo "12.000000000001" por errores de precisión.
String formatCantidad(double valor, {required bool pesable}) {
  if (!pesable) return valor.round().toString();
  final redondeado = double.parse(valor.toStringAsFixed(3));
  return redondeado == redondeado.roundToDouble()
      ? redondeado.toStringAsFixed(0)
      : redondeado.toString();
}
