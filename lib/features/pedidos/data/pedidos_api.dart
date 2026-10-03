import 'package:dio/dio.dart';

import '../domain/pedido_models.dart';

/// Llamadas a `/pedidos/*` (ver `pedidos_rout.py`). Por ahora solo lo que
/// necesita el escaneo contextual de la app de depósito (ver
/// CONTEXTO_WHEREHOUSE.md): resolver un pedido por código y listar sus
/// subpedidos, ambos de solo lectura.
class PedidosApi {
  PedidosApi(this._dio);

  final Dio _dio;

  Future<PedidoDetalle> buscarPorCodigo(String codigo) async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/buscar/$codigo');
    return PedidoDetalle.fromJson(res.data!);
  }

  Future<PedidoDetalle> obtener(int idPedido) async {
    final res = await _dio.get<Map<String, dynamic>>('/pedidos/$idPedido');
    return PedidoDetalle.fromJson(res.data!);
  }

  Future<List<SubpedidoResumen>> subpedidosDe(int idPedido) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/subpedidos/list',
      queryParameters: {'id_pedido': idPedido},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SubpedidoResumen.fromJson)
        .toList();
  }

  /// Módulo "Pedidos" (seguimiento): el backend calcula solo el conjunto de
  /// estados visible según el permiso del usuario, acá solo se pasa el
  /// filtro opcional que eligió (`estado`) y la búsqueda libre.
  Future<List<SubpedidoSeguimiento>> seguimiento({
    String? q,
    String? estado,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/subpedidos/ver',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (estado != null) 'estado': estado,
      },
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SubpedidoSeguimiento.fromJson)
        .toList();
  }

  /// Complemento de `seguimiento()`: pedidos `ACTIVO` sin ningún subpedido
  /// todavía, que de otra forma quedan invisibles en `PedidosHomeScreen`
  /// (ver `pedidos_service.py::pedidos_sin_subpedidos`).
  Future<List<PedidoSinSubpedidos>> sinSubpedidos({String? q}) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/sin-subpedidos',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(PedidoSinSubpedidos.fromJson)
        .toList();
  }

  Future<List<SubpedidoItemResumen>> itemsDe(int idPedidoSubpedido) async {
    final res = await _dio.get<List<dynamic>>(
      '/pedidos/items/list',
      queryParameters: {'id_pedido_subpedido': idPedidoSubpedido},
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SubpedidoItemResumen.fromJson)
        .toList();
  }

  /// Crea solo la cabecera del pedido (`pedidos.crear`) — sin subpedidos,
  /// esos se agregan después desde la web (ver `NuevoPedidoSheet`, mismo
  /// alcance que `NuevoPedidoModal.jsx` cuando se usa sin ítems). Se manda
  /// `confirmar: true` para que nazca en `ACTIVO` en vez de `BORRADOR` —
  /// la app de depósito no tiene (todavía) una pantalla de "borradores", así
  /// que dejarlo en borrador lo dejaría invisible/sin seguimiento.
  Future<PedidoDetalle> crear({
    required String codigoPedido,
    required int idCliente,
    int? idClienteSucursal,
    String? observaciones,
    int? idLugarEntrega,
    DateTime? eta,
    int? idVehiculoEntrega,
    bool requierePgn = false,
    bool requiereAduana = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pedidos',
      data: {
        'codigo_pedido': codigoPedido,
        'id_cliente': idCliente,
        'id_cliente_sucursal': idClienteSucursal,
        'observaciones': observaciones,
        'id_lugar_entrega': idLugarEntrega,
        'eta': eta?.toIso8601String(),
        'id_vehiculo_entrega': idVehiculoEntrega,
        'requiere_pgn': requierePgn,
        'requiere_aduana': requiereAduana,
        'confirmar': true,
      },
    );
    return PedidoDetalle.fromJson(res.data!);
  }

  /// Config de creación de pedidos del almacén base del usuario logueado
  /// (ver `pedidos_config_service.py::pedidos_config_get` — el almacén se
  /// resuelve solo del lado del servidor, no se manda acá). Requiere el
  /// permiso `pedidos_config.ver`; si el usuario no lo tiene o la migración
  /// todavía no corrió, la llamada falla y quien la use debe caer al
  /// default (mismo criterio que el `.catch()` de `NuevoPedidoModal.jsx`).
  Future<PedidosConfigCreacion> configCreacion() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ventas/pedidos-config/config',
    );
    return PedidosConfigCreacion.fromJson(res.data!);
  }

  // =========================================================
  // PICKERS DE "NUEVO PEDIDO" (ver `pedido_models.dart`)
  // =========================================================

  /// `excluirOcasionales: true` para el picker de cliente de `NuevoPedidoSheet`
  /// — mismo criterio que `listarClientes` en `NuevoPedidoModal.jsx`: un
  /// cliente ocasional (ver `migracion_cliente_ocasional.sql`) no debe poder
  /// elegirse para un pedido nuevo. El POS (`PosVentaPage.jsx`/`pos_providers.dart`,
  /// que reusa este mismo método) sí los deja elegir — ahí es justamente el
  /// caso de uso — por eso el default queda en `false`.
  Future<List<ClienteSimple>> clientesListar({
    String? q,
    bool excluirOcasionales = false,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/clientes',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'limit': 30,
        'excluir_ocasionales': excluirOcasionales,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ClienteSimple.fromJson).toList();
  }

  Future<List<SucursalSimple>> sucursalesDeCliente(int idCliente) async {
    final res = await _dio.get<List<dynamic>>(
      '/clientes/$idCliente/sucursales',
    );
    return res.data!
        .cast<Map<String, dynamic>>()
        .map(SucursalSimple.fromJson)
        .toList();
  }

  Future<List<LugarEntregaSimple>> lugaresEntregaListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/lugares-entrega',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(LugarEntregaSimple.fromJson).toList();
  }

  Future<List<VehiculoEntregaSimple>> vehiculosListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/vehiculos',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q, 'limit': 50},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(VehiculoEntregaSimple.fromJson).toList();
  }

  // =========================================================
  // NUEVO SUBPEDIDO DESDE ESTÁNDAR (ver `NuevoSubpedidoSheet`)
  // =========================================================

  /// Plantillas de "Pedido Estándar" activas del cliente — la app de
  /// depósito solo permite cargar subpedidos a partir de una de estas, no
  /// crearlos en blanco (a diferencia de `ModalNuevoSubpedido.jsx` en la
  /// web, que también deja elegir un tipo suelto y cargar ítems a mano).
  Future<List<PedidoEstandarResumen>> estandaresDeCliente(
    int idCliente, {
    String? q,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/pedidos/estandar',
      queryParameters: {
        'id_cliente': idCliente,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(PedidoEstandarResumen.fromJson).toList();
  }

  Future<EstandarAplicarResultado> aplicarEstandar({
    required int idPedidoEstandar,
    required int idPedido,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pedidos/estandar/$idPedidoEstandar/aplicar',
      data: {'id_pedido': idPedido},
    );
    return EstandarAplicarResultado.fromJson(res.data!);
  }

  // =========================================================
  // MENÚ DE AJUSTES DEL PEDIDO (ver `PedidoInfoScreen`)
  // =========================================================

  /// `patch` solo puede traer claves editables según el estado del pedido
  /// (BORRADOR/ACTIVO, ver `EDITABLE_FIELDS_*` en `pedidos_service.py`) —
  /// acá se usa nada más para ETA (`eta`) y lugar de entrega
  /// (`id_lugar_entrega`).
  Future<PedidoDetalle> patch({
    required int idPedido,
    required int expectedVersion,
    required Map<String, dynamic> patch,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/pedidos/$idPedido',
      data: {'expected_version': expectedVersion, 'patch': patch},
    );
    return PedidoDetalle.fromJson(res.data!);
  }

  /// Anula el pedido completo: todos sus subpedidos activos pasan a
  /// `ANULADO` y se liberan sus reservas de stock (ver `pedido_anular`).
  Future<PedidoAnularResultado> anular({
    required int idPedido,
    required int expectedVersion,
    String? observacion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/pedido/$idPedido/anular',
      data: {
        'id_pedido': idPedido,
        'expected_version': expectedVersion,
        'observacion': observacion,
      },
    );
    return PedidoAnularResultado.fromJson(res.data!);
  }

  // =========================================================
  // SUBPEDIDO: CONFIRMAR (ver `SubpedidoItemsScreen`)
  // =========================================================

  /// BORRADOR → CONFIRMADO: crea las reservas de stock de todos los ítems
  /// activos (ver `subpedido_confirmacion_service.py::subpedido_confirmar`).
  Future<SubpedidoConfirmarResultado> confirmarSubpedido({
    required int idPedidoSubpedido,
    required int expectedVersion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/confirmar',
      data: {
        'id_pedido_subpedido': idPedidoSubpedido,
        'expected_version': expectedVersion,
      },
    );
    return SubpedidoConfirmarResultado.fromJson(res.data!);
  }

  /// Marca "esperar" (`acepta_fulfillment = 0`, libera la reserva física de
  /// picking si la hubiera) para los ítems que quedaron con cantidad
  /// pendiente tras confirmar — ver `subpedido_aplicar_decisiones_service.py`.
  /// La app de depósito no ofrece el picker de decisiones por ítem que tiene
  /// la web (combinar / compra externa / eliminar); todo lo sin stock queda
  /// en espera automática de reposición.
  Future<void> aplicarDecisionEsperar({
    required int idPedidoSubpedido,
    required List<int> idsItems,
  }) async {
    if (idsItems.isEmpty) return;
    await _dio.post<Map<String, dynamic>>(
      '/pedidos/subpedidos/$idPedidoSubpedido/aplicar-decisiones',
      data: {
        'items': idsItems
            .map(
              (id) => {'id_pedido_subpedido_item': id, 'decision': 'esperar'},
            )
            .toList(),
      },
    );
  }
}
