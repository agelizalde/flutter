import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/coming_soon_screen.dart';
import '../core/widgets/debug_screen_tag.dart';
import '../core/widgets/wherehouse_bottom_nav.dart';
import '../features/escaner/presentation/buscador_screen.dart';
import '../features/notificaciones/presentation/notificaciones_screen.dart';
import '../features/home/presentation/configuracion_screen.dart';
import '../features/home/presentation/perfil_screen.dart';
import '../features/pedidos/domain/pedido_models.dart' show SubpedidoResumen;
import '../features/pedidos/presentation/pedido_info_screen.dart';
import '../features/pedidos/presentation/pedidos_home_screen.dart';
import '../features/pedidos/presentation/subpedido_items_screen.dart';
import '../features/ajuste_stock/presentation/ajuste_stock_detalle_screen.dart';
import '../features/ajuste_stock/presentation/ajuste_stock_historial_screen.dart';
import '../features/ajuste_stock/presentation/ajuste_stock_home_screen.dart';
import '../features/ajuste_stock/presentation/merma_rapida_screen.dart';
import '../features/ajuste_stock/presentation/nuevo_ajuste_screen.dart';
import '../features/ajuste_stock_solicitudes/presentation/mis_solicitudes_screen.dart';
import '../features/ajuste_stock_solicitudes/presentation/solicitar_control_screen.dart';
import '../core/network/conexion_estado.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/blocked_user_screen.dart';
import '../features/auth/presentation/cambiar_password_screen.dart';
import '../features/auth/presentation/configurar_servidor_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/sin_conexion_screen.dart';
import '../features/creador/presentation/creador_home_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/entrega/presentation/entrega_home_screen.dart';
import '../features/entrega/presentation/entrega_subpedido_screen.dart';
import '../features/expedicion/presentation/expedicion_detalle_screen.dart';
import '../features/expedicion/presentation/expedicion_home_screen.dart';
import '../features/firmas/presentation/firma_solicitud_detalle_screen.dart';
import '../features/firmas/presentation/firmas_pendientes_screen.dart';
import '../features/oc_simple/presentation/oc_simple_screen.dart';
import '../features/pos/presentation/pos_screen.dart';
import '../features/picking_control/presentation/picking_control_detalle_screen.dart';
import '../features/picking_control/presentation/picking_control_home_screen.dart';
import '../features/picking_operario/presentation/picking_home_screen.dart';
import '../features/picking_operario/presentation/picking_trabajo_screen.dart';
import '../features/picking_operario/presentation/quitar_productos_screen.dart';
import '../features/picking_operario/presentation/zona_selector_screen.dart';
import '../features/produccion/presentation/configurar_impresora_screen.dart';
import '../features/produccion/presentation/etiquetas_screen.dart';
import '../features/produccion/presentation/finalizar_orden_screen.dart';
import '../features/produccion/presentation/mis_producciones_screen.dart';
import '../features/produccion/presentation/nueva_orden_screen.dart';
import '../features/produccion/presentation/orden_detalle_screen.dart';
import '../features/produccion/presentation/orden_en_curso_screen.dart';
import '../features/produccion/presentation/produccion_home_screen.dart';
import '../features/recepcion/presentation/agregar_item_screen.dart';
import '../features/recepcion/presentation/nueva_recepcion_screen.dart';
import '../features/recepcion/presentation/recepcion_control_screen.dart';
import '../features/recepcion/presentation/recepcion_detalle_screen.dart';
import '../features/recepcion/presentation/recepcion_historial_screen.dart';
import '../features/recepcion/presentation/recepcion_home_screen.dart';
import '../features/recepcion/presentation/oc_info_screen.dart';
import '../features/recepcion/presentation/oc_pendientes_screen.dart';
import '../features/recepcion/presentation/recibir_oc_inicio_screen.dart';
import '../features/recepcion/presentation/recibir_oc_items_screen.dart';
import '../features/recepcion/presentation/recibir_oc_listado_screen.dart';
import '../features/stock/presentation/producto_detalle_screen.dart';
import '../features/stock/presentation/proveedor_productos_screen.dart';
import '../features/stock/presentation/stock_search_screen.dart';
import '../features/stock/presentation/ubicacion_productos_screen.dart';
import '../features/stock/presentation/zona_ubicaciones_screen.dart';
import '../features/traslados/domain/traslado_models.dart' show AlertaReacomodo;
import '../features/traslados/presentation/ejecutar_traslado_screen.dart';
import '../features/traslados/presentation/traslado_detalle_screen.dart';
import '../features/traslados/presentation/traslados_home_screen.dart';
import '../features/vehiculos/presentation/vehiculo_detalle_screen.dart';
import '../features/vehiculos/presentation/vehiculos_home_screen.dart';

