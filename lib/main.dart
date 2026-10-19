import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/network/backend_monitor.dart';
import 'core/network/http_overrides.dart';
import 'core/notifications/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hasta que no se suba google-services.json/GoogleService-Info.plist
  // (ver CONTEXTO_WHEREHOUSE.md, pendiente de Firebase Console), esto tira
  // una excepción nativa — atajado a propósito para que la falta de
  // configuración de push notifications no tire abajo el resto de la app
  // (stock, picking, pedidos, etc., que no dependen de esto para nada).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);
  } catch (_) {
    // Push notifications quedan deshabilitadas en esta build; el resto de
    // la app sigue andando igual.
  }

  // Antes de cualquier request: deja que `Env.erpIpForzada` pueda forzar la
  // IP LAN de `erp.` en cualquier `HttpClient` de la app (Dio, fotos, el
  // propio chequeo de `Env`) — ver `AutoDominioHttpOverrides`.
  HttpOverrides.global = AutoDominioHttpOverrides();
  // Antes que nada: si alguien pisó la URL del backend desde "Configurar
  // servidor" (login), o si hay que auto-elegir entre erp./public., que ya
  // esté resuelto para el primer request.
  await Env.cargarOverrideGuardado();
  // Vigila en segundo plano si conviene volver a erp. luego de haber caído
  // a public. — no hace nada si `Env` no está en modo automático.
  BackendMonitor.instancia.iniciar();
  runApp(const ProviderScope(child: WherehouseApp()));
}
