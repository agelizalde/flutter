import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/network/backend_monitor.dart';
import 'core/network/http_overrides.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
