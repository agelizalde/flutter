import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/recepcion_providers.dart';
import 'widgets/recepcion_tile.dart';

/// Pantalla de inicio del módulo. Mismo lenguaje visual que Home
/// (`HomeScreen`) y Detalle producto: header "hero" con degradé en vez de
/// AppBar plano.
/// - "Recibir OC" es la acción que más sentido tiene a futuro (la mayoría
///   de la mercadería entra por una orden de compra), por eso va primero
///   y más grande.
/// - "Recepción manual" es la única forma de crear una recepción hoy,
///   pero requiere el permiso `recepciones.manual` — si el usuario no lo
///   tiene, el botón ni aparece.
/// - Debajo, accesos directos a Historial y Pendientes de control (este
///   último requiere el permiso `recepciones.controlar` — si no lo tiene,
///   ni aparece; si lo tiene y hay pendientes, se pone naranja con un
///   globo con la cantidad), y las últimas recepciones del usuario que
///   están PEND_CONTROL o INGRESADA.
class RecepcionHomeScreen extends ConsumerWidget {
  const RecepcionHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recientesAsync = ref.watch(recepcionesRecientesProvider);
    final usuario = ref.watch(authControllerProvider).value;
    final puedeRecibirOc = usuario?.tienePermiso('recepciones.crear') ?? false;
    final puedeRecepcionManual = usuario?.tienePermiso('recepciones.manual') ?? false;
    final puedeControlar = usuario?.tienePermiso('recepciones.controlar') ?? false;

    final cantidadPendientesControl = puedeControlar
        ? ref.watch(recepcionListadoProvider(('', 'PEND_CONTROL'))).value?.length ?? 0
        : 0;

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(recepcionesRecientesProvider),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _Hero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (puedeRecibirOc) ...[
                      _RecibirOcCta(onTap: () => context.push('/recepcion/oc/inicio')),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        if (puedeRecepcionManual)
                          Expanded(
                            child: _AccionTile(
                              icono: Icons.add,
                              color: const Color(0xFF16A34A),
                              etiqueta: 'Recepción manual',
                              onTap: () => context.push('/recepcion/nueva'),
                            ),
                          ),
                        if (puedeControlar) ...[
                          if (puedeRecepcionManual) const SizedBox(width: 10),
                          Expanded(
                            child: _AccionTile(
                              icono: Icons.warning_amber_rounded,
                              color: AppColors.muted,
                              etiqueta: 'Pendientes de control',
                              badge: cantidadPendientesControl,
                              onTap: () => context.push('/recepcion/pendientes-control'),
                            ),
                          ),
                        ],
                        if (puedeRecepcionManual || puedeControlar) const SizedBox(width: 10),
                        Expanded(
                          child: _AccionTile(
                            icono: Icons.history,
                            color: AppColors.accent,
                            etiqueta: 'Historial',
                            onTap: () => context.push('/recepcion/historial'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'TUS ÚLTIMAS RECEPCIONES',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverToBoxAdapter(
                child: recientesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return const _SinRecepcionesAun();
                    }
                    return Column(
                      children: [
                        for (final r in items) ...[
                          RecepcionTile(recepcion: r),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.heroStart, AppColors.heroEnd],
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  ),
                ),
                // Menú de accesos secundarios del módulo — hoy solo "Ver OC
                // pendientes" (semáforo de fecha estimada de entrega), pensado
                // para crecer sin volver a apilar CTA en el body.
                PopupMenuButton<String>(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 22),
                  onSelected: (value) {
                    if (value == 'oc_pendientes') context.push('/recepcion/oc/pendientes');
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'oc_pendientes',
                      child: Text('Ver OC pendientes'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Recepción',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
            ),
            const SizedBox(height: 4),
            const Text('Recibí y controlá mercadería', style: TextStyle(fontSize: 13, color: Color(0xFFCBD5E1))),
          ],
        ),
      ),
    );
  }
}

class _RecibirOcCta extends StatelessWidget {
  const _RecibirOcCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CtaCard(
      icono: Icons.qr_code_scanner,
      color: AppColors.accent,
      titulo: 'Recibir OC',
      subtitulo: 'Recepción a partir de una orden de compra',
      onTap: onTap,
    );
  }
}

/// Tarjeta de acción principal — blanca con ícono de color, como el resto
/// de tarjetas de la app (`_ModuloCard`, `_ResultCard`, `RecepcionTile`).
/// Antes estas dos CTA eran bloques sólidos de color pegados debajo del
/// hero oscuro: quedaban 3 franjas azules apiladas sin contraste, muy
/// "pesado" arriba de la pantalla.
class _CtaCard extends StatelessWidget {
  const _CtaCard({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icono, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccionTile extends StatelessWidget {
  const _AccionTile({
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icono;
  final Color color;
  final String etiqueta;
  final VoidCallback onTap;

  /// Cantidad pendiente. `0` (default) = tile neutro. Más de `0` = tile
  /// destacado entero en naranja con el número en un recuadro, no solo un
  /// globito sobre el ícono (eso quedaba muy apretado en un tile chico).
  final int badge;

  @override
  Widget build(BuildContext context) {
    final destacado = badge > 0;
    final fondo = destacado ? AppColors.alertTx : Colors.white;
    final colorIcono = destacado ? Colors.white : color;
    final colorTexto = destacado ? Colors.white : AppColors.text;

    return Container(
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: destacado ? AppColors.alertTx.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
            blurRadius: destacado ? 16 : 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, color: colorIcono, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      etiqueta,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colorTexto),
                    ),
                  ],
                ),
              ),
              if (destacado)
                Positioned(top: 8, right: 8, child: _BadgeCount(count: badge)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeCount extends StatelessWidget {
  const _BadgeCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      constraints: const BoxConstraints(minWidth: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.alertTx, height: 1),
      ),
    );
  }
}

class _SinRecepcionesAun extends StatelessWidget {
  const _SinRecepcionesAun();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: const Column(
        children: [
          Icon(Icons.move_to_inbox_outlined, size: 32, color: AppColors.faint),
          SizedBox(height: 10),
          Text(
            'Todavía no tenés recepciones pendientes de control ni ingresadas',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
