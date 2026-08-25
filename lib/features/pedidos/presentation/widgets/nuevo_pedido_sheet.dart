import 'package:flutter/material.dart';

import '../../../../core/utils/parsing.dart';
import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../../../core/widgets/selector_sheet.dart';
import '../../data/pedidos_repository.dart';
import '../../domain/pedido_models.dart';

/// Autogenera un código de pedido igual al de la web (`generarCodigoPedido`
/// en `pedidosApi.js`) — "PED-YYYYMMDD-NNNN" con 4 dígitos al azar. El
/// usuario no lo ve ni lo edita, es un dato técnico que el sistema resuelve
/// solo (a diferencia de la web, donde el campo queda visible por si se
/// necesita un código propio).
String _generarCodigoPedido() {
  final ahora = DateTime.now();
  final fecha =
      '${ahora.year.toString().padLeft(4, '0')}'
      '${ahora.month.toString().padLeft(2, '0')}'
      '${ahora.day.toString().padLeft(2, '0')}';
  final azar = 1000 + (ahora.microsecondsSinceEpoch % 9000);
  return 'PED-$fecha-$azar';
}

/// "00:00", "00:30", ..., "23:30" — mismo paso de 30 min que `HORA_OPTIONS`
/// en `NuevoPedidoModal.jsx` (web), para no dejar cargar una ETA con
/// minutos sueltos que después no se puede replicar en un horario real de
/// entrega.
final List<String> _horaOptions = List.generate(48, (i) {
  final h = (i ~/ 2).toString().padLeft(2, '0');
  final m = i.isEven ? '00' : '30';
  return '$h:$m';
});

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

