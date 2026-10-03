import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/recepcion_oc_providers.dart';
import '../domain/orden_compra_models.dart';

/// Urgencia de la fecha estimada de entrega de una OC, relativa a hoy —
/// solo compara la parte de fecha (sin hora): "hoy" es hoy sin importar la
/// hora exacta que traiga el backend.
enum _UrgenciaEntrega { hoy, futura, vencida, sinFecha }

_UrgenciaEntrega _urgencia(DateTime? fechaEntrega) {
  if (fechaEntrega == null) return _UrgenciaEntrega.sinFecha;
  final hoy = DateTime.now();
  final hoySoloFecha = DateTime(hoy.year, hoy.month, hoy.day);
  final entregaSoloFecha = DateTime(fechaEntrega.year, fechaEntrega.month, fechaEntrega.day);
  if (entregaSoloFecha.isAtSameMomentAs(hoySoloFecha)) return _UrgenciaEntrega.hoy;
  if (entregaSoloFecha.isAfter(hoySoloFecha)) return _UrgenciaEntrega.futura;
  return _UrgenciaEntrega.vencida;
}

/// Listado de OC aprobadas con saldo pendiente en el almacén del usuario —
/// se llega acá desde el menú ⚙️ de `RecepcionHomeScreen` ("Ver OC
/// pendientes"). Cada fila muestra la fecha estimada de entrega con un
/// semáforo (verde=hoy, amarillo=a partir de mañana, rojo=ya vencida); al
/// tocar una fila se reusa `OcInfoScreen` (`/recepcion/oc/info/:id`), la
/// misma vista de solo lectura que ya usa el escáner, para ver qué
/// productos se esperan de esa OC.
class OcPendientesScreen extends ConsumerWidget {
  const OcPendientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recepcionOcPendientesTodasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('OC pendientes')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recepcionOcPendientesTodasProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 60),
                  Icon(Icons.inbox_outlined, size: 40, color: AppColors.faint),
                  SizedBox(height: 12),
                  Text(
                    'No hay órdenes de compra pendientes de recibir en tu almacén.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              );
            }
            // Vencidas primero, después hoy, después futuras — lo más
            // urgente arriba. Dentro de cada grupo, más antigua primero.
            final ordenados = [...items]..sort((a, b) {
              final ua = _urgencia(a.fechaEntrega).index;
              final ub = _urgencia(b.fechaEntrega).index;
              final ordenA = ua == _UrgenciaEntrega.vencida.index ? -1 : ua;
              final ordenB = ub == _UrgenciaEntrega.vencida.index ? -1 : ub;
              if (ordenA != ordenB) return ordenA.compareTo(ordenB);
              final fa = a.fechaEntrega;
              final fb = b.fechaEntrega;
              if (fa == null || fb == null) return 0;
              return fa.compareTo(fb);
            });
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: ordenados.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final oc = ordenados[i];
                return _OcPendienteTile(
                  oc: oc,
                  onTap: () => context.push('/recepcion/oc/info/${oc.idOc}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OcPendienteTile extends StatelessWidget {
  const _OcPendienteTile({required this.oc, required this.onTap});

  final OrdenCompraSimple oc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.description_outlined, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oc.proveedorNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      oc.codigo,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${oc.itemsPendientes} ítem(s) pendiente(s)',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _FechaEntregaBadge(fechaEntrega: oc.fechaEntrega),
            ],
          ),
        ),
      ),
    );
  }
}

/// Semáforo de la fecha estimada de entrega:
/// - Verde: se recibe hoy.
/// - Amarillo: a partir de mañana.
/// - Rojo: ya tendría que haber llegado (fecha pasada).
/// - Gris: la OC no tiene fecha estimada cargada.
class _FechaEntregaBadge extends StatelessWidget {
  const _FechaEntregaBadge({required this.fechaEntrega});

  final DateTime? fechaEntrega;

  @override
  Widget build(BuildContext context) {
    final urgencia = _urgencia(fechaEntrega);

    final (Color fondo, Color texto, String etiqueta) = switch (urgencia) {
      _UrgenciaEntrega.hoy => (AppColors.okBg, AppColors.okTx, 'Hoy'),
      _UrgenciaEntrega.futura => (AppColors.waBg, AppColors.waTx, formatFecha(fechaEntrega!)),
      _UrgenciaEntrega.vencida => (AppColors.erBg, AppColors.erTx, formatFecha(fechaEntrega!)),
      _UrgenciaEntrega.sinFecha => (AppColors.soft, AppColors.muted, 'Sin fecha'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
          child: Text(
            etiqueta,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: texto),
          ),
        ),
        if (urgencia == _UrgenciaEntrega.vencida) ...[
          const SizedBox(height: 4),
          const Text('Vencida', style: TextStyle(fontSize: 10, color: AppColors.erTx)),
        ],
      ],
    );
  }
}
