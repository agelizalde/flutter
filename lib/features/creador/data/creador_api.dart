import 'package:dio/dio.dart';

import '../domain/creador_models.dart';

/// Todas las llamadas propias del módulo "Creador" (alta/edición rápida de
/// Proveedores, Marcas, Productos, Zonas y Ubicaciones). Es la única feature
/// de la app que escribe estos 5 catálogos desde Flutter — el resto de las
/// features solo los buscan de solo lectura (`stock/data/proveedores_api.dart`,
/// `stock/data/productos_api.dart`, `recepcion/data/ubicaciones_api.dart`),
/// por eso no se reutilizan esos clientes: acá se necesitan más campos
/// (`row_version`, `ruc`, `dv`, etc.) que esos modelos "simples" no traen.
class CreadorApi {
  CreadorApi(this._dio);

  final Dio _dio;

  // =========================================================
  // CATÁLOGOS DE REFERENCIA (pickers)
  // =========================================================

  Future<List<MarcaCreador>> marcasListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos/marcas',
      queryParameters: {
        'incluir_inactivas': false,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(MarcaCreador.fromJson).toList();
  }

  Future<MarcaCreador> marcaCrear({required String nombre}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/productos/marcas',
      data: {'nombre': nombre},
    );
    return MarcaCreador.fromJson(res.data!);
  }

  Future<MarcaCreador> marcaEditar({
    required int idMarca,
    required String nombre,
    required int expectedVersion,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/productos/marcas/$idMarca',
      data: {'nombre': nombre, 'expected_version': expectedVersion},
    );
    return MarcaCreador.fromJson(res.data!);
  }

  /// Nota el `/` final del prefix (ver `categorias_producto_rout.py`).
  Future<List<CategoriaCreador>> categoriasListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos/categorias/',
      queryParameters: {
        'incluir_inactivas': false,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(CategoriaCreador.fromJson).toList();
  }

  Future<List<UnidadCreador>> unidadesListar() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos/unidades',
      queryParameters: {
        'incluir_inactivas': false,
        'order_by': 'nombre',
        'order_dir': 'asc',
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(UnidadCreador.fromJson).toList();
  }

  Future<List<ImpuestoCreador>> impuestosListar() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/impuestos',
      queryParameters: {'incluir_inactivos': false, 'limit': 200},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ImpuestoCreador.fromJson).toList();
  }

  Future<List<MonedaCreador>> monedasListar() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/monedas',
      queryParameters: {'activo': true, 'page': 1, 'page_size': 200},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(MonedaCreador.fromJson).toList();
  }

  // =========================================================
  // PROVEEDORES (ver `proveedores_service.py`)
  // =========================================================

  Future<List<ProveedorCreador>> proveedoresListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/proveedores',
      queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'page': 1,
        'page_size': 50,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProveedorCreador.fromJson).toList();
  }

  Future<ProveedorCreador> proveedorCrear({
    String? nombreComercial,
    required String razonSocial,
    String? ruc,
    String? codigoVerificador,
    int? idMonedaBase,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/proveedores',
      data: {
        'nombre_comercial': nombreComercial,
        'razon_social': razonSocial,
        'ruc': ruc,
        'dv': codigoVerificador,
        // Defaults del spec — el backend ya los toma por su cuenta si se
        // omiten, pero se los mandamos explícitos para que quede claro qué
        // se está precargando.
        'tipo_persona': 'JURIDICA',
        'tipo_pago_compra': 'CONTADO',
        'id_moneda_base': idMonedaBase,
      },
    );
    return ProveedorCreador.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  Future<ProveedorCreador> proveedorEditar({
    required int idProveedor,
    required int expectedVersion,
    String? nombreComercial,
    required String razonSocial,
    String? ruc,
    String? codigoVerificador,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/proveedores/$idProveedor',
      data: {
        'expected_version': expectedVersion,
        'nombre_comercial': nombreComercial,
        'razon_social': razonSocial,
        'ruc': ruc,
        'dv': codigoVerificador,
      },
    );
    return ProveedorCreador.fromJson(res.data!['item'] as Map<String, dynamic>);
  }

  // =========================================================
  // PRODUCTOS (ver `productos_crear_ver.py` / `productos_editar.py`)
  // =========================================================

  Future<List<ProductoCreador>> productosListar({String? q}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/productos',
      queryParameters: {if (q != null && q.isNotEmpty) 'q': q, 'limit': 50},
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ProductoCreador.fromJson).toList();
  }

  Future<ProductoAlmacenajeSimple> productoAlmacenaje(int idProducto) async {
    final res = await _dio.get<Map<String, dynamic>>('/productos/$idProducto');
    return ProductoAlmacenajeSimple.fromJson(
      res.data!['almacenaje'] as Map<String, dynamic>?,
    );
  }

  Future<ProductoCreador> productoCrear({
    required String codigoInterno,
    required String nombre,
    int? idMarca,
    int? idCategoriaTipo,
    required int idUnidadBase,
    int? idProveedorCabecera,
    int? idImpuesto,
    required bool requiereVencimientoLote,
    int? vidaUtilDias,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/productos',
      data: {
        'codigo_interno': codigoInterno,
        'nombre': nombre,
        'id_marca': idMarca,
        'id_categoria_tipo': idCategoriaTipo,
        // Defaults del spec: producto físico, vendible/comprable/maneja
        // stock, no ficticio — el resto se ajusta después desde el detalle
        // completo en la web si hace falta.
        'clase_producto': 'FISICO',
        'vendible': true,
        'comprable': true,
        'maneja_stock': true,
        'es_comercial': false,
        'id_unidad_base': idUnidadBase,
        'id_proveedor_cabecera': idProveedorCabecera,
        'id_impuesto': idImpuesto,
        'almacenaje': {
          'requiere_lote': requiereVencimientoLote,
          'control_vencimiento': requiereVencimientoLote,
          'vida_util_dias': requiereVencimientoLote ? vidaUtilDias : null,
        },
      },
    );
    return ProductoCreador.fromJson(res.data!);
  }

  Future<ProductoCreador> productoEditar({
    required int idProducto,
    required int expectedVersion,
    required String nombre,
    int? idMarca,
    int? idCategoriaTipo,
    required int idUnidadBase,
    int? idProveedorCabecera,
    int? idImpuesto,
    required bool requiereVencimientoLote,
    int? vidaUtilDias,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/productos/$idProducto',
      data: {
        'expected_version': expectedVersion,
        'patch': {
          'nombre': nombre,
          'id_marca': idMarca,
          'id_categoria_tipo': idCategoriaTipo,
          'id_unidad_base': idUnidadBase,
          'id_proveedor_cabecera': idProveedorCabecera,
          'id_impuesto': idImpuesto,
          'almacenaje': {
            'requiere_lote': requiereVencimientoLote,
            'control_vencimiento': requiereVencimientoLote,
            'vida_util_dias': requiereVencimientoLote ? vidaUtilDias : null,
          },
        },
      },
    );
    return ProductoCreador.fromJson(
      res.data!['producto'] as Map<String, dynamic>,
    );
  }

  // =========================================================
  // CÓDIGOS DE BARRA (ver `producto_codigo_barra_service.py`)
  // =========================================================

  /// A diferencia del resto de los listados del Creador, este endpoint
  /// devuelve un array plano (no `{items: [...]}`, ver
  /// `producto_codigo_barra_rout.py::listar_productos_codigos_barra`).
  Future<List<CodigoBarraCreador>> codigosBarraListar({
    int? idProducto,
    String? q,
  }) async {
    final res = await _dio.get<List<dynamic>>(
      '/productos/codigos-barra',
      queryParameters: {
        'id_producto': ?idProducto,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    final items = (res.data ?? const []).cast<Map<String, dynamic>>();
    return items.map(CodigoBarraCreador.fromJson).toList();
  }

  Future<CodigoBarraCreador> codigoBarraCrear({
    required int idProducto,
    required String codigoBarra,
    required String tipoCodigo,
    bool principal = false,
    String? observaciones,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/productos/codigos-barra',
      data: {
        'id_producto': idProducto,
        'codigo_barra': codigoBarra,
        'tipo_codigo': tipoCodigo,
        'principal': principal,
        'observaciones': observaciones,
      },
    );
    return CodigoBarraCreador.fromJson(res.data!);
  }

  Future<CodigoBarraCreador> codigoBarraEditar({
    required int idCodigoBarra,
    required int expectedVersion,
    required String codigoBarra,
    required String tipoCodigo,
    bool principal = false,
    String? observaciones,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/productos/codigos-barra/$idCodigoBarra',
      data: {
        'expected_version': expectedVersion,
        'codigo_barra': codigoBarra,
        'tipo_codigo': tipoCodigo,
        'principal': principal,
        'observaciones': observaciones,
      },
    );
    return CodigoBarraCreador.fromJson(res.data!);
  }

  Future<CodigoBarraCreador> codigoBarraDesactivar({
    required int idCodigoBarra,
    required int expectedVersion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/productos/codigos-barra/$idCodigoBarra/desactivar',
      data: {'expected_version': expectedVersion},
    );
    return CodigoBarraCreador.fromJson(res.data!);
  }

  Future<CodigoBarraCreador> codigoBarraReactivar({
    required int idCodigoBarra,
    required int expectedVersion,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/productos/codigos-barra/$idCodigoBarra/reactivar',
      data: {'expected_version': expectedVersion},
    );
    return CodigoBarraCreador.fromJson(res.data!);
  }

  // =========================================================
  // ZONAS (ver `ubicacion_zona.py`)
  // =========================================================

  Future<List<ZonaCreador>> zonasListar({
    required int idAlmacen,
    String? q,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ubicaciones/zonas',
      queryParameters: {
        'id_almacen': idAlmacen,
        if (q != null && q.isNotEmpty) 'q': q,
        'page': 1,
        'page_size': 100,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(ZonaCreador.fromJson).toList();
  }

  Future<ZonaCreador> zonaCrear({
    required int idAlmacen,
    required String nombre,
    String? codigo,
    required String tipo,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/ubicaciones/zonas',
      data: {
        'id_almacen': idAlmacen,
        'nombre': nombre,
        'codigo': codigo,
        'tipo': tipo,
      },
    );
    return ZonaCreador.fromJson(res.data!);
  }

  Future<ZonaCreador> zonaEditar({
    required int idZona,
    required int expectedVersion,
    required String nombre,
    String? codigo,
    required String tipo,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/ubicaciones/zonas/$idZona',
      data: {
        'expected_version': expectedVersion,
        'nombre': nombre,
        'codigo': codigo,
        'tipo': tipo,
      },
    );
    return ZonaCreador.fromJson(res.data!);
  }

  // =========================================================
  // UBICACIONES (ver `ubicacion_ubicacion.py`)
  // =========================================================

  Future<List<UbicacionCreador>> ubicacionesListar({
    int? idZona,
    int? idAlmacen,
    String? nivel,
    String? q,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/ubicaciones',
      queryParameters: {
        'id_zona': ?idZona,
        'id_almacen': ?idAlmacen,
        'nivel': ?nivel,
        if (q != null && q.isNotEmpty) 'q': q,
        'activo': true,
        'page': 1,
        'page_size': 100,
      },
    );
    final items = (res.data!['items'] as List).cast<Map<String, dynamic>>();
    return items.map(UbicacionCreador.fromJson).toList();
  }

  Future<UbicacionCreador> ubicacionCrear({
    required int idZona,
    required String nombre,
    required String codigo,
    required String tipoUbicacion,
    required String nivel,
    int? idUbicacionPadre,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/ubicaciones',
      data: {
        'id_zona': idZona,
        'nombre': nombre,
        'codigo': codigo,
        'tipo_ubicacion': tipoUbicacion,
        'nivel': nivel,
        'id_ubicacion_padre': idUbicacionPadre,
      },
    );
    return UbicacionCreador.fromJson(res.data!);
  }

  Future<UbicacionCreador> ubicacionEditar({
    required int idUbicacion,
    required int expectedVersion,
    required int idZona,
    required String nombre,
    required String codigo,
    required String tipoUbicacion,
    required String nivel,
    int? idUbicacionPadre,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/ubicaciones/$idUbicacion',
      data: {
        'expected_version': expectedVersion,
        'id_zona': idZona,
        'nombre': nombre,
        'codigo': codigo,
        'tipo_ubicacion': tipoUbicacion,
        'nivel': nivel,
        'id_ubicacion_padre': idUbicacionPadre,
      },
    );
    return UbicacionCreador.fromJson(res.data!);
  }
}
