import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../application/firmas_providers.dart';
import '../domain/firma_solicitud.dart';

/// Se llega desde el tab Perfil ("Firmas pendientes"). Muestra ÚNICAMENTE
/// lo que le toca firmar al usuario logueado (`puedeFirmarYo`, ver
/// `firmas_providers.dart`) — a propósito no hay forma de ver lo pendiente
/// de otros, esto es su cola de tareas, no un panel administrativo.
/// Agrupado por tipo de documento (OC, OP, entrega de pedido...).
class FirmasPendientesScreen extends ConsumerWidget {
  const FirmasPendientesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario != null && !usuario.tienePermiso('firmas.ver')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Firmas pendientes')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tenés permiso para ver el módulo de firmas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final async = ref.watch(firmasPendientesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Firmas pendientes')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(firmasPendientesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 60),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (items) {
            final propias = items.where((s) => s.puedeFirmarYo).toList();
            final grupos = _agrupar(propias);

            if (grupos.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 56, color: AppColors.faint),
                          SizedBox(height: 14),
                          Text(
                            'Nada esperando tu firma',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(
                  'Tenés ${propias.length} solicitud${propias.length == 1 ? '' : 'es'} esperando tu firma',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                ...grupos.map((g) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _GrupoCard(grupo: g))),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Grupo {
  _Grupo(this.codigo, this.nombre);

  final String codigo;
  final String nombre;
  final List<FirmaSolicitud> items = [];
}

List<_Grupo> _agrupar(List<FirmaSolicitud> propias) {
  final porTipo = <String, _Grupo>{};
  for (final s in propias) {
    final g = porTipo.putIfAbsent(s.documentoTipoCodigo, () => _Grupo(s.documentoTipoCodigo, s.documentoTipoNombre));
    g.items.add(s);
  }
  final lista = porTipo.values.toList();
  for (final g in lista) {
    g.items.sort((a, b) => a.fechaSolicitud.compareTo(b.fechaSolicitud));
  }
  lista.sort((a, b) => b.items.length.compareTo(a.items.length) != 0
      ? b.items.length.compareTo(a.items.length)
      : a.nombre.compareTo(b.nombre));
  return lista;
}

(IconData, Color, Color) _iconoTipo(String codigo) => switch (codigo) {
  'OC' => (Icons.description_outlined, AppColors.inBg, AppColors.inTx),
  'OP' => (Icons.payments_outlined, const Color(0xFFF3E8FF), const Color(0xFF7C3AED)),
  'PEDIDO_ENTREGA' => (Icons.local_shipping_outlined, AppColors.waBg, AppColors.waTx),
  'OC_EXCESO_CANTIDAD' => (Icons.add_box_outlined, AppColors.erBg, AppColors.erTx),
  'OC_DIFERENCIA_PESO' => (Icons.monitor_weight_outlined, AppColors.erBg, AppColors.erTx),
  _ => (Icons.draw_outlined, AppColors.soft, AppColors.sub),
};

class _GrupoCard extends StatelessWidget {
  const _GrupoCard({required this.grupo});

  final _Grupo grupo;

  @override
  Widget build(BuildContext context) {
    final (icono, bg, fg) = _iconoTipo(grupo.codigo);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, size: 19, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grupo.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    Text(
                      '${grupo.items.length} pendiente${grupo.items.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...grupo.items.map(
            (s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _SolicitudTile(solicitud: s)),
          ),
        ],
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pageBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/firmas/${solicitud.idFirmaSolicitud}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      solicitud.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Pidió ${solicitud.solicitanteUsername ?? '—'} · ${_fmtRelativo(solicitud.fechaSolicitud)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatGs(solicitud.monto),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtRelativo(DateTime fecha) {
  final ms = DateTime.now().difference(fecha).inMilliseconds;
  final min = ms ~/ 60000;
  if (min < 1) return 'recién';
  if (min < 60) return 'hace $min min';
  final hs = min ~/ 60;
  if (hs < 24) return 'hace $hs h';
  final dias = hs ~/ 24;
  if (dias < 30) return 'hace $dias d';
  final meses = dias ~/ 30;
  if (meses < 12) return 'hace $meses mes${meses > 1 ? 'es' : ''}';
  final anios = meses ~/ 12;
  return 'hace $anios año${anios > 1 ? 's' : ''}';
}
