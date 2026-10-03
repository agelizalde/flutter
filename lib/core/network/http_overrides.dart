import 'dart:io';

import '../config/env.dart';

/// Override global de `HttpClient` -- afecta por igual a Dio, a
/// `BackendResolver` y a cualquier `NetworkImage`/fetch de Flutter, porque
/// todos crean su cliente con `HttpClient()` internamente y ese
/// constructor delega en `HttpOverrides.current` si hay uno seteado.
///
/// Para qué sirve: `Env` intenta primero resolver `erp.riversupply.com.py`
/// por DNS normal. El problema real que motivó esto es que un celu, aunque
/// esté conectado al wifi de la oficina, puede resolver ese nombre distinto
/// de como lo resuelve una PC en la misma red (DNS privado de Android
/// forzando un resolver público, alguna VPN de otra app instalada, etc.) --
/// eso hacía que la app cayera siempre a `public.` aunque el navegador del
/// mismo dispositivo, con el mismo wifi, sí llegara bien a `erp.`.
///
/// La solución es forzar el socket TCP a la IP LAN fija del servidor
/// (`Env.erpIpForzada`) sin cambiar nada más de la request: `SecureSocket`
/// sigue usando `uri.host` (no la IP real conectada) para el SNI del
/// handshake TLS y para validar el certificado, y el header `Host` que
/// manda `HttpClient` también sale de `uri.host` -- así nginx recibe
/// exactamente la misma request que si la resolución DNS hubiera andado
/// bien. Ver `Env._probarErp` para cuándo se activa `erpIpForzada`.
class AutoDominioHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      final ipForzada = Env.erpIpForzada;
      final destino = (ipForzada != null && uri.host == Env.erpHost)
          ? ipForzada
          : uri.host;
      final tarea = await Socket.startConnect(destino, uri.port);
      // Fijar `connectionFactory` apaga el envoltorio TLS automático que
      // `HttpClient` hace solo cuando usa su propio `SecureSocket.startConnect`
      // (ver `_ConnectionTarget.connect` en el SDK) -- sin este paso, todas
      // las requests https de la app (erp. y public. por igual, no solo las
      // que fuerzan IP) salían como texto plano sobre el puerto 443. El
      // servidor detecta que no es un handshake TLS válido y responde con un
      // 400 en texto plano ("the plain HTTP request was sent to an HTTPS
      // port") -- Dart lo interpreta como una respuesta HTTP 400 normal, no
      // como un error de conexión, así que ni siquiera disparaba el
      // diagnóstico de `BackendResolver`. `host: uri.host` (no `destino`) es
      // lo que mantiene el SNI/validación de certificado contra el dominio
      // real aunque el socket TCP haya ido a la IP forzada.
      if (!uri.isScheme('https')) {
        return ConnectionTask.fromSocket(tarea.socket, tarea.cancel);
      }
      final seguro = tarea.socket.then(
        (socket) => SecureSocket.secure(socket, host: uri.host, context: context),
      );
      return ConnectionTask.fromSocket(seguro, tarea.cancel);
    };
    return client;
  }
}
