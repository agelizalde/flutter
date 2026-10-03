import 'package:flutter/foundation.dart';

/// Estado global de conectividad con el backend. Lo actualizan `Env` (falla
/// el chequeo inicial o un reintento manual), `DioClient` (un request se
/// queda sin ningún origen al que caer) y `BackendMonitor` (el chequeo
/// periódico vuelve a tener éxito) — es el único lugar al que miran todos.
///
/// `sinConexion` es un `ValueNotifier` (o sea, ya es un `Listenable`) para
/// poder colgarlo directo del `refreshListenable` de `GoRouter` en
/// `app/router.dart`, mismo mecanismo que ya usa `_AuthRefreshListenable`:
/// cuando pasa a `true`, el router redirige a `/sin-conexion` sin importar
/// en qué pantalla esté el usuario — así la app nunca se queda trabada en
/// un spinner o un error que nadie vio.
class ConexionEstado {
  ConexionEstado._();

  static final ValueNotifier<bool> sinConexion = ValueNotifier<bool>(false);

  /// Detalle técnico del último fallo (host, causa) para mostrar en
  /// `SinConexionScreen` — mismo criterio que `DioClient._mensajeSinConexion`.
  static String? detalle;

  static void marcarSinConexion([String? detalle]) {
    ConexionEstado.detalle = detalle;
    sinConexion.value = true;
  }

  static void marcarConectado() {
    detalle = null;
    if (sinConexion.value) sinConexion.value = false;
  }
}
