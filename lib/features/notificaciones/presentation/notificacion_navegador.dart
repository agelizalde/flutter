import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/notificaciones_providers.dart';
import '../domain/notificacion_model.dart';

/// Resuelve a qué pantalla navegar para cada notificación. El backend manda
/// `ruta` pensada para el front WEB (React, ej.
/// `/deposito/centro-mando/pedido/74/87`) — acá se ignora, y la ruta de
/// Flutter se arma a mano por `tipoEntidad` (+ `tipo` cuando una misma
/// entidad puede significar pantallas distintas, ej. `PEDIDO_SUBPEDIDO` es
/// tanto picking como expedición asignada). Tipos sin pantalla en esta app
/// (ej. Firmas, que es web-only) caen al fallback: se marca leída igual,
/// pero se avisa que hay que abrirlo desde la web.
Future<void> abrirNotificacion(BuildContext context, WidgetRef ref, Notificacion n) async {
  if (!n.leida) {
    unawaited(
      ref.read(notificacionesRepositoryProvider).marcarLeida(n.idNotificacion).then((_) {
        ref.invalidate(misNotificacionesProvider);
      }),
    );
  }

  final ruta = _resolverRuta(n);
  if (ruta == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Esta notificación se abre desde la web')));
    }
    return;
  }

  if (context.mounted) context.push(ruta);
}

String? _resolverRuta(Notificacion n) {
  final id = n.idEntidad;

  switch (n.tipoEntidad) {
    case 'PEDIDO_SUBPEDIDO':
      if (id == null) return null;
      if (n.tipo.startsWith('EXPEDICION')) return '/expedicion/subpedido/$id';
      if (n.tipo.startsWith('PICKING')) return '/picking-operario/subpedido/$id/zona';
      return null;
    case 'AJUSTE_STOCK_SOLICITUD':
      return '/ajuste-stock/mis-solicitudes';
    case 'RECEPCION':
      if (id == null) return null;
      return '/recepcion/$id';
    default:
      return null;
  }
}
