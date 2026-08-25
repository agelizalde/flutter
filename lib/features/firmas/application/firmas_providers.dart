import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/silent_refresh.dart';
import '../../auth/application/auth_controller.dart';
import '../data/firmas_api.dart';
import '../data/firmas_repository.dart';
import '../domain/firma_solicitud.dart';

final firmasApiProvider = Provider<FirmasApi>((ref) {
  return FirmasApi(ref.watch(dioClientProvider).dio);
});

final firmasRepositoryProvider = Provider<FirmasRepository>((ref) {
  return FirmasRepository(ref.watch(firmasApiProvider));
});

/// Todo lo PENDIENTE de firma (cualquier módulo: OC, OP, entrega de
/// pedido...), con `puedeFirmarYo` calculado cruzando contra la respuesta
/// de `solo_para_mi=true` (mi rol está habilitado en la regla que matcheó)
/// más el permiso de fallback del usuario si la solicitud no tiene regla —
/// mismo criterio que `FirmasPendientesPage.jsx` en la web. Con
/// `enableSilentRefresh`, igual que notificaciones/mis tareas.
final firmasPendientesProvider = FutureProvider.autoDispose<List<FirmaSolicitud>>((ref) async {
  enableSilentRefresh(ref);
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
