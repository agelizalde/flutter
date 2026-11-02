import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/parsing.dart';

/// Insignia de "nivel" según cuántas veces se produjo una receta — mismo
/// criterio que `tierInfo()` en la web (`RecetaDetallePage.jsx`): Nueva (0),
/// Bronce (>=1), Plata (>=5), Oro (>=15). Puramente cosmético/gamificado,
/// no viene del backend.
class TierInfo {
  const TierInfo(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

TierInfo tierInfoFor(int vecesProducida) {
  if (vecesProducida >= 15) return const TierInfo('Oro', Icons.emoji_events, Color(0xFFCA8A04));
  if (vecesProducida >= 5) return const TierInfo('Plata', Icons.workspace_premium, Color(0xFF64748B));
  if (vecesProducida >= 1) return const TierInfo('Bronce', Icons.military_tech, Color(0xFFC2703D));
  return const TierInfo('Nueva', Icons.auto_awesome, Color(0xFF6366F1));
}

/// Fila de `GET /produccion/recetas` (ver `receta_service.py::recetas_list`).
class RecetaResumen {
  RecetaResumen({
    required this.idReceta,
    required this.codigo,
    required this.nombre,
    this.productoPrincipalNombre,
    this.productoReferenciaNombre,
    required this.tiempoReferenciaSegundos,
    required this.usuariosRequeridos,
    required this.vecesProducida,
    required this.activo,
  });

  factory RecetaResumen.fromJson(Map<String, dynamic> j) => RecetaResumen(
    idReceta: j['id_receta'] as int,
    codigo: j['codigo'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    productoPrincipalNombre: j['producto_principal_nombre'] as String?,
    productoReferenciaNombre: j['producto_referencia_nombre'] as String?,
    tiempoReferenciaSegundos: j['tiempo_referencia_segundos'] as int? ?? 0,
    usuariosRequeridos: j['usuarios_requeridos'] as int? ?? 1,
    vecesProducida: j['veces_producida'] as int? ?? 0,
    activo: j['activo'] as bool? ?? true,
  );

  final int idReceta;
  final String codigo;
  final String nombre;
  final String? productoPrincipalNombre;
  final String? productoReferenciaNombre;
  final int tiempoReferenciaSegundos;
  final int usuariosRequeridos;
  final int vecesProducida;
  final bool activo;
}

/// Fila de `produccion_recetas_consumo` (ver `receta_service.py::_consumo_of`).
class RecetaLineaConsumo {
  RecetaLineaConsumo({
    required this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.esReferencia,
    required this.cantidadPorReferencia,
  });

  factory RecetaLineaConsumo.fromJson(Map<String, dynamic> j) => RecetaLineaConsumo(
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    unidadSimbolo: (j['unidad_simbolo'] as String?)?.isNotEmpty == true
        ? j['unidad_simbolo'] as String
        : (j['unidad_nombre'] as String? ?? ''),
    esReferencia: j['es_referencia'] as bool? ?? false,
    cantidadPorReferencia: parseDouble(j['cantidad_por_referencia']),
  );

  final int idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final bool esReferencia;
  final double cantidadPorReferencia;
}

/// Fila de `produccion_recetas_resultado` (ver `receta_service.py::_resultado_of`).
class RecetaLineaResultado {
  RecetaLineaResultado({
    required this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.esPrincipal,
    required this.cantidadPorReferencia,
    this.diasVencimiento,
  });

  factory RecetaLineaResultado.fromJson(Map<String, dynamic> j) => RecetaLineaResultado(
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    unidadSimbolo: (j['unidad_simbolo'] as String?)?.isNotEmpty == true
        ? j['unidad_simbolo'] as String
        : (j['unidad_nombre'] as String? ?? ''),
    esPrincipal: j['es_principal'] as bool? ?? false,
    cantidadPorReferencia: parseDouble(j['cantidad_por_referencia']),
    diasVencimiento: j['dias_vencimiento'] as int?,
  );

  final int idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final bool esPrincipal;
  final double cantidadPorReferencia;
  final int? diasVencimiento;
}

/// Fila de `produccion_recetas_mermas` — `idProducto` null = merma genérica
/// sin stock propio (ver `receta_service.py::_mermas_of`).
class RecetaLineaMerma {
  RecetaLineaMerma({
    this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.cantidadPorReferencia,
  });

  factory RecetaLineaMerma.fromJson(Map<String, dynamic> j) => RecetaLineaMerma(
    idProducto: j['id_producto'] as int?,
    productoNombre: j['producto_nombre'] as String? ?? 'Merma genérica',
    unidadSimbolo: (j['unidad_simbolo'] as String?)?.isNotEmpty == true
        ? j['unidad_simbolo'] as String
        : (j['unidad_nombre'] as String? ?? ''),
    cantidadPorReferencia: parseDouble(j['cantidad_por_referencia']),
  );

  final int? idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final double cantidadPorReferencia;
}

/// Claves de `produccion_etiquetas_campos.campo` (ver
/// `etiqueta_service.py::CampoEtiquetaLiteral`) — catálogo fijo de 10 campos
/// posibles en una plantilla de etiqueta.
class CampoEtiqueta {
  static const producto = 'PRODUCTO';
  static const marca = 'MARCA';
  static const lote = 'LOTE';
  static const codigoBarra = 'CODIGO_BARRA';
  static const codigoQr = 'CODIGO_QR';
  static const cantidad = 'CANTIDAD';
  static const fechaEmbalaje = 'FECHA_EMBALAJE';
  static const fechaVencimiento = 'FECHA_VENCIMIENTO';
  static const observacion = 'OBSERVACION';

  /// Registro sanitario/habilitación del establecimiento (ej. SENACSA en
  /// Paraguay) — texto fijo por plantilla, agregado 2026-07-15 a partir de
  /// un ZPL real que ya usaba el usuario.
  static const rspa = 'RSPA';
}

/// Alineación de una línea de la etiqueta (ver
/// `etiqueta_service.py::AlineacionLiteral`).
class AlineacionEtiqueta {
  static const izquierda = 'IZQUIERDA';
  static const centro = 'CENTRO';
  static const derecha = 'DERECHA';
}

/// Fila de `produccion_etiquetas_campos` — un campo activo de la plantilla,
/// EN ORDEN (la posición en `EtiquetaTemplate.campos` es el orden real de
/// impresión). Un campo del catálogo ausente de esa lista simplemente no se
/// imprime.
class EtiquetaCampoTemplate {
  EtiquetaCampoTemplate({
    required this.campo,
    this.alineacion = AlineacionEtiqueta.izquierda,
    this.cantidadModo,
    this.cantidadTextoFijo,
    this.observacionTexto,
    this.rspaTexto,
  });

  factory EtiquetaCampoTemplate.fromJson(Map<String, dynamic> j) => EtiquetaCampoTemplate(
    campo: j['campo'] as String,
    alineacion: j['alineacion'] as String? ?? AlineacionEtiqueta.izquierda,
    cantidadModo: j['cantidad_modo'] as String?,
    cantidadTextoFijo: j['cantidad_texto_fijo'] as String?,
    observacionTexto: j['observacion_texto'] as String?,
    rspaTexto: j['rspa_texto'] as String?,
  );

  /// Uno de `CampoEtiqueta`.
  final String campo;

  /// Uno de `AlineacionEtiqueta`.
  final String alineacion;

  /// Solo si `campo == CampoEtiqueta.cantidad`: 'REAL' | 'FIJO' | 'PESAR'.
  final String? cantidadModo;

  /// Solo si `cantidadModo == 'FIJO'`.
  final String? cantidadTextoFijo;

  /// Solo si `campo == CampoEtiqueta.observacion`.
  final String? observacionTexto;

  /// Solo si `campo == CampoEtiqueta.rspa`.
  final String? rspaTexto;
}

/// Resumen embebido en `GET /produccion/recetas/{id}` (campo `etiqueta`, ver
/// `receta_service.py::_etiqueta_resumen`) — solo lo necesario para mostrar
/// qué plantilla tiene asignada la receta y buscar su detalle completo
/// (`ProduccionApi.obtenerEtiqueta`) cuando haga falta imprimir.
class EtiquetaResumen {
  EtiquetaResumen({
    required this.idEtiqueta,
    required this.nombre,
    required this.anchoMm,
    required this.altoMm,
  });

  factory EtiquetaResumen.fromJson(Map<String, dynamic> j) => EtiquetaResumen(
    idEtiqueta: j['id_etiqueta'] as int,
    nombre: j['nombre'] as String? ?? '',
    anchoMm: parseDouble(j['ancho_mm']),
    altoMm: parseDouble(j['alto_mm']),
  );

  final int idEtiqueta;
  final String nombre;
  final double anchoMm;
  final double altoMm;
}

/// Un elemento del diseño de la etiqueta (`produccion_etiquetas.layout_json`,
/// ver `etiqueta_service.py::LayoutElementoIn` y el diseñador web
/// `ajustes/produccion/etiquetas/etiquetaDiseno.js`). Medidas en mm dentro
/// del área útil (sin márgenes), en el sentido en que se LEE la etiqueta;
/// x/y = esquina superior izquierda.
class EtiquetaElemento {
  EtiquetaElemento({
    required this.id,
    required this.tipo,
    this.campo,
    required this.x,
    required this.y,
    required this.w,
    this.h = 0,
    this.size = 10,
    this.bold = false,
    this.align = 'left',
    this.lineas = 1,
    this.prefijo,
    this.texto,
    this.visible = true,
    this.grosor = 0.3,
    this.mostrarNumero = true,
    this.cantidadModo,
    this.cantidadTextoFijo,
  });

  factory EtiquetaElemento.fromJson(Map<String, dynamic> j) => EtiquetaElemento(
    id: j['id']?.toString() ?? '',
    tipo: j['tipo'] as String? ?? 'texto',
    campo: j['campo'] as String?,
    x: parseDouble(j['x']),
    y: parseDouble(j['y']),
    w: parseDouble(j['w']),
    h: parseDouble(j['h']),
    size: j['size'] == null ? 10 : parseDouble(j['size']),
    bold: j['bold'] == true,
    align: j['align'] as String? ?? 'left',
    lineas: (j['lineas'] as num?)?.toInt() ?? 1,
    prefijo: j['prefijo'] as String?,
    texto: j['texto'] as String?,
    visible: j['visible'] != false,
    grosor: j['grosor'] == null ? 0.3 : parseDouble(j['grosor']),
    mostrarNumero: j['mostrar_numero'] != false,
    cantidadModo: j['cantidad_modo'] as String?,
    cantidadTextoFijo: j['cantidad_texto_fijo'] as String?,
  );

  final String id;

  /// 'dato' | 'texto' | 'barra' | 'qr' | 'linea_h' | 'linea_v' | 'rect'.
  final String tipo;

  /// Solo si `tipo == 'dato'`: uno de `CampoEtiqueta` (salvo barra/QR).
  final String? campo;
  final double x;
  final double y;
  final double w;
  final double h;

  /// Letra en puntos (texto).
  final double size;
  final bool bold;

  /// 'left' | 'center' | 'right'.
  final String align;
  final int lineas;
  final String? prefijo;

  /// Texto libre, OBSERVACION o RSPA.
  final String? texto;
  final bool visible;
  final double grosor;
  final bool mostrarNumero;
  final String? cantidadModo;
  final String? cantidadTextoFijo;

  bool get esTexto => tipo == 'dato' || tipo == 'texto';

  /// Alto de la caja de texto: renglones × letra × interlineado 1,2.
  double get altoTexto => lineas * size * 0.3528 * 1.2;

  EtiquetaElemento escalado(double sx, double sy) {
    final s = math.min(sx, sy);
    return EtiquetaElemento(
      id: id,
      tipo: tipo,
      campo: campo,
      x: x * sx,
      y: y * sy,
      w: tipo == 'qr' ? w * s : (tipo == 'linea_v' ? w : w * sx),
      h: h * sy,
      size: esTexto ? math.max(4, size * s) : size,
      bold: bold,
      align: align,
      lineas: lineas,
      prefijo: prefijo,
      texto: texto,
      visible: visible,
      grosor: grosor,
      mostrarNumero: mostrarNumero,
      cantidadModo: cantidadModo,
      cantidadTextoFijo: cantidadTextoFijo,
    );
  }
}

/// `layout_json` de la plantilla: elementos + tamaño del área útil con que se
/// diseñaron (si después cambió el tamaño o los márgenes se reescala).
class EtiquetaLayout {
  EtiquetaLayout({required this.refAncho, required this.refAlto, required this.elementos});

  factory EtiquetaLayout.fromJson(Map<String, dynamic> j) => EtiquetaLayout(
    refAncho: parseDouble(j['ref_ancho']),
    refAlto: parseDouble(j['ref_alto']),
    elementos: (j['elementos'] as List? ?? [])
        .whereType<Map>()
        .map((e) => EtiquetaElemento.fromJson(e.cast<String, dynamic>()))
        .toList(),
  );

  final double refAncho;
  final double refAlto;
  final List<EtiquetaElemento> elementos;
}

/// Detalle completo de `GET /produccion/etiquetas/{id}` (ver
/// `etiqueta_service.py::_build_full`) — la plantilla reusable de impresión.
/// Antes esto vivía embebido por receta (`produccion_recetas_etiqueta_campos`,
/// 2026-07-14); ahora es un catálogo aparte (`produccion_etiquetas`,
/// 2026-07-15) y la receta solo guarda una referencia
/// (`RecetaDetalle.etiqueta.idEtiqueta`).
///
/// Desde el diseñador web (2026-11-02) puede traer `layout`: elementos con
/// posición/tamaño propios. Sin `layout` se imprime con el auto-ajuste de
/// siempre a partir de `campos` (que el backend mantiene sincronizados).
class EtiquetaTemplate {
  EtiquetaTemplate({
    required this.idEtiqueta,
    required this.nombre,
    required this.anchoMm,
    required this.altoMm,
    required this.campos,
    this.rotacion = 90,
    this.margenSuperior = 2,
    this.margenInferior = 2,
    this.margenIzquierdo = 2,
    this.margenDerecho = 2,
    this.layout,
  });

  factory EtiquetaTemplate.fromJson(Map<String, dynamic> j) {
    final lay = j['layout_json'];
    return EtiquetaTemplate(
      idEtiqueta: j['id_etiqueta'] as int,
      nombre: j['nombre'] as String? ?? '',
      anchoMm: parseDouble(j['ancho_mm']),
      altoMm: parseDouble(j['alto_mm']),
      campos: (j['campos'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(EtiquetaCampoTemplate.fromJson)
          .toList(),
      rotacion: (j['rotacion'] as num?)?.toInt() ?? 90,
      margenSuperior: j['margen_superior'] == null ? 2 : parseDouble(j['margen_superior']),
      margenInferior: j['margen_inferior'] == null ? 2 : parseDouble(j['margen_inferior']),
      margenIzquierdo: j['margen_izquierdo'] == null ? 2 : parseDouble(j['margen_izquierdo']),
      margenDerecho: j['margen_derecho'] == null ? 2 : parseDouble(j['margen_derecho']),
      layout: lay is Map ? EtiquetaLayout.fromJson(lay.cast<String, dynamic>()) : null,
    );
  }

  final int idEtiqueta;
  final String nombre;

  /// Rollo FÍSICO: ancho = `^PW`, alto = `^LL`.
  final double anchoMm;
  final double altoMm;
  final List<EtiquetaCampoTemplate> campos;

  /// Giro de la impresión, de a 90° horario: 0 = derecha, 90/270 = de
  /// costado respecto del avance del papel, 180 = al revés (rollo que llega
  /// con las etiquetas dadas vuelta).
  final int rotacion;

  /// Márgenes en el sentido de lectura.
  final double margenSuperior;
  final double margenInferior;
  final double margenIzquierdo;
  final double margenDerecho;
  final EtiquetaLayout? layout;

  bool get deCostado => rotacion % 180 == 90;

  /// Tamaño en el sentido de lectura (con 90°/270° se intercambian).
  double get anchoLectura => deCostado ? altoMm : anchoMm;
  double get altoLectura => deCostado ? anchoMm : altoMm;
  double get areaAncho => anchoLectura - margenIzquierdo - margenDerecho;
  double get areaAlto => altoLectura - margenSuperior - margenInferior;

  /// Elementos visibles del diseño llevados al área útil actual.
  List<EtiquetaElemento> get elementosVisibles {
    final lay = layout;
    if (lay == null) return const [];
    final sx = lay.refAncho > 0 ? areaAncho / lay.refAncho : 1.0;
    final sy = lay.refAlto > 0 ? areaAlto / lay.refAlto : 1.0;
    final reescalar = (sx - 1).abs() > 0.001 || (sy - 1).abs() > 0.001;
    return lay.elementos.where((e) => e.visible).map((e) => reescalar ? e.escalado(sx, sy) : e).toList();
  }
}

/// Detalle completo de `GET /produccion/recetas/{id}` — la "ficha" de la
/// receta, usada para armar el cartel de "todo lo que necesita" antes de
/// producir (ver `NuevaOrdenScreen`) y la plantilla de etiqueta al imprimir.
class RecetaDetalle {
  RecetaDetalle({
    required this.idReceta,
    required this.codigo,
    required this.nombre,
    this.descripcion,
    required this.tiempoReferenciaSegundos,
    required this.usuariosRequeridos,
    required this.vecesProducida,
    required this.consumo,
    required this.resultado,
    required this.mermas,
    this.etiqueta,
  });

  factory RecetaDetalle.fromJson(Map<String, dynamic> j) => RecetaDetalle(
    idReceta: j['id_receta'] as int,
    codigo: j['codigo'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    descripcion: j['descripcion'] as String?,
    tiempoReferenciaSegundos: j['tiempo_referencia_segundos'] as int? ?? 0,
    usuariosRequeridos: j['usuarios_requeridos'] as int? ?? 1,
    vecesProducida: j['veces_producida'] as int? ?? 0,
    consumo: (j['consumo'] as List).cast<Map<String, dynamic>>().map(RecetaLineaConsumo.fromJson).toList(),
    resultado: (j['resultado'] as List).cast<Map<String, dynamic>>().map(RecetaLineaResultado.fromJson).toList(),
    mermas: (j['mermas'] as List).cast<Map<String, dynamic>>().map(RecetaLineaMerma.fromJson).toList(),
    etiqueta: j['etiqueta'] != null ? EtiquetaResumen.fromJson(j['etiqueta'] as Map<String, dynamic>) : null,
  );

  final int idReceta;
  final String codigo;
  final String nombre;
  final String? descripcion;
  final int tiempoReferenciaSegundos;
  final int usuariosRequeridos;
  final int vecesProducida;
  final List<RecetaLineaConsumo> consumo;
  final List<RecetaLineaResultado> resultado;
  final List<RecetaLineaMerma> mermas;

  /// Plantilla de etiqueta asignada (`produccion_recetas.id_etiqueta`) — solo
  /// el resumen (id/nombre/dimensiones); el detalle completo con campos se
  /// busca aparte con `ProduccionApi.obtenerEtiqueta(etiqueta.idEtiqueta)`.
  final EtiquetaResumen? etiqueta;

  RecetaLineaConsumo? get referencia {
    for (final c in consumo) {
      if (c.esReferencia) return c;
    }
    return null;
  }

  RecetaLineaResultado? get principal {
    for (final r in resultado) {
      if (r.esPrincipal) return r;
    }
    return null;
  }
}

/// Fila escalada de `POST /produccion/ordenes/preview` (ver
/// `orden_service.py::calcular_estimado`) — sin nombre/unidad, solo
/// cantidad; se combina por posición con `RecetaDetalle.consumo/resultado`
/// (misma query, mismo ORDER BY en el backend, así que el índice coincide).
class PreviewLinea {
  PreviewLinea({required this.idProducto, required this.cantidadPlanificada});

  factory PreviewLinea.fromJson(Map<String, dynamic> j) => PreviewLinea(
    idProducto: j['id_producto'] as int?,
    cantidadPlanificada: parseDouble(j['cantidad_planificada']),
  );

  final int? idProducto;
  final double cantidadPlanificada;
}

/// Respuesta de `POST /produccion/ordenes/preview`.
class OrdenPreview {
  OrdenPreview({
    required this.idReceta,
    required this.cantidadReferenciaReal,
    required this.tiempoEstimadoSegundos,
    required this.usuariosRequeridos,
    required this.consumo,
    required this.resultado,
    required this.mermas,
  });

  factory OrdenPreview.fromJson(Map<String, dynamic> j) => OrdenPreview(
    idReceta: j['id_receta'] as int,
    cantidadReferenciaReal: parseDouble(j['cantidad_referencia_real']),
    tiempoEstimadoSegundos: j['tiempo_estimado_segundos'] as int? ?? 0,
    usuariosRequeridos: j['usuarios_requeridos'] as int? ?? 1,
    consumo: (j['consumo'] as List).cast<Map<String, dynamic>>().map(PreviewLinea.fromJson).toList(),
    resultado: (j['resultado'] as List).cast<Map<String, dynamic>>().map(PreviewLinea.fromJson).toList(),
    mermas: (j['mermas'] as List).cast<Map<String, dynamic>>().map(PreviewLinea.fromJson).toList(),
  );

  final int idReceta;
  final double cantidadReferenciaReal;
  final int tiempoEstimadoSegundos;
  final int usuariosRequeridos;
  final List<PreviewLinea> consumo;
  final List<PreviewLinea> resultado;
  final List<PreviewLinea> mermas;
}

/// Fila de `GET /produccion/ordenes` (listado, ver `orden_service.py::ordenes_list`).
class OrdenListItem {
  OrdenListItem({
    required this.idOrden,
    required this.codigo,
    required this.idReceta,
    required this.recetaNombre,
    required this.estado,
    required this.cantidadReferenciaReal,
    this.productoPrincipalNombre,
    required this.tiempoEstimadoSegundos,
    this.tiempoRealSegundos,
    this.tiempoTranscurridoSegundos = 0,
    this.creadoEn,
    this.finalizadoEn,
  });

  factory OrdenListItem.fromJson(Map<String, dynamic> j) => OrdenListItem(
    idOrden: j['id_orden'] as int,
    codigo: j['codigo'] as String? ?? '',
    idReceta: j['id_receta'] as int,
    recetaNombre: j['receta_nombre'] as String? ?? '',
    estado: j['estado'] as String? ?? 'BORRADOR',
    cantidadReferenciaReal: parseDouble(j['cantidad_referencia_real']),
    productoPrincipalNombre: j['producto_principal_nombre'] as String?,
    tiempoEstimadoSegundos: j['tiempo_estimado_segundos'] as int? ?? 0,
    tiempoRealSegundos: j['tiempo_real_segundos'] as int?,
    tiempoTranscurridoSegundos: j['tiempo_transcurrido_segundos'] as int? ?? 0,
    creadoEn: parseDateOrNull(j['creado_en']),
    finalizadoEn: parseDateOrNull(j['finalizado_en']),
  );

  final int idOrden;
  final String codigo;
  final int idReceta;
  final String recetaNombre;

  /// 'BORRADOR' | 'EN_PROCESO' | 'PAUSADA' | 'FINALIZADA' | 'ANULADA'
  final String estado;
  final double cantidadReferenciaReal;
  final String? productoPrincipalNombre;
  final int tiempoEstimadoSegundos;
  final int? tiempoRealSegundos;

  /// Suma de intervalos al momento de listar (incluye el abierto si está
  /// EN_PROCESO) — base del cronómetro de "Retomar" en el Home.
  final int tiempoTranscurridoSegundos;
  final DateTime? creadoEn;
  final DateTime? finalizadoEn;
}

/// Fila de `produccion_ordenes_consumo` (ver `orden_service.py::_consumo_of`).
class OrdenLineaConsumo {
  OrdenLineaConsumo({
    required this.idOrdenConsumo,
    required this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.esReferencia,
    required this.cantidadPlanificada,
    this.cantidadReal,
  });

  factory OrdenLineaConsumo.fromJson(Map<String, dynamic> j) => OrdenLineaConsumo(
    idOrdenConsumo: j['id_orden_consumo'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    unidadSimbolo: (j['unidad_simbolo'] as String?)?.isNotEmpty == true
        ? j['unidad_simbolo'] as String
        : (j['unidad_nombre'] as String? ?? ''),
    esReferencia: j['es_referencia'] as bool? ?? false,
    cantidadPlanificada: parseDouble(j['cantidad_planificada']),
    cantidadReal: parseDoubleOrNull(j['cantidad_real']),
  );

  final int idOrdenConsumo;
  final int idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final bool esReferencia;
  final double cantidadPlanificada;
  final double? cantidadReal;
}

/// Fila de `produccion_ordenes_resultado`.
class OrdenLineaResultado {
  OrdenLineaResultado({
    required this.idOrdenResultado,
    required this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.esPrincipal,
    required this.cantidadPlanificada,
    this.cantidadReal,
    this.diasVencimiento,
    this.loteInterno,
    this.fechaVencimiento,
    this.ubicacionNombre,
  });

  factory OrdenLineaResultado.fromJson(Map<String, dynamic> j) => OrdenLineaResultado(
    idOrdenResultado: j['id_orden_resultado'] as int,
    idProducto: j['id_producto'] as int,
    productoNombre: j['producto_nombre'] as String? ?? '',
    unidadSimbolo: (j['unidad_simbolo'] as String?)?.isNotEmpty == true
        ? j['unidad_simbolo'] as String
        : (j['unidad_nombre'] as String? ?? ''),
    esPrincipal: j['es_principal'] as bool? ?? false,
    cantidadPlanificada: parseDouble(j['cantidad_planificada']),
    cantidadReal: parseDoubleOrNull(j['cantidad_real']),
    diasVencimiento: j['dias_vencimiento'] as int?,
    loteInterno: j['lote_interno'] as String?,
    fechaVencimiento: parseDateOrNull(j['fecha_vencimiento']),
    ubicacionNombre: j['ubicacion_nombre'] as String?,
  );

  final int idOrdenResultado;
  final int idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final bool esPrincipal;
  final double cantidadPlanificada;
  final double? cantidadReal;
  final int? diasVencimiento;
  final String? loteInterno;

  /// Vencimiento real del lote generado (`lotes.fecha_vencimiento`) — a
  /// diferencia de `diasVencimiento`, que es el criterio de la receta.
  final DateTime? fechaVencimiento;

  /// Dónde quedó guardado ese lote (ver `orden_service.py::_resultado_of`)
  /// — puede variar entre líneas de la misma orden si el producto tiene
  /// ubicación automática configurada (`productos_almacenaje.id_ubicacion_automatica`).
  final String? ubicacionNombre;
}

/// Fila de `produccion_ordenes_mermas` — `idProducto` null = merma genérica.
class OrdenLineaMerma {
  OrdenLineaMerma({
    required this.idOrdenMerma,
    this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.cantidadPlanificada,
    this.cantidadReal,
  });

  factory OrdenLineaMerma.fromJson(Map<String, dynamic> j) => OrdenLineaMerma(
    idOrdenMerma: j['id_orden_merma'] as int,
    idProducto: j['id_producto'] as int?,
    productoNombre: j['producto_nombre'] as String? ?? 'Merma genérica',
    unidadSimbolo: (j['unidad_simbolo'] as String?)?.isNotEmpty == true
        ? j['unidad_simbolo'] as String
        : (j['unidad_nombre'] as String? ?? ''),
    cantidadPlanificada: parseDouble(j['cantidad_planificada']),
    cantidadReal: parseDoubleOrNull(j['cantidad_real']),
  );

  final int idOrdenMerma;
  final int? idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final double cantidadPlanificada;
  final double? cantidadReal;
}

/// Detalle completo de `GET /produccion/ordenes/{id}` (ver
/// `orden_service.py::_build_full`) — alimenta tanto la pantalla "en curso"
/// (cronómetro) como la de finalizar.
class OrdenProduccion {
  OrdenProduccion({
    required this.idOrden,
    required this.codigo,
    required this.idReceta,
    required this.idAlmacen,
    required this.estado,
    required this.cantidadReferenciaReal,
    required this.tiempoEstimadoSegundos,
    this.tiempoRealSegundos,
    required this.tiempoTranscurridoSegundos,
    required this.usuariosRequeridos,
    required this.rowVersion,
    required this.consumo,
    required this.resultado,
    required this.mermas,
    this.recetaNombre,
    this.almacenNombre,
    this.creadorNombre,
    this.operarioNombre,
    this.creadoEn,
    this.iniciadoEn,
    this.finalizadoEn,
    this.actualizadoEn,
    this.observaciones,
    this.motivoAnulacion,
  });

  factory OrdenProduccion.fromJson(Map<String, dynamic> j) => OrdenProduccion(
    idOrden: j['id_orden'] as int,
    codigo: j['codigo'] as String? ?? '',
    idReceta: j['id_receta'] as int,
    idAlmacen: j['id_almacen'] as int,
    estado: j['estado'] as String? ?? 'BORRADOR',
    cantidadReferenciaReal: parseDouble(j['cantidad_referencia_real']),
    tiempoEstimadoSegundos: j['tiempo_estimado_segundos'] as int? ?? 0,
    tiempoRealSegundos: j['tiempo_real_segundos'] as int?,
    tiempoTranscurridoSegundos: j['tiempo_transcurrido_segundos'] as int? ?? 0,
    usuariosRequeridos: j['usuarios_requeridos'] as int? ?? 1,
    rowVersion: j['row_version'] as int,
    consumo: (j['consumo'] as List).cast<Map<String, dynamic>>().map(OrdenLineaConsumo.fromJson).toList(),
    resultado: (j['resultado'] as List).cast<Map<String, dynamic>>().map(OrdenLineaResultado.fromJson).toList(),
    mermas: (j['mermas'] as List).cast<Map<String, dynamic>>().map(OrdenLineaMerma.fromJson).toList(),
    recetaNombre: j['receta_nombre'] as String?,
    almacenNombre: j['almacen_nombre'] as String?,
    creadorNombre: j['creador_nombre'] as String?,
    operarioNombre: j['operario_nombre'] as String?,
    creadoEn: parseDateOrNull(j['creado_en']),
    iniciadoEn: parseDateOrNull(j['iniciado_en']),
    finalizadoEn: parseDateOrNull(j['finalizado_en']),
    actualizadoEn: parseDateOrNull(j['actualizado_en']),
    observaciones: j['observaciones'] as String?,
    motivoAnulacion: j['motivo_anulacion'] as String?,
  );

  final int idOrden;
  final String codigo;
  final int idReceta;
  final int idAlmacen;

  /// 'BORRADOR' | 'EN_PROCESO' | 'PAUSADA' | 'FINALIZADA' | 'ANULADA'
  final String estado;
  final double cantidadReferenciaReal;
  final int tiempoEstimadoSegundos;
  final int? tiempoRealSegundos;
  final int tiempoTranscurridoSegundos;
  final int usuariosRequeridos;
  final int rowVersion;
  final List<OrdenLineaConsumo> consumo;
  final List<OrdenLineaResultado> resultado;
  final List<OrdenLineaMerma> mermas;

  final String? recetaNombre;
  final String? almacenNombre;

  /// Quién armó la orden — puede diferir de [operarioNombre] si otra
  /// persona la retomó/finalizó (`orden_service.py::ordenes_iniciar` fija
  /// el operario recién al iniciar el cronómetro).
  final String? creadorNombre;
  final String? operarioNombre;
  final DateTime? creadoEn;
  final DateTime? iniciadoEn;
  final DateTime? finalizadoEn;

  /// Fallback para "cuándo" cuando el estado terminal no pasó por
  /// `finalizar` (ej. ANULADA, que nunca completa `finalizadoEn`).
  final DateTime? actualizadoEn;
  final String? observaciones;
  final String? motivoAnulacion;
}

/// Resultado de `POST /produccion/ordenes` (solo lo que necesita el flujo
/// de la app: el id para encadenar `iniciar` y navegar al detalle).
class OrdenCreada {
  OrdenCreada({required this.idOrden, required this.codigo});

  factory OrdenCreada.fromJson(Map<String, dynamic> j) =>
      OrdenCreada(idOrden: j['id_orden'] as int, codigo: j['codigo'] as String? ?? '');

  final int idOrden;
  final String codigo;
}

/// Fila de `GET /produccion/ordenes/{id}/etiquetas` (ver
/// `orden_service.py::ordenes_etiquetas`) — todo lo necesario para imprimir
/// la etiqueta física de un lote producido, salvo el layout (eso lo define
/// la plantilla asignada a la receta, `RecetaDetalle.etiqueta`, buscada
/// aparte con `idReceta` → `EtiquetaResumen.idEtiqueta` →
/// `ProduccionApi.obtenerEtiqueta`). `marca`/`codigoBarra`/`tipoCodigo`
/// pueden ser `null` si el producto no los tiene configurados en su ficha.
class EtiquetaProduccion {
  EtiquetaProduccion({
    required this.idReceta,
    required this.loteInterno,
    required this.producto,
    this.marca,
    this.codigoBarra,
    this.tipoCodigo,
    required this.cantidad,
    required this.unidad,
    this.fechaVencimiento,
  });

  factory EtiquetaProduccion.fromJson(Map<String, dynamic> j) => EtiquetaProduccion(
    idReceta: j['id_receta'] as int,
    loteInterno: j['lote_interno'] as String? ?? '',
    producto: j['producto'] as String? ?? '',
    marca: j['marca'] as String?,
    codigoBarra: j['codigo_barra'] as String?,
    tipoCodigo: j['tipo_codigo'] as String?,
    cantidad: parseDouble(j['cantidad']),
    unidad: j['unidad'] as String? ?? '',
    fechaVencimiento: parseDateOrNull(j['fecha_vencimiento']),
  );

  final int idReceta;
  final String loteInterno;
  final String producto;
  final String? marca;
  final String? codigoBarra;

  /// 'EAN13' | 'EAN8' | 'UPC' | 'CODE128' | 'QR' | 'INTERNO' | 'OTRO' | null
  final String? tipoCodigo;
  final double cantidad;
  final String unidad;
  final DateTime? fechaVencimiento;
}

/// Impresora que tiene asignada la etiqueta de la receta (Ajustes →
/// Producción → Conexiones en la web). La impresión la hace el SERVIDOR
/// (`POST /produccion/impresoras/imprimir-orden`); la app solo elige a cuál
/// mandar si hay más de una.
class ImpresoraDisponible {
  ImpresoraDisponible({required this.idImpresora, required this.nombre, required this.ip, this.estado});

  factory ImpresoraDisponible.fromJson(Map<String, dynamic> j) => ImpresoraDisponible(
    idImpresora: j['id_impresora'] as int,
    nombre: j['nombre'] as String? ?? '',
    ip: j['ip'] as String? ?? '',
    estado: j['estado'] as String?,
  );

  final int idImpresora;
  final String nombre;
  final String ip;
  final String? estado;
}

/// `GET /produccion/impresoras/para-orden/{id}`: a dónde van las etiquetas de
/// una orden. `problema` != null = no se puede imprimir (receta sin
/// etiqueta, etiqueta sin diseñar o ninguna impresora la tiene asignada).
class DestinoImpresion {
  DestinoImpresion({required this.impresoras, this.problema, this.etiquetaNombre, this.pidePeso = false});

  factory DestinoImpresion.fromJson(Map<String, dynamic> j) {
    final etq = j['etiqueta'] as Map<String, dynamic>?;
    return DestinoImpresion(
      impresoras: (j['impresoras'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ImpresoraDisponible.fromJson)
          .toList(),
      problema: j['problema'] as String?,
      etiquetaNombre: etq?['nombre'] as String?,
      pidePeso: etq?['pide_peso'] == true,
    );
  }

  final List<ImpresoraDisponible> impresoras;
  final String? problema;
  final String? etiquetaNombre;
  final bool pidePeso;
}
