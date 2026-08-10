/// Tamaños de rollo de etiqueta más comunes (ancho x alto en mm) — atajos
/// para no tener que calcular a mano; también se puede escribir cualquier
/// medida a mano en `ConfigurarImpresoraScreen`.
class TamanoEtiqueta {
  const TamanoEtiqueta(this.label, this.anchoMm, this.altoMm);

  final String label;
  final double anchoMm;
  final double altoMm;

  static const opciones = [
    TamanoEtiqueta('40 x 30 mm', 40, 30),
    TamanoEtiqueta('50 x 30 mm', 50, 30),
    TamanoEtiqueta('60 x 40 mm', 60, 40),
    TamanoEtiqueta('70 x 50 mm', 70, 50),
    TamanoEtiqueta('100 x 50 mm', 100, 50),
    TamanoEtiqueta('100 x 150 mm', 100, 150),
  ];
}

/// Configuración de la impresora de etiquetas (guardada localmente en el
/// dispositivo, no viene del backend) — conexión por red (WiFi) a una
/// impresora térmica de etiquetas (ej. Honeywell en modo de emulación ZPL,
/// el lenguaje más compatible entre marcas) vía socket TCP crudo al puerto
/// RAW estándar de impresión (9100, "JetDirect"), más el tamaño físico del
/// rollo cargado.
///
/// Qué campos imprimir, en qué orden y con qué alineación ya NO vive acá
/// (2026-07-14) — eso lo define la plantilla de etiqueta asignada a la
/// receta (`EtiquetaTemplate`, catálogo reusable configurado en la web en
/// Producción → Etiquetas), no el dispositivo. Incluso el tamaño físico
/// usado al imprimir sale de la plantilla (`EtiquetaTemplate.anchoMm`/
/// `altoMm`, ver `impresora_service.dart::construirZplEtiqueta`) — los
/// campos de acá solo importan para la conexión (`ip`/`puerto`) y como
/// tamaño de referencia al configurar el dispositivo.
class ImpresoraConfig {
  const ImpresoraConfig({
    this.ip,
    this.puerto = 9100,
    this.anchoMm = 60,
    this.altoMm = 40,
  });

  final String? ip;
  final int puerto;

  /// Tamaño físico del rollo de etiqueta — define `^PW`/`^LL` en el ZPL
  /// generado (ver `impresora_service.dart`).
  final double anchoMm;
  final double altoMm;

  bool get configurada => ip != null && ip!.trim().isNotEmpty;

  ImpresoraConfig copyWith({
    String? ip,
    int? puerto,
    double? anchoMm,
    double? altoMm,
  }) {
    return ImpresoraConfig(
      ip: ip ?? this.ip,
      puerto: puerto ?? this.puerto,
      anchoMm: anchoMm ?? this.anchoMm,
      altoMm: altoMm ?? this.altoMm,
    );
  }
}
