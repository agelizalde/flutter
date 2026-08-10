import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/notificaciones_providers.dart';
import '../domain/notificacion_model.dart';
import 'notificacion_navegador.dart';

/// Tab "Notificaciones" del bottom nav — feed real del backend (SSE del
/// lado web, acá pollea cada 15s vía `enableSilentRefresh`, no hay SSE en
/// Flutter). Reemplaza al agregador de "Pendientes para vos" que vivía acá
/// antes (ese agregador se mudó a "ALERTAS PARA TI" en el Home, sigue
/// existiendo — son cosas distintas: acá son eventos puntuales que ya
/// pasaron, ahí son resúmenes de trabajo pendiente actual).
///
/// Mismo lenguaje visual que `PedidosHomeScreen` (cards blancas con sombra
/// suave, ícono en contenedor de color, chip a la derecha) y mismos colores
/// por módulo que las tarjetas de "Accesos rápidos" del Home — así una
/// notificación de Picking se ve del mismo celeste que el módulo Picking,
/// etc.
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misNotificacionesProvider);
    final noLeidas = async.value?.where((n) => !n.leida).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text('Notificaciones'),
            if (noLeidas > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  '$noLeidas',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.accentDark),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (noLeidas > 0)
            TextButton.icon(
              onPressed: () async {
                await ref.read(notificacionesRepositoryProvider).marcarTodasLeidas();
                ref.invalidate(misNotificacionesProvider);
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Marcar todas'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(misNotificacionesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 60),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (notificaciones) {
            if (notificaciones.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_outlined, size: 40, color: AppColors.faint),
                          SizedBox(height: 12),
                          Text('No tenés notificaciones todavía', style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              itemCount: notificaciones.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NotificacionCard(notificacion: notificaciones[i]),
            );
          },
        ),
      ),
    );
  }
}

/// Ícono + color por tipo de evento — mismos colores que las tarjetas de
/// "Accesos rápidos" del Home (`_ModuloDeposito`), para que una
/// notificación de Picking se lea como "del módulo Picking" de un vistazo.
class _VisualNotificacion {
  const _VisualNotificacion(this.icono, this.color);

  final IconData icono;
  final Color color;

  static _VisualNotificacion de(Notificacion n) {
    if (n.tipo.startsWith('PICKING')) {
      return const _VisualNotificacion(Icons.shopping_basket_outlined, Color(0xFF0EA5E9));
    }
    if (n.tipo.startsWith('CONTROL_STOCK') || n.tipoEntidad == 'AJUSTE_STOCK_SOLICITUD') {
      return const _VisualNotificacion(Icons.rule_outlined, Color(0xFF475569));
    }
    if (n.tipo.startsWith('EXPEDICION')) {
      return const _VisualNotificacion(Icons.local_shipping_outlined, Color(0xFFDC2626));
    }
    if (n.tipo.startsWith('TRASLADO') || n.tipoEntidad == 'RECEPCION') {
      return const _VisualNotificacion(Icons.swap_horiz_outlined, Color(0xFF7C3AED));
    }
    if (n.tipo.startsWith('FIRMAS')) {
      return const _VisualNotificacion(Icons.draw_outlined, Color(0xFFD97706));
    }
    return const _VisualNotificacion(Icons.notifications_outlined, AppColors.accent);
  }
}

class _NotificacionCard extends ConsumerWidget {
  const _NotificacionCard({required this.notificacion});

  final Notificacion notificacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visual = _VisualNotificacion.de(notificacion);
    final noLeida = !notificacion.leida;

    return Material(
      color: noLeida ? AppColors.accentSoft : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => abrirNotificacion(context, ref, notificacion),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: noLeida ? Border.all(color: AppColors.accent.withValues(alpha: 0.18)) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visual.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visual.icono, color: visual.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificacion.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: noLeida ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    if (notificacion.mensaje != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        notificacion.mensaje!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _tiempoRelativo(notificacion.creadoEn),
                      style: const TextStyle(fontSize: 11, color: AppColors.faint, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                children: [
                  if (noLeida)
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                    ),
                  const SizedBox(height: 10),
                  const Icon(Icons.chevron_right, color: AppColors.faint, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _tiempoRelativo(DateTime fecha) {
  final diff = DateTime.now().difference(fecha);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  return 'Hace ${diff.inDays} d';
}
