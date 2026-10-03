import 'package:flutter/material.dart';

import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../../../core/widgets/selector_sheet.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido_models.dart';

/// Edita el lugar de entrega de un pedido ya creado — acción "Mod. Lugar"
/// del menú de ajustes en `PedidoInfoScreen`. Usa `PATCH /pedidos/{id}`
/// (campo `id_lugar_entrega`, editable en BORRADOR y ACTIVO, ver
/// `pedidos_service.py`). Devuelve `true` si guardó, `false`/`null` si se
/// canceló.
Future<bool> abrirModificarLugarSheet(
  BuildContext context,
  PedidosRepository repositorio,
  PedidoDetalle detalle,
) async {
  LugarEntregaSimple? lugar = detalle.idLugarEntrega != null
      ? LugarEntregaSimple(
          idLugar: detalle.idLugarEntrega!,
          nombre: detalle.lugarEntregaNombre ?? '',
        )
      : null;

  final ok = await showFormSheet(
    context,
    titulo: 'Modificar lugar de entrega',
    textoGuardar: 'Guardar',
    initialChildSize: 0.4,
    minChildSize: 0.28,
    camposBuilder: (context, setStateSheet) => [
      PickerField(
        label: 'Lugar de entrega',
        value: lugar?.nombre,
        placeholder: 'Sin asignar',
        onClear: () => setStateSheet(() => lugar = null),
        onTap: () async {
          final elegido = await showSelectorSheet<LugarEntregaSimple>(
            context,
            titulo: 'Elegir lugar de entrega',
            cargar: (q) => repositorio.lugaresEntregaListar(q: q),
            etiqueta: (l) => l.nombre,
            seleccionado: lugar,
            esIgual: (l) => l.idLugar == lugar?.idLugar,
          );
          if (elegido != null) setStateSheet(() => lugar = elegido);
        },
      ),
    ],
    onGuardar: () async {
      await repositorio.patch(
        idPedido: detalle.idPedido,
        expectedVersion: detalle.rowVersion,
        patch: {'id_lugar_entrega': lugar?.idLugar},
      );
    },
  );

  return ok == true;
}
