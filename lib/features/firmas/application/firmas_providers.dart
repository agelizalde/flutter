import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/notificaciones_ws_provider.dart';
import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../auth/application/auth_controller.dart';
import '../data/firmas_api.dart';
import '../data/firmas_repository.dart';
import '../data/oc_detalle_api.dart';
import '../data/oc_detalle_repository.dart';
import '../data/oc_diferencia_peso_api.dart';
import '../data/oc_diferencia_peso_repository.dart';
import '../data/oc_exceso_cantidad_api.dart';
import '../data/oc_exceso_cantidad_repository.dart';
import '../data/op_detalle_api.dart';
import '../data/op_detalle_repository.dart';
import '../domain/firma_solicitud.dart';
import '../domain/oc_detalle.dart';
import '../domain/oc_diferencia_peso_detalle.dart';
import '../domain/oc_exceso_cantidad_detalle.dart';
import '../domain/op_detalle.dart';

final firmasApiProvider = Provider<FirmasApi>((ref) {
  return FirmasApi(ref.watch(dioClientProvider).dio);
});

final firmasRepositoryProvider = Provider<FirmasRepository>((ref) {
  return FirmasRepository(ref.watch(firmasApiProvider));
});

final ocDetalleApiProvider = Provider<OcDetalleApi>((ref) {
  return OcDetalleApi(ref.watch(dioClientProvider).dio);
});

final ocDetalleRepositoryProvider = Provider<OcDetalleRepository>((ref) {
  return OcDetalleRepository(ref.watch(ocDetalleApiProvider));
});

final ocDiferenciaPesoApiProvider = Provider<OcDiferenciaPesoApi>((ref) {
  return OcDiferenciaPesoApi(ref.watch(dioClientProvider).dio);
});

final ocDiferenciaPesoRepositoryProvider = Provider<OcDiferenciaPesoRepository>((ref) {
  return OcDiferenciaPesoRepository(ref.watch(ocDiferenciaPesoApiProvider));
});

final ocExcesoCantidadApiProvider = Provider<OcExcesoCantidadApi>((ref) {
  return OcExcesoCantidadApi(ref.watch(dioClientProvider).dio);
});

final ocExcesoCantidadRepositoryProvider = Provider<OcExcesoCantidadRepository>((ref) {
  return OcExcesoCantidadRepository(ref.watch(ocExcesoCantidadApiProvider));
});

final opDetalleApiProvider = Provider<OpDetalleApi>((ref) {
  return OpDetalleApi(ref.watch(dioClientProvider).dio);
});

final opDetalleRepositoryProvider = Provider<OpDetalleRepository>((ref) {
  return OpDetalleRepository(ref.watch(opDetalleApiProvider));
});

/// Todo lo PENDIENTE de firma (cualquier módulo: OC, OP, entrega de
/// pedido...), con `puedeFirmarYo` calculado cruzando contra la respuesta
/// de `solo_para_mi=true` (mi rol está habilitado en la regla que matcheó)
/// más el permiso de fallback del usuario si la solicitud no tiene regla —
/// mismo criterio que `FirmasPendientesPage.jsx` en la web.
///
/// Piloto de tiempo real: escucha `notificacionesWsProvider` y se invalida
/// apenas llega un evento `FIRMAS_SOLICITUD` (nueva solicitud creada, ver
/// `firmas_solicitudes.py`), en vez de esperar el próximo poll. El
/// `enableSilentRefresh` de acá abajo queda como red de respaldo con
/// intervalo más largo — si el WS se cae y no logra reconectar, la lista
/// igual se termina actualizando sola.
final firmasPendientesProvider = FutureProvider.autoDispose<List<FirmaSolicitud>>((ref) async {
  enableSilentRefresh(ref, interval: const Duration(seconds: 60));

  ref.listen(notificacionesWsProvider, (previous, next) {
    final evento = next.value;
    if (evento != null && evento['tipo_entidad'] == 'FIRMAS_SOLICITUD') {
      ref.invalidateSelf();
    }
  });

  final repo = ref.watch(firmasRepositoryProvider);
  final usuario = ref.watch(authControllerProvider).value;

  final resultados = await Future.wait([
    repo.listarSolicitudes(estado: 'PENDIENTE'),
    repo.listarSolicitudes(estado: 'PENDIENTE', soloParaMi: true),
  ]);
  final todas = resultados[0];
  final paraMiIds = resultados[1].map((s) => s.idFirmaSolicitud).toSet();
  final permisos = usuario?.permissions ?? const <String>[];

  return todas.map((s) {
    final porFallback =
        s.idRegla == null && s.documentoTipoPermisoFallback != null && permisos.contains(s.documentoTipoPermisoFallback);
    return s.copyWith(puedeFirmarYo: paraMiIds.contains(s.idFirmaSolicitud) || porFallback);
  }).toList();
});

final firmaSolicitudDetalleProvider = FutureProvider.autoDispose.family<FirmaSolicitud, int>((ref, id) {
  return ref.watch(firmasRepositoryProvider).getSolicitud(id);
});

/// Detalle de la OC (header + ítems) para una solicitud `OC` — pide esto
/// aparte porque `/firmas/solicitudes/{id}` es intencionalmente genérico
/// (ver `_DatosCard`), igual que [pedidoEntregaResumenProvider] para
/// `PEDIDO_ENTREGA`. `idOc` es `solicitud.idDocumento`.
final ocDetalleProvider = FutureProvider.autoDispose.family<OcDetalle, int>((ref, idOc) {
  return ref.watch(ocDetalleRepositoryProvider).getOc(idOc);
});

/// Últimos precios de compra de un producto (cualquier proveedor) — se pide
/// al tocar un ítem del detalle de la OC, para decidir si aprobar o
/// rechazar la firma.
final ocUltimasComprasProvider = FutureProvider.autoDispose.family<List<OcUltimaCompra>, int>((ref, idProducto) {
  return ref.watch(ocDetalleRepositoryProvider).ultimasCompras(idProducto);
});

/// Detalle de una diferencia de peso (header + ítems) para una solicitud
/// `OC_DIFERENCIA_PESO` — mismo criterio que [ocDetalleProvider]:
/// `/firmas/solicitudes/{id}` es genérico, así que esto se pide aparte.
/// `idDiferencia` es `solicitud.idDocumento`.
final ocDiferenciaPesoProvider = FutureProvider.autoDispose.family<OcDiferenciaPesoDetalle, int>((ref, idDiferencia) {
  return ref.watch(ocDiferenciaPesoRepositoryProvider).getDiferenciaPeso(idDiferencia);
});

/// Detalle de una excepción de cantidad (header + ítems) para una solicitud
/// `OC_EXCESO_CANTIDAD` — mismo criterio que [ocDiferenciaPesoProvider].
/// `idExceso` es `solicitud.idDocumento`.
final ocExcesoCantidadProvider = FutureProvider.autoDispose.family<OcExcesoCantidadDetalle, int>((ref, idExceso) {
  return ref.watch(ocExcesoCantidadRepositoryProvider).getExcesoCantidad(idExceso);
});

/// Detalle de la OP (header + ítems del resumen de cantidades) para una
/// solicitud `OP` — mismo criterio que [ocDetalleProvider]: `idOrdenPago` es
/// `solicitud.idDocumento`.
final opDetalleProvider = FutureProvider.autoDispose.family<OpDetalle, int>((ref, idOrdenPago) {
  return ref.watch(opDetalleRepositoryProvider).getOp(idOrdenPago);
});
