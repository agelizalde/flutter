import '../../picking_operario/domain/picking_models.dart';

/// Resultado de resolver un código escaneado desde el botón de escaneo
/// genérico (Home / bottom nav) — puede ser un producto, una ubicación, una
/// zona, una OC, un pedido, una orden de producción, un contenedor, o no
/// reconocerse. No hay un tipo aparte para "recepción": no tiene código
/// propio en la base (solo `id_recepcion` numérico visible en pantalla) —
/// se cubre enriqueciendo las acciones de [EscaneoOc], que es el código
/// real que dispara una recepción.
sealed class EscaneoResultado {
  const EscaneoResultado();
}

class EscaneoProducto extends EscaneoResultado {
  const EscaneoProducto({required this.idProducto});

  final int idProducto;
}

class EscaneoUbicacion extends EscaneoResultado {
  const EscaneoUbicacion({required this.idUbicacion, required this.nombre});

  final int idUbicacion;
  final String nombre;
}

/// Escanear el código de una zona lleva al listado de sus ubicaciones
/// (`ZonaUbicacionesScreen`), no directo a un stock puntual — una zona
/// agrupa varias ubicaciones.
class EscaneoZona extends EscaneoResultado {
  const EscaneoZona({required this.idZona, required this.nombre});

  final int idZona;
  final String nombre;
}

class EscaneoOc extends EscaneoResultado {
  const EscaneoOc({required this.idOc});

  final int idOc;
}

class EscaneoPedido extends EscaneoResultado {
  const EscaneoPedido({required this.idPedido});

  final int idPedido;
}

class EscaneoOrdenProduccion extends EscaneoResultado {
  const EscaneoOrdenProduccion({required this.idOrden});

  final int idOrden;
}

/// Ya viene con el detalle resuelto (no solo el id): el mismo
/// `GET /picking-operario/contenedor/detalle` que la confirma como
/// contenedor válido ya trae el subpedido/ítems, así que no hace falta un
/// segundo viaje al backend para mostrarlos.
class EscaneoContenedor extends EscaneoResultado {
  const EscaneoContenedor({required this.detalle});

  final ContenedorDetalle detalle;
}

class EscaneoNoEncontrado extends EscaneoResultado {
  const EscaneoNoEncontrado();
}
