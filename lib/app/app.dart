import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/push_notifications_service.dart';
import '../features/notificaciones/presentation/notificacion_navegador.dart';
import 'router.dart';
import 'theme.dart';

class WherehouseApp extends ConsumerStatefulWidget {
  const WherehouseApp({super.key});

  @override
  ConsumerState<WherehouseApp> createState() => _WherehouseAppState();
}

class _WherehouseAppState extends ConsumerState<WherehouseApp> {
  StreamSubscription? _aperturaPushSub;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushNotificationsServiceProvider);
    unawaited(push.inicializar());
    // `rootNavigatorKey` (ver app/router.dart) es lo único que nos da un
    // `BuildContext` válido acá: el tap puede llegar con la app recién
    // abierta por ese mismo tap (notificación con la app terminada), antes
    // de que exista ningún widget propio desde el que arrancar la
    // navegación.
    _aperturaPushSub = push.alAbrirNotificacion.listen((n) {
      final context = rootNavigatorKey.currentContext;
      if (context != null) abrirNotificacion(context, ref, n);
    });
  }

  @override
  void dispose() {
    _aperturaPushSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'RS - WH',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
