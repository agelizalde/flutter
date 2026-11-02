import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Prueba de conexión liviana para elegir entre `erp.riversupply.com.py`
/// (red interna) y `public.riversupply.com.py` (túnel público) — ver
/// `Env._erpOrigin`/`_publicOrigin` y el allow/deny de `nginx.conf`
/// (192.168.100.0/24). Un simple `Socket.connect` no alcanza para
/// distinguir "el dominio resolvió y nginx lo aceptó" de "resolvió pero
/// nginx lo rechazó por IP" (devuelve 403 con la conexión TCP igual
/// aceptada), así que acá se hace un GET real y se mira el código de
/// respuesta.
class BackendResolver {
  const BackendResolver();

  Future<bool> disponible(
    String origen, {
    // 2s quedaba corto para un handshake TLS en frío sobre wifi/datos
    // móviles débiles (típico de un depósito con estanterías metálicas) --
    // el request fallaba el chequeo de disponibilidad aunque el servidor
    // respondiera bien un segundo o dos más tarde, dejando la app en
    // "sin conexión" con los dos orígenes en realidad disponibles.
    Duration timeout = const Duration(seconds: 5),
    Set<int> codigosAdicionales = const {},
    // Callback opcional para diagnóstico -- ver `Env._probarErp`/
    // `Env._publicoDisponible`. Sin esto, un fallo en el campo (dispositivo
    // real, red de la empresa) queda como un simple `false` sin decir si
    // fue DNS, TLS, timeout, o un código HTTP que no cuenta como
    // "disponible" -- imposible de diagnosticar a distancia.
    void Function(String detalle)? onResultado,
  }) async {
    // `HttpClient` de dart:io no existe en web (tira "Unsupported
    // operation: Platform._version") — en `flutter run -d chrome` se
    // prueba con Dio, que usa el XHR del navegador.
    if (kIsWeb) return _disponibleWeb(origen, timeout, codigosAdicionales, onResultado);
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(Uri.parse(origen)).timeout(timeout);
      final response = await request.close().timeout(timeout);
      await response.drain<void>();
      final codigo = response.statusCode;
      final ok = (codigo >= 200 && codigo < 400) || codigosAdicionales.contains(codigo);
      onResultado?.call(
        '$origen -> HTTP $codigo${ok ? '' : ' (no cuenta como disponible)'}',
      );
      return ok;
    } catch (e) {
      onResultado?.call('$origen -> $e');
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _disponibleWeb(
    String origen,
    Duration timeout,
    Set<int> codigosAdicionales,
    void Function(String detalle)? onResultado,
  ) async {
    final dio = Dio(BaseOptions(connectTimeout: timeout, receiveTimeout: timeout, validateStatus: (_) => true));
    try {
      final response = await dio.get<void>(origen);
      final codigo = response.statusCode ?? 0;
      final ok = (codigo >= 200 && codigo < 400) || codigosAdicionales.contains(codigo);
      onResultado?.call(
        '$origen -> HTTP $codigo${ok ? '' : ' (no cuenta como disponible)'}',
      );
      return ok;
    } catch (e) {
      onResultado?.call('$origen -> $e');
      return false;
    } finally {
      dio.close(force: true);
    }
  }
}
