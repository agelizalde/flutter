import 'package:flutter/material.dart';

import '../../../../core/utils/parsing.dart';
import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/hora_wheel_picker.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido_models.dart';

Future<void> _elegirFecha(
  BuildContext context,
  DateTime? actual,
  ValueChanged<DateTime> onElegida,
) async {
  final ahora = DateTime.now();
  final elegida = await showDatePicker(
    context: context,
    initialDate: actual ?? ahora,
    firstDate: DateTime(ahora.year - 1),
    lastDate: DateTime(ahora.year + 2),
  );
  if (elegida != null) onElegida(elegida);
}

/// Edita la ETA de un pedido ya creado — acción "Mod. ETA" del menú de
/// ajustes en `PedidoInfoScreen`. Usa `PATCH /pedidos/{id}` (campo `eta`,
/// editable en BORRADOR y ACTIVO, ver `pedidos_service.py`). Devuelve
/// `true` si guardó, `false`/`null` si se canceló.
Future<bool> abrirModificarEtaSheet(
  BuildContext context,
  PedidosRepository repositorio,
  PedidoDetalle detalle,
) async {
  DateTime? fecha = detalle.eta;
  String? hora = detalle.eta != null
      ? '${detalle.eta!.hour.toString().padLeft(2, '0')}:${detalle.eta!.minute.toString().padLeft(2, '0')}'
      : null;

  final ok = await showFormSheet(
    context,
    titulo: 'Modificar ETA',
    textoGuardar: 'Guardar',
    initialChildSize: 0.45,
    minChildSize: 0.3,
    camposBuilder: (context, setStateSheet) => [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PickerField(
              label: 'Fecha',
              value: fecha != null ? formatFecha(fecha!) : null,
              placeholder: 'Sin definir',
              onClear: () => setStateSheet(() => fecha = null),
              onTap: () =>
                  _elegirFecha(context, fecha, (v) => setStateSheet(() => fecha = v)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PickerField(
              label: 'Hora',
              value: hora,
              placeholder: 'Sin definir',
              onClear: () => setStateSheet(() => hora = null),
              onTap: () async {
                final elegida = await showHoraWheelPicker(
                  context,
                  horaInicial: hora,
                );
                if (elegida != null) setStateSheet(() => hora = elegida);
              },
            ),
          ),
        ],
      ),
    ],
    onGuardar: () async {
      if ((fecha == null) != (hora == null)) {
        throw Exception(
          'Completá la fecha y la hora, o dejá las dos vacías',
        );
      }

      DateTime? eta;
      if (fecha != null && hora != null) {
        final partes = hora!.split(':');
        eta = DateTime(
          fecha!.year,
          fecha!.month,
          fecha!.day,
          int.parse(partes[0]),
          int.parse(partes[1]),
        );
      }

      await repositorio.patch(
        idPedido: detalle.idPedido,
        expectedVersion: detalle.rowVersion,
        patch: {'eta': eta?.toIso8601String()},
      );
    },
  );

  return ok == true;
}
