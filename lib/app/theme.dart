import 'package:flutter/material.dart';

/// Paleta "WMS Premium" (rediseño 2026-07 del Home/nav de wherehouse):
/// fondo blanco/gris muy claro y acento azul, pensada para depósito —
/// legibilidad alta y contraste fuerte para uso a una mano/con guantes.
/// Reemplaza a la paleta stone/índigo anterior (ya no comparte marca 1:1
/// con la web del ERP, decisión deliberada al adoptar este spec).
class AppColors {
  static const pageBg = Color(0xFFF5F7FA);
  static const surface = Color(0xFFFFFFFF);
  static const soft = Color(0xFFF5F7FA);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);

  static const text = Color(0xFF1F2937);
  static const sub = Color(0xFF374151);
  static const muted = Color(0xFF6B7280);
  static const faint = Color(0xFF9CA3AF);
  static const ink = Color(0xFF111827);

  /// Acento de marca (azul, spec "WMS Premium") — botones primarios, foco
  /// de inputs, elementos activos y el botón de escaneo (acción central de
  /// toda la app).
  static const accent = Color(0xFF2563EB);
  static const accentDark = Color(0xFF1D4ED8);
  static const accentSoft = Color(0xFFEFF6FF);

  /// Franjas de prioridad de "Pendientes para vos" (Home/Notificaciones).
  static const prioridadUrgente = Color(0xFFDC2626);
  static const prioridadAlta = Color(0xFFEA580C);
  static const prioridadMedia = Color(0xFFF59E0B);
  static const prioridadInformativa = accent;

  /// Header "hero" oscuro del Home — le da más carácter a la pantalla
  /// principal en vez de repetir el mismo blanco de todas las demás
  /// (gradiente sutil azul-marino a azul de marca).
  static const heroStart = Color(0xFF0F172A);
  static const heroEnd = Color(0xFF1E3A8A);

  /// Naranja vívido para alertas que necesitan atención del usuario (ej.
  /// recepciones pendientes de control) — distinto del ámbar `wa*`
  /// genérico (usado para warnings más suaves, como vencimientos próximos).
  static const alertBg = Color(0xFFFFEDD5);
  static const alertTx = Color(0xFFC2410C);

  static const okBg = Color(0xFFF0FDF4);
  static const okTx = Color(0xFF14532D);
  static const waBg = Color(0xFFFFFBEB);
  static const waTx = Color(0xFF78350F);
  static const erBg = Color(0xFFFFF1F2);
  static const erTx = Color(0xFF881337);
  static const inBg = Color(0xFFF0F7FF);
  static const inTx = Color(0xFF1E3A8A);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.light,
    primary: AppColors.accent,
    surface: AppColors.surface,
    error: AppColors.erTx,
  );

  const inputRadius = 18.0;

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.pageBg,
    splashColor: AppColors.accentSoft,
    highlightColor: AppColors.accentSoft,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    // Inputs "filled, sin borde duro" — el énfasis visual lo da el fondo
    // suave (T.soft) y, al enfocar, un borde de acento. Nada de las cajas
    // outline grises por defecto de Material.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.faint, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: AppColors.erTx, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: AppColors.erTx, width: 1.6),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.soft,
        disabledForegroundColor: AppColors.faint,
        minimumSize: const Size.fromHeight(50),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputRadius)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.sub,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(inputRadius)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.accentSoft,
        selectedForegroundColor: AppColors.accentDark,
        foregroundColor: AppColors.sub,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
