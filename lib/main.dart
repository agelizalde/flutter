import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Antes que nada: si alguien pisó la URL del backend desde "Configurar
  // servidor" (login), que ya esté disponible para el primer request.
  await Env.cargarOverrideGuardado();
  runApp(const ProviderScope(child: WherehouseApp()));
}
