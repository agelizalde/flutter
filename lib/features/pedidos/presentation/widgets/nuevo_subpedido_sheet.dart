import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../../../core/widgets/selector_sheet.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido_models.dart';

/// Alta de un subpedido sobre un pedido ya creado, desde `PedidoInfoScreen`.
/// A diferencia de `ModalNuevoSubpedido.jsx` en la web (que además deja
/// crear un subpedido en blanco y cargar ítems a mano), acá solo se puede
/// elegir uno de los "Pedido Estándar" del cliente (ver
/// `pedidos_estandar_service.py`): la app de depósito no tiene pantalla para
/// armar ítems desde cero, así que restringe a plantillas ya cargadas desde
/// la web. Elegir una crea, en una sola transacción del backend, todos sus
/// subpedidos + ítems (`POST /pedidos/estandar/{id}/aplicar`).
/// Devuelve el resultado de aplicar la plantilla, o `null` si se canceló.
Future<EstandarAplicarResultado?> abrirNuevoSubpedidoSheet(
  BuildContext context,
  PedidosRepository repositorio, {
  required int idPedido,
  required int idCliente,
}) async {
  PedidoEstandarResumen? estandar;
  EstandarAplicarResultado? resultado;

  final ok = await showFormSheet(
    context,
    titulo: 'Nuevo subpedido',
    textoGuardar: 'Crear subpedido',
    camposBuilder: (context, setStateSheet) => [
      PickerField(
        label: 'Tipo de subpedido *',
        value: estandar?.nombre,
        placeholder: 'Elegí un estándar del cliente',
        onTap: () async {
          final elegido = await showSelectorSheet<PedidoEstandarResumen>(
            context,
            titulo: 'Elegir tipo de subpedido',
            cargar: (q) => repositorio.estandaresDeCliente(idCliente, q: q),
            etiqueta: (e) => e.nombre,
            subtitulo: (e) =>
                '${e.cantidadSubpedidos} subpedido${e.cantidadSubpedidos != 1 ? 's' : ''} · '
                '${e.cantidadItems} ítem${e.cantidadItems != 1 ? 's' : ''}',
            seleccionado: estandar,
            esIgual: (e) => e.idPedidoEstandar == estandar?.idPedidoEstandar,
          );
          if (elegido != null) setStateSheet(() => estandar = elegido);
        },
      ),
      if (estandar != null) ...[
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Se van a crear ${estandar!.cantidadSubpedidos} subpedido${estandar!.cantidadSubpedidos != 1 ? 's' : ''} '
            'con ${estandar!.cantidadItems} ítem${estandar!.cantidadItems != 1 ? 's' : ''} en total.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
      ],
    ],
    onGuardar: () async {
      if (estandar == null) throw Exception('Elegí un tipo de subpedido');
      resultado = await repositorio.aplicarEstandar(
        idPedidoEstandar: estandar!.idPedidoEstandar,
        idPedido: idPedido,
      );
    },
  );

  return ok == true ? resultado : null;
}
