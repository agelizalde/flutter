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

  final decimales = ((absoluto - parteEntera) * 100).round().toString().padLeft(2, '0');
  return 'Gs. $signo${buffer.toString()},$decimales';
}
