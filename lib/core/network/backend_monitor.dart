import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/env.dart';

/// Vigila en segundo plano si conviene volver a `erp.riversupply.com.py`
/// una vez que la app ya cayó al túnel público, y reintenta solo cuando la
/// app se quedó totalmente sin conexión (ver `Env.reevaluarConexion`,
/// incluye el caso de un override manual caído) — así `SinConexionScreen`
/// puede desaparecer sola sin que el usuario tenga que tocar "Reintentar".
/// El camino inverso (erp. → public., "se cortó la conexión") es
/// instantáneo y lo maneja `DioClient` reintentando el request fallido —
/// acá solo nos preocupa lo que ningún request fallido detecta solo,
/// porque no hay ningún request en curso para que falle.
///
/// Singleton porque se arranca una sola vez desde `main()`, antes de
/// `runApp`, y vive toda la vida de la app (no hay una pantalla dueña que
/// lo pueda `dispose`-ar).
class BackendMonitor {
  BackendMonitor._();
  static final BackendMonitor instancia = BackendMonitor._();

  static const _intervalo = Duration(seconds: 45);

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _verificando = false;

  void iniciar() {
    if (!Env.monitoreoUtil || _timer != null) return;

    _timer = Timer.periodic(_intervalo, (_) => _revisar());

    // Un cambio de red (ej. se conectó al wifi de la oficina) es la señal
    // más rápida de que puede haber cambiado la respuesta de erp.; no
    // reemplaza al timer porque connectivity_plus solo avisa cambios de
    // *interfaz* (wifi/datos móviles), no si esa red en particular llega
    // a la LAN de la empresa.
    _sub = Connectivity().onConnectivityChanged.listen((_) => _revisar());
  }

  Future<void> _revisar() async {
    if (_verificando) return;
    _verificando = true;
    try {
      await Env.reevaluarConexion();
    } finally {
      _verificando = false;
    }
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
    _sub?.cancel();
    _sub = null;
  }
}
