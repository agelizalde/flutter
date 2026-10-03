import 'package:dio/dio.dart';

import '../domain/picking_models.dart';

/// Payload de `POST /picking-operario/tarea/{id}/completar` (ver
/// `picking_operario_service.py::CompletarTareaIn` — el cajón ya NO se manda
/// acá, se resuelve server-side del `id_contenedor_activo` de la sesión).
class CompletarTareaIn {
  CompletarTareaIn({required this.idSesion, required this.cantidadPickeada, this.codigoBarra});

  final int idSesion;
  final double cantidadPickeada;

  /// Código escaneado (Ajustes -> Operaciones -> Picking -> APP - Picking ->
  /// "Escaneo de producto") — `null` si no se escaneó nada. El backend lo
  /// exige y valida contra `productos_codigos_barra` solo si
  /// `escaneo_producto_obligatorio` está prendido para este almacén Y el
  /// producto tiene algún código activo cargado.
  final String? codigoBarra;

  Map<String, dynamic> toJson() => {
    'id_sesion': idSesion,
    'cantidad_pickeada': cantidadPickeada,
    if (codigoBarra != null) 'codigo_barra': codigoBarra,
  };
}

/// Llamadas a `/picking-operario/*` (ver `picking_operario_rout.py`). Cubre
/// el flujo core del operario, despickeo/devolución (ver
/// CONTEXTO_WHEREHOUSE.md §12d/§12e), config efectiva por almacén y las
/// acciones de supervisor (cancelar/modificar-cantidad) y devolver-ítem —
/// no incluye informes.
class PickingApi {
  PickingApi(this._dio);

  final Dio _dio;

  Future<MisTareasResponse> misTareas() async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-operario/mis-tareas');
    return MisTareasResponse.fromJson(res.data!);
  }

  /// Config efectiva de Ajustes -> Operaciones -> Picking para el almacén
  /// real de este subpedido — se pide antes de operar para adaptar la UI
  /// (ver [PickingConfig]).
  Future<PickingConfig> config({required int idPedidoSubpedido}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/picking-operario/config',
      queryParameters: {'id_pedido_subpedido': idPedidoSubpedido},
    );
    return PickingConfig.fromJson(res.data!);
  }

  /// `PickingConfig.appPickingHabilitado` del almacén BASE del propio
  /// usuario (`usuarios_datos.id_almacen_seleccionado`) — a diferencia de
  /// [config], no necesita un subpedido: se pide ANTES de elegir uno, solo
  /// para decidir si el Home muestra la tarjeta "Picking" (ver
  /// `pickingAppHabilitadoProvider`).
  Future<bool> appHabilitado() async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-operario/app-habilitado');
    return res.data!['habilitado'] as bool? ?? true;
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

  /// `permite_cancelar_tarea` (Ajustes -> Operaciones -> Picking) gatea si
  /// esta acción se ofrece; `cancelar_requiere_supervisor` gatea si hace
  /// falta mandar credenciales (si no, quedan en `null` y el propio
  /// operario queda como responsable — ver `_resolver_actor_o_supervisor`
  /// en el backend).
  Future<CancelarTareaResultado> cancelarTarea({
    required int idStockReservaDetalle,
    String? supervisorEmail,
    String? supervisorPassword,
    String? motivo,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-operario/tarea/$idStockReservaDetalle/cancelar',
      data: {
        'supervisor_email': supervisorEmail,
        'supervisor_password': supervisorPassword,
        'motivo': motivo,
      },
    );
    return CancelarTareaResultado.fromJson(res.data!);
  }

  /// `permite_modificar_cantidad` gatea si esta acción se ofrece;
  /// `modificar_cantidad_requiere_supervisor` gatea las credenciales, igual
  /// criterio que [cancelarTarea].
  Future<ModificarCantidadResultado> modificarCantidad({
    required int idStockReservaDetalle,
    required double nuevaCantidad,
    String? supervisorEmail,
    String? supervisorPassword,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-operario/tarea/$idStockReservaDetalle/modificar-cantidad',
      data: {
        'nueva_cantidad': nuevaCantidad,
        'supervisor_email': supervisorEmail,
        'supervisor_password': supervisorPassword,
      },
    );
    return ModificarCantidadResultado.fromJson(res.data!);
  }

  Future<CajonItemsResponse> cajonItems(int idContenedor) async {
    final res = await _dio.get<Map<String, dynamic>>('/picking-operario/cajon/$idContenedor/items');
    return CajonItemsResponse.fromJson(res.data!);
  }

  /// `permite_devolver_item` gatea si esta acción se ofrece; server-side
  /// también rechaza si el subpedido ya tiene control activo/completado
  /// (ver `puede_devolver` por ítem en [cajonItems]).
  Future<DevolverItemResultado> devolverItem({
    required int idPickingItem,
    required double cantidadDevolver,
    String? motivo,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/picking-operario/picking-item/$idPickingItem/devolver',
      data: {'cantidad_devolver': cantidadDevolver, 'motivo': motivo},
    );
    return DevolverItemResultado.fromJson(res.data!);
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
