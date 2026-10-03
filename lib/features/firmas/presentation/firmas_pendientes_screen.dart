import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../../entrega/application/entrega_providers.dart';
import '../application/firmas_providers.dart';
import '../domain/firma_solicitud.dart';

/// Se llega desde el tab Perfil ("Firmas pendientes"). Muestra ÚNICAMENTE
/// lo que le toca firmar al usuario logueado (`puedeFirmarYo`, ver
/// `firmas_providers.dart`) — a propósito no hay forma de ver lo pendiente
/// de otros, esto es su cola de tareas, no un panel administrativo.
/// Agrupado por tipo de documento (OC, OP, entrega de pedido...), cada grupo
/// arranca comprimido (solo nombre + cantidad pendiente) y se despliega al
/// tocarlo — tipo acordeón: desplegar uno comprime cualquier otro que
/// estuviera abierto, ver [_expandedCodigo].
class FirmasPendientesScreen extends ConsumerStatefulWidget {
  const FirmasPendientesScreen({super.key});

  @override
  ConsumerState<FirmasPendientesScreen> createState() => _FirmasPendientesScreenState();
}

class _FirmasPendientesScreenState extends ConsumerState<FirmasPendientesScreen> {
  /// `documentoTipoCodigo` del único grupo desplegado, o `null` si están
  /// todos comprimidos (estado inicial).
  String? _expandedCodigo;

  @override
  Widget build(BuildContext context) {
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
                ...grupos.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _GrupoCard(
                      grupo: g,
                      expanded: _expandedCodigo == g.codigo,
                      onToggle: () => setState(() {
                        _expandedCodigo = _expandedCodigo == g.codigo ? null : g.codigo;
                      }),
                    ),
                  ),
                ),
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

/// Nombre a mostrar del grupo — por defecto el `documento_tipo_nombre` que
/// manda el backend (`firmas_documentos_tipo.nombre`), salvo para
/// `OC_DIFERENCIA_PESO`/`OC_EXCESO_CANTIDAD` donde se pidió un nombre más
/// corto en esta pantalla sin tocar el nombre real en la base (que también lo
/// usa la web).
String _nombreGrupo(String codigo, String nombreBackend) => switch (codigo) {
  'OC_DIFERENCIA_PESO' => 'OC - Diferencia de peso',
  'OC_EXCESO_CANTIDAD' => 'OC - Diferencia de cantidad',
  _ => nombreBackend,
};

(IconData, Color, Color) _iconoTipo(String codigo) => switch (codigo) {
  'OC' => (Icons.description_outlined, AppColors.inBg, AppColors.inTx),
  'OP' => (Icons.payments_outlined, const Color(0xFFF3E8FF), const Color(0xFF7C3AED)),
  'PEDIDO_ENTREGA' => (Icons.local_shipping_outlined, AppColors.waBg, AppColors.waTx),
  'OC_EXCESO_CANTIDAD' => (Icons.add_box_outlined, AppColors.erBg, AppColors.erTx),
  'OC_DIFERENCIA_PESO' => (Icons.monitor_weight_outlined, AppColors.erBg, AppColors.erTx),
  _ => (Icons.draw_outlined, AppColors.soft, AppColors.sub),
};

/// Comprimido muestra solo ícono + nombre + "N pendientes"; tocar el header
/// dispara [onToggle] (definido por [_FirmasPendientesScreenState], que se
/// encarga de la lógica de acordeón). El cuerpo (lista de solicitudes) se
/// anima con [AnimatedCrossFade] en vez de aparecer/desaparecer de golpe.
class _GrupoCard extends StatelessWidget {
  const _GrupoCard({required this.grupo, required this.expanded, required this.onToggle});

  final _Grupo grupo;
  final bool expanded;
  final VoidCallback onToggle;

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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
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
                          _nombreGrupo(grupo.codigo, grupo.nombre),
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
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, color: AppColors.faint),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: grupo.items
                    .map((s) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _SolicitudTile(solicitud: s)))
                    .toList(),
              ),
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
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
          child: solicitud.esPedidoEntrega
            ? _EntregaTileRow(solicitud: solicitud)
            : (solicitud.esOrdenCompra || solicitud.esOrdenPago)
                ? _OrdenCompraTileRow(solicitud: solicitud)
                : (solicitud.esDiferenciaPeso || solicitud.esExcesoCantidad)
                    ? _DiferenciaPesoTileRow(solicitud: solicitud)
                    : _GenericTileRow(solicitud: solicitud),
        ),
      ),
    );
  }
}

