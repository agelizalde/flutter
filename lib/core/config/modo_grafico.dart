import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// "Modo gráfico" de Android — qué motor de dibujo usa la app. Lo decide
/// `MainActivity.kt` al arrancar (no se puede cambiar en caliente); esto solo
/// lee/guarda la preferencia y reinicia la app para aplicarla.
///
/// - [auto]: compatibilidad solo en Android viejos (< 10 o sin Vulkan 1.1).
/// - [compat]: siempre el motor anterior (para una terminal que se ve negra o
///   se cierra al abrir).
/// - [moderno]: siempre Impeller.
enum ModoGrafico {
  auto('auto', 'Automático'),
  compat('compat', 'Compatibilidad'),
  moderno('moderno', 'Moderno');

  const ModoGrafico(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static ModoGrafico deCodigo(String? codigo) =>
      ModoGrafico.values.firstWhere((m) => m.codigo == codigo, orElse: () => ModoGrafico.auto);
}

class EstadoModoGrafico {
  const EstadoModoGrafico({required this.modo, required this.compatibilidadAuto, required this.compatibilidadActiva});

  final ModoGrafico modo;

  /// Lo que elegiría "Automático" en este dispositivo.
  final bool compatibilidadAuto;

  /// Lo que se está usando ahora mismo (desde que arrancó la app).
  final bool compatibilidadActiva;
}

class ModoGraficoStore {
  static const _canal = MethodChannel('wherehouse/modo_grafico');

  /// Solo existe en Android (iOS no tiene el problema).
  static bool get disponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<EstadoModoGrafico?> estado() async {
    if (!disponible) return null;
    final res = await _canal.invokeMapMethod<String, dynamic>('estado');
    if (res == null) return null;
    return EstadoModoGrafico(
      modo: ModoGrafico.deCodigo(res['modo'] as String?),
      compatibilidadAuto: res['compatibilidadAuto'] == true,
      compatibilidadActiva: res['compatibilidadActiva'] == true,
    );
  }

  static Future<void> guardar(ModoGrafico modo) => _canal.invokeMethod<void>('guardar', {'modo': modo.codigo});

  /// Mata el proceso y vuelve a abrir la app — el motor se elige una sola vez
  /// por proceso, cerrar la pantalla no alcanza.
  static Future<void> reiniciar() => _canal.invokeMethod<void>('reiniciar');
}
