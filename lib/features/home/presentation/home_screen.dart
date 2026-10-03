import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/auth/usuario_actual.dart';
import '../../../core/config/env.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../escaner/application/escaner_providers.dart';
import '../../escaner/presentation/resolver_navegacion.dart';
import '../../notificaciones/application/notificaciones_providers.dart';
import '../../picking_operario/application/picking_providers.dart';
import '../../pos/application/pos_providers.dart';
import '../../recepcion/application/recepcion_providers.dart';
import '../application/home_providers.dart';
import 'widgets/tarea_pendiente_card.dart';

class _ModuloDeposito {
  const _ModuloDeposito(
    this.titulo,
    this.descripcion,
    this.icono,
    this.ruta,
    this.color,
    this.permiso, {
    this.requiereRedInterna = true,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;
  final String ruta;
  final Color color;

  /// Código `app.<módulo>.ver` — permiso EXCLUSIVO para mostrar esta
  /// tarjeta, separado del permiso de acción que gatea la pantalla/endpoint
  /// en sí (ej. `stock.ver` sigue gateando `/deposito/stock`, pero ya no
  /// decide si la tarjeta aparece). Se configura por rol en el tab "App"
  /// de `RolDetallePage.jsx` (web) — ver
  /// `back-app/endpoints/modules/ajustes/usuarios/migracion_permisos_app_accesos.sql`.
  final String permiso;

  /// false solo para los módulos cuyos endpoints están en el allowlist de
  /// `public.riversupply.com.py` (Pedidos, Entrega y OC simples, ver
  /// `nginx.conf`) — el resto da 404 seguro fuera de la red de la empresa,
  /// así que no tiene sentido ni mostrar la tarjeta. Ver
  /// `Env.usandoAccesoPublico`.
  final bool requiereRedInterna;
}

/// "Accesos rápidos" — todos los módulos del depósito en una sola grilla,
/// cada uno con una descripción corta (rediseño 2026-07 del Home). Cada
/// módulo se oculta si el usuario (por sus roles) no tiene el permiso
/// `app.*.ver` correspondiente — decidido aparte del permiso que gatea el
/// endpoint real, así un rol puede configurarse a medida qué ve en la app
/// sin tocar lo que puede hacer en el back/web.
const _modulosBase = [
  _ModuloDeposito('Stock', 'Ver stock y ubicaciones', Icons.inventory_2_outlined, '/stock', Color(0xFF2563EB), 'app.stock.ver'),
  _ModuloDeposito('Recepción', 'Recibir mercadería', Icons.move_to_inbox_outlined, '/recepcion', Color(0xFF16A34A), 'app.recepcion.ver'),
  _ModuloDeposito('Traslados', 'Mover entre ubicaciones', Icons.swap_horiz_outlined, '/traslados', Color(0xFF7C3AED), 'app.traslados.ver'),
  _ModuloDeposito('Ajuste de stock', 'Ajustar o solicitar ajuste', Icons.rule_outlined, '/ajuste-stock', Color(0xFF475569), 'app.ajuste_stock.ver'),
  // Gateado además por `pickingAppHabilitadoProvider` en `_modulosPara`
  // (no alcanza con `app.picking.ver`: además hace falta que "Habilitar
  // picking app" esté prendido en Ajustes → Operaciones → Picking → APP -
  // Picking para el almacén base del usuario — kill switch independiente
  // de los permisos de rol).
  _ModuloDeposito('Picking', 'Preparar pedidos', Icons.shopping_basket_outlined, '/picking-operario', Color(0xFF0EA5E9), 'app.picking.ver'),
  _ModuloDeposito('Producción', 'Órdenes y partes', Icons.precision_manufacturing_outlined, '/produccion', Color(0xFFEA580C), 'app.produccion.ver'),
  _ModuloDeposito('Cargar camión', 'Cargar cajones al camión', Icons.local_shipping_outlined, '/expedicion', Color(0xFFDC2626), 'app.expedicion.ver'),
  // Entrega, Pedidos y OC simples son los únicos módulos cuyos endpoints
  // (`/pedidos/...`, `/productos/`, `/proveedores/`, `/compras/oc/`) están
  // en el allowlist de `public.` — ver `_ModuloDeposito.requiereRedInterna`
  // y `nginx.conf`.
  _ModuloDeposito('Entregar pedido', 'Confirmar entrega al cliente', Icons.assignment_turned_in_outlined, '/entrega', Color(0xFF16A34A), 'app.entrega.ver', requiereRedInterna: false),
  _ModuloDeposito('Pedidos', 'Ver y gestionar', Icons.receipt_long_outlined, '/pedidos', Color(0xFF4F46E5), 'app.pedidos.ver', requiereRedInterna: false),
  _ModuloDeposito('Asignar pickers', 'Asignar tareas de picking', Icons.assignment_ind_outlined, '/picking-asignacion', Color(0xFFD97706), 'app.picking_asignacion.ver'),
  _ModuloDeposito('Control de calidad', 'Controlar pedidos armados', Icons.fact_check_outlined, '/picking-control', Color(0xFF0D9488), 'app.picking_control.ver'),
  _ModuloDeposito('OC simples', 'Órdenes de compra', Icons.shopping_cart_outlined, '/oc-simple', Color(0xFFDB2777), 'app.oc_simple.ver', requiereRedInterna: false),
  // El módulo Creador en sí agrupa 5 permisos distintos (proveedores/
  // marcas/productos/zonas/ubicaciones) y cada pestaña adentro ya se oculta
  // sola según el permiso puntual del usuario (ver `CreadorHomeScreen`);
  // `app.creador.ver` solo decide si la tarjeta del Home aparece.
  _ModuloDeposito('Creador', 'Alta rápida de catálogos', Icons.add_box_outlined, '/creador', Color(0xFF0891B2), 'app.creador.ver'),
  // Gateado además por `tienePuntoVentaAsignadoProvider` en `_modulosPara`
  // (no alcanza con `app.pos.ver`: hace falta también que el usuario tenga
  // un punto de venta ACTIVO asignado — ver Ajustes → Puntos de venta en
  // la web).
  _ModuloDeposito('Punto de venta', 'Vender de mostrador', Icons.point_of_sale_outlined, '/pos', Color(0xFF059669), 'app.pos.ver'),
  _ModuloDeposito('Mantenimiento', 'Vehículos y mantenimientos', Icons.build_outlined, '/vehiculos', Color(0xFF64748B), 'app.vehiculos.ver'),
];

List<_ModuloDeposito> _modulosPara(
  UsuarioActual? usuario, {
  required bool tienePuntoVenta,
  required bool pickingAppHabilitado,
  required bool usandoAccesoPublico,
}) {
  return _modulosBase
      .where((m) => usuario?.tienePermiso(m.permiso) ?? false)
      .where((m) => m.ruta != '/pos' || tienePuntoVenta)
      // "Habilitar picking app" (Ajustes -> Operaciones -> Picking -> APP -
      // Picking): kill switch por almacén, independiente del permiso
      // `app.picking.ver` — ver `pickingAppHabilitadoProvider`.
      .where((m) => m.ruta != '/picking-operario' || pickingAppHabilitado)
      // Fuera de la red de la empresa (túnel `public.`), ocultar los
      // módulos que ni siquiera llegan al backend — ver
      // `Env.usandoAccesoPublico` y `_ModuloDeposito.requiereRedInterna`.
      .where((m) => !m.requiereRedInterna || !usandoAccesoPublico)
      .toList();
}

String _saludo() {
  final hora = DateTime.now().hour;
  if (hora < 12) return 'Buenos días';
  if (hora < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final primerNombre = usuario?.nombreMostrar.split(' ').first;
    final tienePuntoVenta = ref.watch(tienePuntoVentaAsignadoProvider).value ?? false;
    final pickingAppHabilitado = ref.watch(pickingAppHabilitadoProvider).value ?? false;
    final pendientes = ref.watch(pendientesHomeProvider);
    final hayNotificacionesSinLeer =
        ref.watch(misNotificacionesProvider).value?.any((n) => !n.leida) ?? false;
    final almacenes = ref.watch(almacenesProvider).value ?? const [];
    String? almacenNombre;
    if (usuario != null) {
      for (final a in almacenes) {
        if (a.idAlmacen == usuario.idAlmacenSeleccionado) {
          almacenNombre = a.nombre;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroHeader(
              saludo: primerNombre != null ? '¡Hola, $primerNombre!' : _saludo(),
              almacenNombre: almacenNombre,
              hayPendientes: hayNotificacionesSinLeer,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(child: _SeccionTitulo('ACCESOS RÁPIDOS')),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            // `ValueListenableBuilder` (no un provider más) porque
            // `Env.usandoAccesoPublicoListenable` no es estado de Riverpod
            // — es el mismo mecanismo "plano" que ya usa `ConexionEstado`
            // en `app/router.dart`. Así la grilla se recalcula sola si el
            // usuario cambia de red (erp. -> public.) en medio de la
            // sesión, sin tener que reabrir la app.
            sliver: ValueListenableBuilder<bool>(
              valueListenable: Env.usandoAccesoPublicoListenable,
              builder: (context, usandoAccesoPublico, _) {
                final modulos = _modulosPara(
                  usuario,
                  tienePuntoVenta: tienePuntoVenta,
                  pickingAppHabilitado: pickingAppHabilitado,
                  usandoAccesoPublico: usandoAccesoPublico,
                );
                return SliverGrid(
                  // `mainAxisExtent` (alto fijo en px) en vez de
                  // `childAspectRatio` a propósito: el ancho de columna
                  // cambia según el dispositivo, pero el contenido de la
                  // tarjeta (ícono 52px + 1-2 líneas de texto) no — con
                  // `childAspectRatio` en una pantalla ancha la tarjeta
                  // salía altísima con medio cartón vacío abajo.
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 150,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ModuloCard(modulo: modulos[index]),
                    childCount: modulos.length,
                  ),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _SeccionTitulo('ALERTAS PARA TI'),
                  if (pendientes.length > 4)
                    TextButton(
                      onPressed: () => context.go('/notificaciones'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                      child: const Text('Ver todas', style: TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverToBoxAdapter(child: _PendientesSection(pendientes: pendientes)),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.saludo, required this.almacenNombre, required this.hayPendientes});

  final String saludo;
  final String? almacenNombre;
  final bool hayPendientes;

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        saludo,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                      ),
                      if (almacenNombre != null) ...[
                        const SizedBox(height: 4),
                        Text(almacenNombre!, style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1))),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/notificaciones'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                      ),
                      if (hayPendientes)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.prioridadUrgente,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.heroEnd, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Buscador(),
          ],
        ),
      ),
    );
  }
}

class _Buscador extends ConsumerWidget {
  const _Buscador();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/escaner'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.faint, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Buscar producto, pedido, ubicación...',
                  style: TextStyle(color: AppColors.faint, fontSize: 13),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _escanear(context, ref),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.qr_code_scanner, color: AppColors.accent, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _escanear(BuildContext context, WidgetRef ref) async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resultado = await ref.read(escanerRepositoryProvider).resolver(codigo);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await resolverYNavegar(context, ref, resultado, codigoNoEncontrado: codigo);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
    );
  }
}

/// Sin backend de métricas del día ("Hoy": picking realizados, recepciones,
/// tiempo promedio) no hay dato real que mostrar, así que esa tarjeta del
/// spec se omite acá — no se fabrica un número. Si más adelante existe un
/// endpoint de productividad diaria, va como sección propia debajo de esta.
class _PendientesSection extends StatelessWidget {
  const _PendientesSection({required this.pendientes});

  final List<TareaPendiente> pendientes;

  @override
  Widget build(BuildContext context) {
    if (pendientes.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_outlined, size: 32, color: AppColors.faint),
            SizedBox(height: 8),
            Text('Estás al día, sin pendientes', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      );
    }

    final visibles = pendientes.take(4).toList();

    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < visibles.length; i++) ...[
            TareaPendienteCard(tarea: visibles[i]),
            if (i < visibles.length - 1) const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _ModuloCard extends StatelessWidget {
  const _ModuloCard({required this.modulo});

  final _ModuloDeposito modulo;

  @override
  Widget build(BuildContext context) {
    // Mismo lenguaje visual que el resto de las tarjetas de la app
    // (`OcInfoScreen._Card`, `PedidoInfoScreen._Card`, etc.): Container con
    // sombra suave + Material transparente adentro. Ícono con tinte suave
    // (no color sólido con sombra de color — quedaba muy "gritón") y todo
    // centrado, no alineado a la izquierda.
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
          onTap: () => context.push(modulo.ruta),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: modulo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(modulo.icono, color: modulo.color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(
                  modulo.titulo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 3),
                Text(
                  modulo.descripcion,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