/// Notifica a go_router cuando cambia el estado de auth, sin recrear el
/// [GoRouter] entero (recrearlo en cada cambio reiniciaría la navegación
/// a `initialLocation` en cada login/logout).
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthRefreshListenable(ref);
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    // `ConexionEstado.sinConexion` es un `ValueNotifier` (ya `Listenable`)
    // — combinado acá, un cambio de conectividad dispara `redirect` igual
    // que un login/logout, sin necesidad de que el usuario navegue solo.
    refreshListenable: Listenable.merge([authListenable, ConexionEstado.sinConexion]),
    redirect: (context, state) {
      final vaAConfigurarServidor = state.matchedLocation == '/configurar-servidor';
      final vaASinConexion = state.matchedLocation == '/sin-conexion';

      // Sin conexión con NINGÚN servidor: pasa por encima de todo lo demás
      // (auth incluido — no tiene sentido resolver sesión sin poder
      // consultar `/auth/me`) salvo las dos rutas que necesita para
      // salir del pozo: la pantalla misma y "Configurar servidor".
      if (ConexionEstado.sinConexion.value) {
        if (!vaASinConexion && !vaAConfigurarServidor) return '/sin-conexion';
        return null;
      }

      final authState = ref.read(authControllerProvider);
      if (authState.isLoading) return null;

      final usuario = authState.value;
      final estaLogueado = usuario != null;
      final estaBloqueado = usuario?.bloqueadoErp ?? false;
      final vaALogin = state.matchedLocation == '/login';
      final vaABloqueado = state.matchedLocation == '/blocked';

      // Se recuperó la conexión estando en /sin-conexion: mandar a donde
      // corresponda según el estado de sesión, no dejarlo varado ahí.
      if (vaASinConexion) {
        if (!estaLogueado) return '/login';
        return estaBloqueado ? '/blocked' : '/';
      }

      if (!estaLogueado && !vaALogin && !vaAConfigurarServidor) return '/login';
      if (estaLogueado && estaBloqueado && !vaABloqueado) return '/blocked';
      if (estaLogueado && !estaBloqueado && vaABloqueado) return '/';
      if (estaLogueado && vaALogin) return estaBloqueado ? '/blocked' : '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const DebugScreenTag(label: 'Login', child: LoginScreen()),
      ),
      GoRoute(
        path: '/blocked',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Bloqueado', child: BlockedUserScreen()),
      ),
      GoRoute(
        path: '/sin-conexion',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Sin conexión', child: SinConexionScreen()),
      ),
      GoRoute(
        path: '/configurar-servidor',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Configurar servidor', child: ConfigurarServidorScreen()),
      ),
      // Shell global de navegación (bottom nav) — Inicio/Pedidos/
      // Notificaciones/Perfil tienen estado propio (un `StatefulShellBranch`
      // cada uno); "Escanear" no es un branch, es el botón central de
      // `WherehouseShell` que abre la cámara directo. Todo lo demás
      // (módulos, detalles) sigue siendo `GoRoute` suelto fuera del shell,
      // empujado con `context.push` como antes — no tienen bottom nav
      // visible mientras están abiertos.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => WherehouseShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DebugScreenTag(label: 'Home', child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pedidos',
                builder: (context, state) => const DebugScreenTag(label: 'Pedidos', child: PedidosHomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notificaciones',
                builder: (context, state) =>
                    const DebugScreenTag(label: 'Notificaciones', child: NotificacionesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/perfil',
                builder: (context, state) => const DebugScreenTag(label: 'Perfil', child: PerfilScreen()),
              ),
            ],
          ),
        ],
      ),
      // Módulos pendientes de implementar (CONTEXTO_WHEREHOUSE.md §12) —
      // se van reemplazando por la pantalla real de cada feature.
      GoRoute(
        path: '/stock',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Stock · Buscar', child: StockSearchScreen()),
      ),
      GoRoute(
        path: '/stock/producto/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Stock · Detalle producto',
          child: ProductoDetalleScreen(idProducto: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/stock/ubicacion/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Stock · Productos en ubicación',
          child: UbicacionProductosScreen(
            idUbicacion: int.parse(state.pathParameters['id']!),
            nombreUbicacion: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/stock/zona/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Stock · Ubicaciones de zona',
          child: ZonaUbicacionesScreen(
            idZona: int.parse(state.pathParameters['id']!),
            nombreZona: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/stock/proveedor/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Stock · Productos de proveedor',
          child: ProveedorProductosScreen(
            idProveedor: int.parse(state.pathParameters['id']!),
            nombreProveedor: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/recepcion',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Recepción · Inicio', child: RecepcionHomeScreen()),
      ),
      GoRoute(
        path: '/recepcion/historial',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Recepción · Historial', child: RecepcionHistorialScreen()),
      ),
      GoRoute(
        path: '/recepcion/pendientes-control',
        builder: (context, state) => const DebugScreenTag(
          label: 'Recepción · Pendientes de control',
          child: RecepcionHistorialScreen(
            estadoFijo: 'PEND_CONTROL',
            titulo: 'Pendientes de control',
          ),
        ),
      ),
      GoRoute(
        path: '/recepcion/nueva',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Recepción · Nueva', child: NuevaRecepcionScreen()),
      ),
      GoRoute(
        path: '/recepcion/oc/inicio',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Recepción · Recibir OC', child: RecibirOcInicioScreen()),
      ),
      // Se llega acá desde el menú ⚙️ de RecepcionHomeScreen ("Ver OC
      // pendientes") — listado de solo lectura, cada fila abre
      // `/recepcion/oc/info/:id` (OcInfoScreen) para ver los ítems.
      GoRoute(
        path: '/recepcion/oc/pendientes',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Recepción · OC pendientes', child: OcPendientesScreen()),
      ),
      GoRoute(
        path: '/recepcion/oc/proveedor/:idProveedor',
        builder: (context, state) => DebugScreenTag(
          label: 'Recepción · OC del proveedor',
          child: RecibirOcListadoScreen(
            idProveedor: int.parse(state.pathParameters['idProveedor']!),
            nombreProveedor: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/recepcion/oc/:idOc/items',
        builder: (context, state) => DebugScreenTag(
          label: 'Recepción · Ítems de OC',
          child: RecibirOcItemsScreen(idOc: int.parse(state.pathParameters['idOc']!)),
        ),
      ),
      // Vista de solo lectura de una OC, alimentada por el buscador/escáner
      // genérico de Home (ver features/escaner) — llega por id y pide los
      // datos ella misma (no usa `extra`, ver OcInfoScreen).
      GoRoute(
        path: '/recepcion/oc/info/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Recepción · Info de OC',
          child: OcInfoScreen(idOc: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/recepcion/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Recepción · Detalle',
          child: RecepcionDetalleScreen(idRecepcion: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/recepcion/:id/controlar',
        builder: (context, state) => DebugScreenTag(
          label: 'Recepción · Controlar',
          child: RecepcionControlScreen(idRecepcion: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/recepcion/:id/items/nuevo',
        builder: (context, state) => DebugScreenTag(
          label: 'Recepción · Agregar ítem',
          child: AgregarItemScreen(idRecepcion: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/traslados',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Traslados · Inicio', child: TrasladosHomeScreen()),
      ),
      GoRoute(
        path: '/traslados/nuevo',
        builder: (context, state) => DebugScreenTag(
          label: 'Traslados · Nuevo',
          child: EjecutarTrasladoScreen(prefillAlerta: state.extra as AlertaReacomodo?),
        ),
      ),
      GoRoute(
        path: '/traslados/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Traslados · Detalle',
          child: TrasladoDetalleScreen(idTraspaso: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/oc-simple',
        builder: (context, state) =>
            const DebugScreenTag(label: 'OC simple', child: OcSimpleScreen()),
      ),
      GoRoute(
        path: '/creador',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Creador', child: CreadorHomeScreen()),
      ),
      GoRoute(
        path: '/pos',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Punto de venta', child: PosScreen()),
      ),
      GoRoute(
        path: '/ajuste-stock',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Ajuste de stock · Inicio', child: AjusteStockHomeScreen()),
      ),
      GoRoute(
        path: '/ajuste-stock/historial',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Ajuste de stock · Historial', child: AjusteStockHistorialScreen()),
      ),
      GoRoute(
        path: '/ajuste-stock/nuevo',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Ajuste de stock · Nuevo', child: NuevoAjusteScreen()),
      ),
      GoRoute(
        path: '/ajuste-stock/merma-rapida',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Ajuste de stock · Merma rápida', child: MermaRapidaScreen()),
      ),
      GoRoute(
        path: '/ajuste-stock/solicitar',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Ajuste de stock · Solicitar control', child: SolicitarControlScreen()),
      ),
      GoRoute(
        path: '/ajuste-stock/mis-solicitudes',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Ajuste de stock · Mis solicitudes', child: MisSolicitudesScreen()),
      ),
      GoRoute(
        path: '/ajuste-stock/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Ajuste de stock · Detalle',
          child: AjusteStockDetalleScreen(idAjusteStock: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/picking-asignacion',
        builder: (context, state) => const ComingSoonScreen(titulo: 'Asignar pickers'),
      ),
      GoRoute(
        path: '/picking-operario',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Picking · Inicio', child: PickingHomeScreen()),
      ),
      GoRoute(
        path: '/picking-operario/subpedido/:id/zona',
        builder: (context, state) => DebugScreenTag(
          label: 'Picking · Elegir zona',
          child: ZonaSelectorScreen(idPedidoSubpedido: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/picking-operario/trabajo',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Picking · Trabajo', child: PickingTrabajoScreen()),
      ),
      GoRoute(
        path: '/picking-operario/quitar-productos',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Picking · Quitar productos', child: QuitarProductosScreen()),
      ),
      GoRoute(
        path: '/picking-control',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Control de picking · Inicio', child: PickingControlHomeScreen()),
      ),
      GoRoute(
        path: '/picking-control/subpedido/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Control de picking · Detalle',
          child: PickingControlDetalleScreen(idPedidoSubpedido: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/produccion',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Producción · Inicio', child: ProduccionHomeScreen()),
      ),
      GoRoute(
        path: '/produccion/mis-producciones',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Producción · Mis producciones', child: MisProduccionesScreen()),
      ),
      GoRoute(
        path: '/produccion/ordenes/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Producción · Detalle',
          child: OrdenDetalleScreen(idOrden: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/produccion/nueva/:idReceta',
        builder: (context, state) => DebugScreenTag(
          label: 'Producción · Nueva',
          child: NuevaOrdenScreen(idReceta: int.parse(state.pathParameters['idReceta']!)),
        ),
      ),
      GoRoute(
        path: '/produccion/taller/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Producción · En curso',
          child: OrdenEnCursoScreen(idOrden: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/produccion/taller/:id/finalizar',
        builder: (context, state) => DebugScreenTag(
          label: 'Producción · Finalizar',
          child: FinalizarOrdenScreen(idOrden: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/produccion/taller/:id/etiquetas',
        builder: (context, state) => DebugScreenTag(
          label: 'Producción · Etiquetas',
          child: EtiquetasScreen(idOrden: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/produccion/impresora',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Producción · Configurar impresora', child: ConfigurarImpresoraScreen()),
      ),
      GoRoute(
        path: '/expedicion',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Expedición · Inicio', child: ExpedicionHomeScreen()),
      ),
      GoRoute(
        path: '/expedicion/subpedido/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Expedición · Carga',
          child: ExpedicionDetalleScreen(idPedidoSubpedido: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/entrega',
        builder: (context, state) => const DebugScreenTag(label: 'Entrega · Inicio', child: EntregaHomeScreen()),
      ),
      GoRoute(
        path: '/entrega/subpedido/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Entrega · Confirmar',
          child: EntregaSubpedidoScreen(idPedidoSubpedido: int.parse(state.pathParameters['id']!)),
        ),
      ),
      // Vista de solo lectura de un pedido, alimentada por el buscador/
      // escáner genérico (ver features/escaner) — llega por id y pide los
      // datos ella misma, mismo patrón que `/recepcion/oc/info/:id`.
      GoRoute(
        path: '/pedidos/info/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Pedidos · Info',
          child: PedidoInfoScreen(idPedido: int.parse(state.pathParameters['id']!)),
        ),
      ),
      // Ítems de un subpedido — se llega tocando una fila en
      // `PedidoInfoScreen`, que manda el `SubpedidoResumen` ya cargado por
      // `extra` para no pedirlo de nuevo (tipo/estado para el appbar).
      GoRoute(
        path: '/pedidos/subpedido/:id/items',
        builder: (context, state) {
          final resumen = state.extra as SubpedidoResumen?;
          return DebugScreenTag(
            label: 'Pedidos · Ítems de subpedido',
            child: SubpedidoItemsScreen(
              idPedidoSubpedido: int.parse(state.pathParameters['id']!),
              idPedido: resumen?.idPedido,
              tipoNombre: resumen?.tipoNombre,
              estadoSubpedido: resumen?.estado,
              rowVersion: resumen?.rowVersion,
            ),
          );
        },
      ),
      // Botón de escaneo del bottom nav / buscador: resuelve producto,
      // ubicación, OC, pedido u orden de producción (ver features/escaner).
      GoRoute(
        path: '/escaner',
        builder: (context, state) => const DebugScreenTag(label: 'Buscar', child: BuscadorScreen()),
      ),
      // Viven fuera del bottom nav (se llega desde el tab Perfil).
      GoRoute(
        path: '/configuracion',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Configuración', child: ConfiguracionScreen()),
      ),
      GoRoute(
        path: '/cambiar-password',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Actualizar contraseña', child: CambiarPasswordScreen()),
      ),
      GoRoute(
        path: '/vehiculos',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Mantenimiento · Vehículos', child: VehiculosHomeScreen()),
      ),
      GoRoute(
        path: '/vehiculos/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Mantenimiento · Detalle vehículo',
          child: VehiculoDetalleScreen(idVehiculo: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        path: '/firmas',
        builder: (context, state) =>
            const DebugScreenTag(label: 'Firmas · Pendientes', child: FirmasPendientesScreen()),
      ),
      GoRoute(
        path: '/firmas/:id',
        builder: (context, state) => DebugScreenTag(
          label: 'Firmas · Detalle',
          child: FirmaSolicitudDetalleScreen(idFirmaSolicitud: int.parse(state.pathParameters['id']!)),
        ),
      ),
    ],
  );
});
