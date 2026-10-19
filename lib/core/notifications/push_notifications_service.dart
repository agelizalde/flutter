import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/notificaciones/domain/notificacion_model.dart';
import '../providers.dart';

/// Capa fina sobre `firebase_messaging`: pedir permiso, mandar/renovar el
/// token al backend (`/notificaciones/push-token`, ver
/// `notificaciones_push_service.py`), y resolver el tap sobre una
/// notificación del sistema (app en background o recién abierta por ese
/// tap) a un [Notificacion] que `abrirNotificacion()`
/// (`notificacion_navegador.dart`) ya sabe interpretar — no se duplica
/// lógica de navegación acá.
///
/// Mostrar la notificación en sí (banner del sistema con la app cerrada o
/// en background) no lo maneja este servicio — lo hace Android/iOS solo, a
/// partir del payload `notification` que manda el backend. En foreground no
/// se muestra nada nativo a propósito: el usuario ya está viendo la app, y
/// el feed/WebSocket existente (`misNotificacionesProvider`) refleja la
/// notificación nueva igual.
class PushNotificationsService {
  PushNotificationsService(this._ref);

  final Ref _ref;

  final _aperturaController = StreamController<Notificacion>.broadcast();

  /// Emite un [Notificacion] cada vez que el usuario toca una notificación
  /// push — tanto si la app estaba en background (`onMessageOpenedApp`)
  /// como si estaba terminada (chequeado una vez acá vía
  /// `getInitialMessage()`).
  Stream<Notificacion> get alAbrirNotificacion => _aperturaController.stream;

  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado) return;
    _inicializado = true;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      unawaited(enviarTokenAlBackend());
      messaging.onTokenRefresh.listen((_) => enviarTokenAlBackend());

      FirebaseMessaging.onMessageOpenedApp.listen(_emitirSiResoluble);

      final inicial = await messaging.getInitialMessage();
      if (inicial != null) _emitirSiResoluble(inicial);
    } catch (_) {
      // Firebase no se inicializó en main() (falta google-services.json /
      // GoogleService-Info.plist) — push notifications quedan
      // deshabilitadas en esta build, el resto de la app sigue sin verse
      // afectado (ver el try/catch equivalente en main.dart).
    }
  }

  void _emitirSiResoluble(RemoteMessage mensaje) {
    final n = _notificacionDesdeMensaje(mensaje);
    if (n != null) _aperturaController.add(n);
  }

  /// El payload `data` lo arma `enviar_push()` en el backend con exactamente
  /// estos campos — ver `notificaciones_push_service.py`. `null` si falta
  /// algo esencial (mensaje viejo/de otra fuente): mejor no navegar mal que
  /// adivinar.
  Notificacion? _notificacionDesdeMensaje(RemoteMessage mensaje) {
    final data = mensaje.data;
    final idNotificacion = int.tryParse(data['id_notificacion'] ?? '');
    final tipoEntidad = data['tipo_entidad'] as String?;
    if (idNotificacion == null || tipoEntidad == null) return null;

    return Notificacion(
      idNotificacion: idNotificacion,
      tipo: data['tipo'] as String? ?? '',
      titulo: mensaje.notification?.title ?? '',
      mensaje: mensaje.notification?.body,
      tipoEntidad: tipoEntidad,
      idEntidad: int.tryParse(data['id_entidad'] ?? ''),
      ruta: data['ruta'] as String?,
      leida: false,
      creadoEn: DateTime.now(),
    );
  }

  /// Pública: además de llamarse sola desde [inicializar] (una vez por
  /// arranque de app), `AuthController` la vuelve a llamar justo después de
  /// un login exitoso y al restaurar una sesión guardada — si el primer
  /// intento en [inicializar] corrió sin sesión todavía (401, atajado
  /// abajo), este es el que realmente deja el token registrado.
  Future<void> enviarTokenAlBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _ref.read(dioClientProvider).dio.post<void>(
        '/notificaciones/push-token',
        data: {
          'fcm_token': token,
          'plataforma': defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
        },
      );
    } catch (_) {
      // Best-effort: no bloquea login/arranque. Si falló por falta de red,
      // el próximo `inicializar()` (reinicio de la app) o `onTokenRefresh`
      // lo vuelve a intentar.
    }
  }

  /// Llamado desde logout — best-effort, mismo criterio que el registro: un
  /// fallo acá no debería impedir cerrar sesión.
  Future<void> eliminarTokenDelBackend() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _ref.read(dioClientProvider).dio.delete<void>(
        '/notificaciones/push-token',
        data: {'fcm_token': token},
      );
    } catch (_) {
      // Idem arriba — ver eliminar_token() en el backend, que además es
      // idempotente de su lado.
    }
  }
}

final pushNotificationsServiceProvider = Provider<PushNotificationsService>((ref) {
  return PushNotificationsService(ref);
});

/// Handler de mensajes en background — requisito de FlutterFire: tiene que
/// ser una función top-level (no un método de instancia), registrada antes
/// de `runApp` (ver `main.dart`). No necesita hacer nada: el payload
/// `notification` ya lo muestra el sistema operativo solo: esto solo existe
/// para que el plugin tenga un handler que invocar.
@pragma('vm:entry-point')
Future<void> fcmBackgroundHandler(RemoteMessage message) async {}
