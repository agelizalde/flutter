import '../../../core/utils/parsing.dart';

/// Fila de `GET /vehiculos` / `GET /vehiculos/{id}` (ver `vehiculos_service.py`).
/// Versión completa para el módulo Mantenimiento — distinta de
/// `VehiculoEntregaSimple` (features/pedidos), que solo trae lo mínimo para
/// el picker de vehículo de un pedido.
class Vehiculo {
  Vehiculo({
    required this.idVehiculo,
    required this.nombre,
    this.tipo,
    this.patente,
    this.capacidadKg,
    this.capacidadLitros,
    required this.habilitadoCombustible,
    required this.habilitadoAlimentos,
    required this.habilitadoOtro,
    this.descripcion,
    this.fotoUrl,
    this.kilometrajeActual,
    required this.activo,
    required this.rowVersion,
  });

  factory Vehiculo.fromJson(Map<String, dynamic> j) => Vehiculo(
    idVehiculo: j['id_vehiculo'] as int,
    nombre: j['nombre'] as String? ?? '',
    tipo: j['tipo'] as String?,
    patente: j['patente'] as String?,
    capacidadKg: parseDoubleOrNull(j['capacidad_kg']),
    capacidadLitros: parseDoubleOrNull(j['capacidad_litros']),
    habilitadoCombustible: j['habilitado_combustible'] as bool? ?? false,
    habilitadoAlimentos: j['habilitado_alimentos'] as bool? ?? false,
    habilitadoOtro: j['habilitado_otro'] as bool? ?? false,
    descripcion: j['descripcion'] as String?,
    fotoUrl: j['foto_url'] as String?,
    kilometrajeActual: j['kilometraje_actual'] as int?,
    activo: j['activo'] as bool? ?? true,
    rowVersion: j['row_version'] as int? ?? 1,
  );

  final int idVehiculo;
  final String nombre;
  final String? tipo;
  final String? patente;
  final double? capacidadKg;
  final double? capacidadLitros;
  final bool habilitadoCombustible;
  final bool habilitadoAlimentos;
  final bool habilitadoOtro;
  final String? descripcion;
  final String? fotoUrl;
  final int? kilometrajeActual;
  final bool activo;
  final int rowVersion;

  String get subtituloDisplay {
    final partes = [tipo, patente].where((p) => p != null && p.trim().isNotEmpty).toList();
    return partes.join(' · ');
  }
}

/// Fila de `GET /vehiculos/{id}/mantenimientos` (ver
/// `vehiculos_mantenimientos_service.py`). El backend soporta mantenimientos
/// de una parte asignada (`id_config`, con `parte_nombre`) o libres (solo
/// `titulo`) — la app de depósito, en su versión simple, solo carga libres,
/// pero igual muestra el historial completo (incluye los de parte asignada
/// que se hayan cargado desde el ERP web).
class Mantenimiento {
  Mantenimiento({
    required this.idMantenimiento,
    required this.idVehiculo,
    this.idConfig,
    this.parteNombre,
    this.titulo,
    this.descripcion,
    required this.fechaRealizado,
    this.kilometraje,
    this.costo,
    this.archivoUrl,
    this.archivoNombreOriginal,
    this.responsableNombre,
    required this.activo,
    required this.rowVersion,
  });

  factory Mantenimiento.fromJson(Map<String, dynamic> j) => Mantenimiento(
    idMantenimiento: j['id_mantenimiento'] as int,
    idVehiculo: j['id_vehiculo'] as int,
    idConfig: j['id_config'] as int?,
    parteNombre: j['parte_nombre'] as String?,
    titulo: j['titulo'] as String?,
    descripcion: j['descripcion'] as String?,
    fechaRealizado: DateTime.parse(j['fecha_realizado'] as String),
    kilometraje: j['kilometraje'] as int?,
    costo: parseDoubleOrNull(j['costo']),
    archivoUrl: j['archivo_url'] as String?,
    archivoNombreOriginal: j['archivo_nombre_original'] as String?,
    responsableNombre: j['responsable_nombre'] as String?,
    activo: j['activo'] as bool? ?? true,
    rowVersion: j['row_version'] as int? ?? 1,
  );

  final int idMantenimiento;
  final int idVehiculo;
  final int? idConfig;
  final String? parteNombre;
  final String? titulo;
  final String? descripcion;
  final DateTime fechaRealizado;
  final int? kilometraje;
  final double? costo;
  final String? archivoUrl;
  final String? archivoNombreOriginal;
  final String? responsableNombre;
  final bool activo;
  final int rowVersion;

  /// El de la parte asignada si viene de una config, si no el libre.
  String get tituloDisplay => parteNombre ?? titulo ?? 'Mantenimiento';

  bool get esImagenAdjunta {
    final url = archivoUrl?.toLowerCase() ?? '';
    return url.endsWith('.png') || url.endsWith('.jpg') || url.endsWith('.jpeg') || url.endsWith('.webp');
  }
}
