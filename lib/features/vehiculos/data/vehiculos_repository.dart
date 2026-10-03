import 'package:image_picker/image_picker.dart';

import '../domain/vehiculo_models.dart';
import 'vehiculos_api.dart';

/// Repositorio de Vehículos/Mantenimiento — passthrough fino sobre
/// [VehiculosApi], mismo patrón que `ExpedicionRepository`: sin try/catch ni
/// cache local, los errores se propagan como `DioException` y se capturan en
/// la pantalla con `describeError`.
class VehiculosRepository {
  VehiculosRepository(this._api);

  final VehiculosApi _api;

  Future<List<Vehiculo>> listar({String? q, bool? activo}) => _api.listar(q: q, activo: activo);

  Future<Vehiculo> detalle(int idVehiculo) => _api.detalle(idVehiculo);

  Future<List<Mantenimiento>> mantenimientos(int idVehiculo) => _api.mantenimientos(idVehiculo);

  Future<Mantenimiento> crearMantenimiento(
    int idVehiculo, {
    required String titulo,
    String? descripcion,
    required DateTime fechaRealizado,
    int? kilometraje,
    double? costo,
    XFile? archivo,
  }) => _api.crearMantenimiento(
    idVehiculo,
    titulo: titulo,
    descripcion: descripcion,
    fechaRealizado: fechaRealizado,
    kilometraje: kilometraje,
    costo: costo,
    archivo: archivo,
  );
}