class _GenericTileRow extends StatelessWidget {
  const _GenericTileRow({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

/// Formato propio compartido por `OC` y `OP` (ver
/// `FirmaSolicitud.esOrdenCompra`/`esOrdenPago`): "Proveedor - Solicitante" /
/// "N° - Fecha de solicitud", con la fecha en rojo si lleva 2+ días pendiente
/// de firma (ya se demoró) o en amarillo si lleva 0-1 día (recién llegada) —
/// no hay un plazo límite configurado en el sistema, es un umbral fijo
/// elegido para esta pantalla. El precio total se muestra igual que en
/// `_GenericTileRow` (`formatGs(solicitud.monto)`), sin cambios.
/// `documentoCodigo`/`documentoProveedorNombre` ya vienen enriquecidos en el
/// listado (ver `_enriquecer_con_resumen`/`oc_firma_hook.py`/`op_firma_hook
/// .py`), no hace falta pedir el detalle de la OC/OP aparte acá.
class _OrdenCompraTileRow extends StatelessWidget {
  const _OrdenCompraTileRow({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final proveedor = solicitud.documentoProveedorNombre ?? '—';
    final solicitante = solicitud.solicitanteUsername ?? '—';
    final codigo = solicitud.documentoCodigo ?? '${solicitud.documentoTipoCodigo} #${solicitud.idDocumento}';
    final diasPendiente = DateTime.now().difference(solicitud.fechaSolicitud).inDays;
    final colorFecha = diasPendiente >= 2 ? AppColors.erTx : AppColors.waTx;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$proveedor - $solicitante',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$codigo - ', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    TextSpan(
                      text: formatFecha(solicitud.fechaSolicitud),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorFecha),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    );
  }
}

/// Formato propio compartido por `OC_DIFERENCIA_PESO` y `OC_EXCESO_CANTIDAD`
/// (ver `FirmaSolicitud.esDiferenciaPeso`/`esExcesoCantidad`): "Proveedor -
/// Solicitante" / "N° OC - Fecha de la solicitud", sin monto (ninguna de las
/// dos excepciones tiene un monto que valga mostrar acá, ver comentario en
/// `_DatosCard` de la pantalla de detalle) — en su lugar un círculo rojo
/// fijo, igual que el semáforo de [_EstadoCirculo] pero sin estado
/// intermedio: toda solicitud de estos tipos es, por definición, una
/// discrepancia a revisar. Mismos campos enriquecidos que
/// [_OrdenCompraTileRow] (`documentoCodigo`/`documentoProveedorNombre`, este
/// último vía `_resumen_exceso_oc`/`_resumen_diferencia_peso` en sus hooks
/// respectivos).
class _DiferenciaPesoTileRow extends StatelessWidget {
  const _DiferenciaPesoTileRow({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    final proveedor = solicitud.documentoProveedorNombre ?? '—';
    final solicitante = solicitud.solicitanteUsername ?? '—';
    final codigo = solicitud.documentoCodigo ?? 'OC #${solicitud.idDocumento}';

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: AppColors.erTx, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$proveedor - $solicitante',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const SizedBox(height: 3),
              Text(
                '$codigo - ${formatFecha(solicitud.fechaSolicitud)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: AppColors.faint),
      ],
    );
  }
}

/// Formato propio para `PEDIDO_ENTREGA` (ver `FirmaSolicitud.esPedidoEntrega`):
/// "Cliente - Sucursal - Tipo de subpedido" / "Quién entregó - Fecha de la
/// entrega", sin precio, más un círculo verde/rojo según si la entrega tuvo
/// problemas — pide `PedidoEntregaResumen` aparte porque el listado genérico
/// de Firmas no trae nada de la entrega en sí (ver `_EntregaPedidoCard` en
/// la pantalla de detalle, mismo dato).
class _EntregaTileRow extends ConsumerWidget {
  const _EntregaTileRow({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pedidoEntregaResumenProvider(solicitud.idDocumento));

    return async.when(
      loading: () => Row(
        children: [
          const _EstadoCirculo(sinProblemas: null),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              solicitud.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.faint),
          ),
        ],
      ),
      error: (e, _) => Row(
        children: [
          const _EstadoCirculo(sinProblemas: null),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              describeError(e),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.erTx),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.faint),
        ],
      ),
      data: (resumen) {
        final sub = resumen.subpedido;
        final linea1 = [resumen.clienteNombre, resumen.sucursalNombre, sub.tipoNombre]
            .where((p) => p != null && p.trim().isNotEmpty)
            .join(' - ');
        final linea2 = [sub.entregoNombre, sub.entregoFecha != null ? formatFechaHora(sub.entregoFecha!) : null]
            .where((p) => p != null && p.trim().isNotEmpty)
            .join(' - ');
        return Row(
          children: [
            _EstadoCirculo(sinProblemas: sub.sinProblemas),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linea1.isEmpty ? solicitud.titulo : linea1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    linea2.isEmpty ? '—' : linea2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        );
      },
    );
  }
}

/// Verde: entrega sin novedades. Rojo: tuvo rechazo/devolución/faltante.
/// Gris: todavía no se sabe (cargando o el subpedido no está entregado).
class _EstadoCirculo extends StatelessWidget {
  const _EstadoCirculo({required this.sinProblemas});

  final bool? sinProblemas;

  @override
  Widget build(BuildContext context) {
    final color = switch (sinProblemas) {
      true => AppColors.okTx,
      false => AppColors.erTx,
      null => AppColors.faint,
    };
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
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