/// Alta de la cabecera de un pedido nuevo — mismos campos que
/// `NuevoPedidoModal.jsx` (web) cuando se crea "vacío": cliente, sucursal,
/// lugar de entrega, ETA, vehículo y observaciones (el código de pedido se
/// genera solo, ver `_generarCodigoPedido`). Los subpedidos e ítems se
/// agregan después desde la web, como ya documenta `PedidosHomeScreen`.
/// Devuelve el pedido creado, o `null` si se canceló.
Future<PedidoDetalle?> abrirNuevoPedidoSheet(
  BuildContext context,
  PedidosRepository repositorio,
) async {
  final observacionesCtrl = TextEditingController();

  ClienteSimple? cliente;
  SucursalSimple? sucursal;
  LugarEntregaSimple? lugarEntrega;
  VehiculoEntregaSimple? vehiculo;
  DateTime? etaFecha;
  String? etaHora;

  PedidoDetalle? creado;

  // Sheet más alto que el default de `showFormSheet` (pensado para los
  // formularios de Creador, con menos campos) — junto con el layout en
  // filas de a 2 de acá abajo, entra completo sin que haga falta arrastrar
  // ni scrollear en un teléfono chico.
  final ok = await showFormSheet(
    context,
    titulo: 'Nuevo pedido',
    textoGuardar: 'Crear pedido',
    initialChildSize: 0.92,
    minChildSize: 0.6,
    camposBuilder: (context, setStateSheet) => [
      PickerField(
        label: 'Cliente *',
        value: cliente?.etiqueta,
        onTap: () async {
          final elegido = await showSelectorSheet<ClienteSimple>(
            context,
            titulo: 'Elegir cliente',
            cargar: (q) => repositorio.clientesListar(q: q),
            etiqueta: (c) => c.etiqueta,
            seleccionado: cliente,
            esIgual: (c) => c.idCliente == cliente?.idCliente,
          );
          if (elegido != null) {
            setStateSheet(() {
              cliente = elegido;
              // La sucursal es de un cliente puntual: si se cambia el
              // cliente, la que estaba elegida deja de tener sentido.
              sucursal = null;
            });
          }
        },
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PickerField(
              label: 'Sucursal',
              value: sucursal?.nombre,
              placeholder: cliente == null ? 'Elegí cliente' : 'Sin asignar',
              enabled: cliente != null,
              onTap: () async {
                final idCliente = cliente!.idCliente;
                final elegida = await showSelectorSheet<SucursalSimple>(
                  context,
                  titulo: 'Elegir sucursal',
                  cargar: (q) async {
                    final todas = await repositorio.sucursalesDeCliente(
                      idCliente,
                    );
                    if (q.isEmpty) return todas;
                    final ql = q.toLowerCase();
                    return todas
                        .where((s) => s.nombre.toLowerCase().contains(ql))
                        .toList();
                  },
                  etiqueta: (s) => s.nombre,
                  seleccionado: sucursal,
                  esIgual: (s) => s.idSucursal == sucursal?.idSucursal,
                );
                if (elegida != null) setStateSheet(() => sucursal = elegida);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PickerField(
              label: 'Lugar de entrega',
              value: lugarEntrega?.nombre,
              placeholder: 'Sin asignar',
              onTap: () async {
                final elegido = await showSelectorSheet<LugarEntregaSimple>(
                  context,
                  titulo: 'Elegir lugar de entrega',
                  cargar: (q) => repositorio.lugaresEntregaListar(q: q),
                  etiqueta: (l) => l.nombre,
                  seleccionado: lugarEntrega,
                  esIgual: (l) => l.idLugar == lugarEntrega?.idLugar,
                );
                if (elegido != null)
                  setStateSheet(() => lugarEntrega = elegido);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      PickerField(
        label: 'Vehículo',
        value: vehiculo != null
            ? (vehiculo!.patente != null
                  ? '${vehiculo!.nombre} (${vehiculo!.patente})'
                  : vehiculo!.nombre)
            : null,
        placeholder: 'Sin asignar',
        onTap: () async {
          final elegido = await showSelectorSheet<VehiculoEntregaSimple>(
            context,
            titulo: 'Elegir vehículo',
            cargar: (q) => repositorio.vehiculosListar(q: q),
            etiqueta: (v) => v.nombre,
            subtitulo: (v) => v.patente,
            seleccionado: vehiculo,
            esIgual: (v) => v.idVehiculo == vehiculo?.idVehiculo,
          );
          if (elegido != null) setStateSheet(() => vehiculo = elegido);
        },
      ),
      const SizedBox(height: 10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PickerField(
              label: 'ETA - fecha',
              value: etaFecha != null ? formatFecha(etaFecha!) : null,
              placeholder: 'Sin definir',
              onClear: () => setStateSheet(() => etaFecha = null),
              onTap: () => _elegirFecha(
                context,
                etaFecha,
                (v) => setStateSheet(() => etaFecha = v),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PickerField(
              label: 'ETA - hora',
              value: etaHora,
              placeholder: 'Sin definir',
              onClear: () => setStateSheet(() => etaHora = null),
              onTap: () async {
                final elegida = await showSelectorSheet<String>(
                  context,
                  titulo: 'Elegir hora (cada 30 min)',
                  cargar: (q) async => q.isEmpty
                      ? _horaOptions
                      : _horaOptions.where((h) => h.contains(q)).toList(),
                  etiqueta: (h) => h,
                  seleccionado: etaHora,
                  esIgual: (h) => h == etaHora,
                );
                if (elegida != null) setStateSheet(() => etaHora = elegida);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      TextField(
        controller: observacionesCtrl,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Observaciones'),
      ),
    ],
    onGuardar: () async {
      if (cliente == null) throw Exception('Elegí un cliente');
      if ((etaFecha == null) != (etaHora == null)) {
        throw Exception(
          'Completá la fecha y la hora de la ETA, o dejá las dos vacías',
        );
      }

      DateTime? eta;
      if (etaFecha != null && etaHora != null) {
        final partes = etaHora!.split(':');
        eta = DateTime(
          etaFecha!.year,
          etaFecha!.month,
          etaFecha!.day,
          int.parse(partes[0]),
          int.parse(partes[1]),
        );
      }

      creado = await repositorio.crear(
        codigoPedido: _generarCodigoPedido(),
        idCliente: cliente!.idCliente,
        idClienteSucursal: sucursal?.idSucursal,
        observaciones: observacionesCtrl.text.trim().isEmpty
            ? null
            : observacionesCtrl.text.trim(),
        idLugarEntrega: lugarEntrega?.idLugar,
        eta: eta,
        idVehiculoEntrega: vehiculo?.idVehiculo,
      );
    },
  );

  return ok == true ? creado : null;
}
