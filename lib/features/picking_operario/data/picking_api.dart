import 'package:dio/dio.dart';

import '../domain/picking_models.dart';

/// Payload de `POST /picking-operario/tarea/{id}/completar` (ver
/// `picking_operario_service.py::CompletarTareaIn` — el cajón ya NO se manda
/// acá, se resuelve server-side del `id_contenedor_activo` de la sesión).
class CompletarTareaIn {
  CompletarTareaIn({required this.idSesion, required this.cantidadPickeada});

  final int idSesion;
  final double cantidadPickeada;

  Map<String, dynamic> toJson() => {
    'id_sesion': idSesion,
    'cantidad_pickeada': cantidadPickeada,
  };
}

/// Llamadas a `/picking-operario/*` (ver `picking_operario_rout.py`). Cubre
/// el flujo core del operario más despickeo/devolución (ver
/// CONTEXTO_WHEREHOUSE.md §12d/§12e) — no incluye cancelar/modificar-cantidad
/// (supervisor), devolver-item ni informes.
class PickingApi {
  PickingApi(this._dio);

  final Dio _dio;

  Future<MisTareasResponse> misTareas() async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-operario/mis-tareas');
    return MisTareasResponse.fromJson(res.data!);
  }

  /// Devuelve el `id_sesion` (nueva o retomada) — el shape completo de la
  /// sesión (iniciado_en, cajón activo) se pide aparte con [sesionActiva],
  /// porque `accion='iniciada'` (sesión nueva) no los trae en la respuesta.
  Future<int> iniciarZona({required int idPedidoSubpedido, required int idZona}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-operario/zona/iniciar',
      data: {'id_pedido_subpedido': idPedidoSubpedido, 'id_zona': idZona},
    );
    return res.data!['id_sesion'] as int;
  }

  Future<SesionZona?> sesionActiva() async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-operario/zona/sesion/activa');
    final sesion = res.data!['sesion'];
    return sesion == null ? null : SesionZona.fromJson(sesion as Map<String, dynamic>);
  }

  /// `idContenedor: null` = "picking sin cajón" (limpia el cajón activo de
  /// la sesión, si había uno).
  Future<SeleccionarCajonResultado> seleccionarCajon({
    required int idSesion,
    required int? idContenedor,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-operario/zona/sesion/$idSesion/cajon',
      data: {'id_contenedor': idContenedor},
    );
    return SeleccionarCajonResultado.fromJson(res.data!);
  }

  Future<void> terminarSesion(int idSesion) async {
    await _dio.post<Map<String, dynamic>>('/picking-operario/zona/sesion/$idSesion/terminar');
  }

  /// `idPedidoSubpedido` habilita el chequeo server-side de compatibilidad:
  /// si el cajón tiene productos activos de OTRO subpedido, el backend
  /// rechaza la búsqueda con 400 (ver `_conflicto_pedido_en_cajon` en
  /// `picking_operario_service.py`).
  Future<ContenedorPicking> buscarContenedor(String codigo, {int? idPedidoSubpedido}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/picking-operario/contenedor/buscar',
      queryParameters: {
        'codigo': codigo,
        if (idPedidoSubpedido != null) 'id_pedido_subpedido': idPedidoSubpedido,
      },
    );
    return ContenedorPicking.fromJson(res.data!);
  }

  Future<ContenedorDetalle> buscarContenedorDetalle(String codigo) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/picking-operario/contenedor/detalle',
      queryParameters: {'codigo': codigo},
    );
    return ContenedorDetalle.fromJson(res.data!);
  }

  Future<CompletarTareaResultado> completarTarea({
    required int idStockReservaDetalle,
    required CompletarTareaIn payload,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-operario/tarea/$idStockReservaDetalle/completar',
      data: payload.toJson(),
    );
    return CompletarTareaResultado.fromJson(res.data!);
  }

  Future<List<TareaDespickeo>> misTareasDespickeo() async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-operario/despickeo/mis-tareas');
    return (res.data!['tareas'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(TareaDespickeo.fromJson)
        .toList();
  }

  Future<ConfirmarDespickeoResultado> confirmarDespickeo({
    required int idDespickeoTarea,
    String? observacion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-operario/despickeo/$idDespickeoTarea/confirmar',
      data: {'observacion': observacion},
    );
    return ConfirmarDespickeoResultado.fromJson(res.data!);
  }
}
