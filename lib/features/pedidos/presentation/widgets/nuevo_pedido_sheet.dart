import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/parsing.dart';
import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/hora_wheel_picker.dart';
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

/// Origen de los productos del pedido nuevo — mismo concepto que `ORIGENES`
/// en `NuevoPedidoModal.jsx`, pero sin "excel" (ver `PedidosConfigCreacion`).
enum _Origen { vacio, estandar }

/// Orígenes elegibles según la Configuración de creación del almacén y,
/// para "estándar", que el cliente tenga alguno guardado — mismo criterio
/// que `origenesVisibles` en la web.
List<_Origen> _origenesVisibles(
  PedidosConfigCreacion config,
  List<PedidoEstandarResumen> estandares,
) {
  return [
    if (config.origenVacioHabilitado) _Origen.vacio,
    if (config.origenEstandarHabilitado && estandares.isNotEmpty)
      _Origen.estandar,
  ];
}

/// Alta de la cabecera de un pedido nuevo — mismos campos que
/// `NuevoPedidoModal.jsx` (web) cuando se crea "vacío" o "desde estándar" (el
/// origen "excel" no está disponible en esta app, ver `PedidosConfigCreacion`)
/// respetando la Configuración de creación de pedidos del almacén (Ajustes ->
/// Ventas -> Pedidos -> Creación): qué campos se muestran y cuáles son
/// obligatorios, más los checkboxes de Documentación (PGN/Aduana). El código
/// de pedido se genera solo (ver `_generarCodigoPedido`), a diferencia de la
/// web donde el campo queda visible. Los subpedidos "vacíos" se agregan
/// después desde la web, como ya documenta `PedidosHomeScreen`.
/// Devuelve el pedido creado, o `null` si se canceló.
Future<PedidoDetalle?> abrirNuevoPedidoSheet(
  BuildContext context,
  PedidosRepository repositorio,
) async {
  // Config de creación del almacén base del usuario — si falla (sin permiso
  // `pedidos_config.ver`, migración sin correr, etc.) se sigue con el
  // default de siempre en vez de bloquear la creación de pedidos.
  PedidosConfigCreacion config;
  try {
    config = await repositorio.configCreacion();
  } catch (_) {
    config = const PedidosConfigCreacion();
  }
  if (!context.mounted) return null;

  final observacionesCtrl = TextEditingController();

  ClienteSimple? cliente;
  SucursalSimple? sucursal;
  LugarEntregaSimple? lugarEntrega;
  VehiculoEntregaSimple? vehiculo;
  DateTime? etaFecha;
  String? etaHora;
  bool requierePgn = false;
  bool requiereAduana = false;

  List<SucursalSimple> sucursales = [];
  List<PedidoEstandarResumen> estandares = [];
  PedidoEstandarResumen? estandarSel;
  _Origen origen = config.origenVacioHabilitado ? _Origen.vacio : _Origen.estandar;

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
    camposBuilder: (context, setStateSheet) {
      final sucursalVisible =
          config.sucursalHabilitada && (cliente == null || sucursales.isNotEmpty);
      final origenesElegibles = _origenesVisibles(config, estandares);

      return [
        PickerField(
          label: 'Cliente *',
          value: cliente?.etiqueta,
          onTap: () async {
            final elegido = await showSelectorSheet<ClienteSimple>(
              context,
              titulo: 'Elegir cliente',
              cargar: (q) =>
                  repositorio.clientesListar(q: q, excluirOcasionales: true),
              etiqueta: (c) => c.etiqueta,
              seleccionado: cliente,
              esIgual: (c) => c.idCliente == cliente?.idCliente,
            );
            if (elegido == null) return;
            setStateSheet(() {
              cliente = elegido;
              // La sucursal y los estándares son de un cliente puntual: si
              // se cambia el cliente, lo elegido deja de tener sentido.
              sucursal = null;
              sucursales = [];
              estandares = [];
              estandarSel = null;
            });
            final resultados = await Future.wait([
              repositorio.sucursalesDeCliente(elegido.idCliente),
              repositorio
                  .estandaresDeCliente(elegido.idCliente)
                  .catchError((_) => <PedidoEstandarResumen>[]),
            ]);
            setStateSheet(() {
              sucursales = resultados[0] as List<SucursalSimple>;
              estandares = resultados[1] as List<PedidoEstandarResumen>;
              final visibles = _origenesVisibles(config, estandares);
              if (visibles.isNotEmpty && !visibles.contains(origen)) {
                origen = visibles.first;
              }
            });
          },
        ),
        if (sucursalVisible) ...[
          const SizedBox(height: 10),
          PickerField(
            label:
                'Sucursal${config.sucursalObligatoria ? ' *' : ''}',
            value: sucursal?.nombre,
            placeholder: cliente == null ? 'Elegí cliente' : 'Sin asignar',
            enabled: cliente != null,
            onTap: () async {
              final elegida = await showSelectorSheet<SucursalSimple>(
                context,
                titulo: 'Elegir sucursal',
                cargar: (q) async {
                  if (q.isEmpty) return sucursales;
                  final ql = q.toLowerCase();
                  return sucursales
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
        ],

        // ORIGEN DE LOS PRODUCTOS — visible solo con cliente elegido y más
        // de una opción elegible (si Configuración de creación dejó una
        // sola, se usa directo sin mostrar nada para elegir).
        if (cliente != null && origenesElegibles.length > 1) ...[
          const SizedBox(height: 14),
          const _SectionLabel('Origen del pedido'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final o in origenesElegibles)
                ChoiceChip(
                  label: Text(o == _Origen.vacio ? 'Vacío' : 'Desde estándar'),
                  avatar: Icon(
                    o == _Origen.vacio ? Icons.edit_outlined : Icons.star_outline,
                    size: 16,
                  ),
                  selected: origen == o,
                  onSelected: (_) => setStateSheet(() {
                    origen = o;
                    if (o != _Origen.estandar) estandarSel = null;
                  }),
                  selectedColor: AppColors.accentSoft,
                  labelStyle: TextStyle(
                    color: origen == o ? AppColors.accentDark : AppColors.sub,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: origen == o ? AppColors.accent : AppColors.border,
                  ),
                ),
            ],
          ),
        ],
        if (cliente != null && origen == _Origen.estandar) ...[
          const SizedBox(height: 10),
          PickerField(
            label: 'Cargar desde estándar',
            value: estandarSel?.nombre,
            placeholder: 'Seleccioná un estándar…',
            onTap: () async {
              final elegido = await showSelectorSheet<PedidoEstandarResumen>(
                context,
                titulo: 'Elegir estándar',
                cargar: (q) async {
                  if (q.isEmpty) return estandares;
                  final ql = q.toLowerCase();
                  return estandares
                      .where((e) => e.nombre.toLowerCase().contains(ql))
                      .toList();
                },
                etiqueta: (e) => e.nombre,
                subtitulo: (e) =>
                    '${e.cantidadSubpedidos} subpedido${e.cantidadSubpedidos != 1 ? 's' : ''} · '
                    '${e.cantidadItems} ítem${e.cantidadItems != 1 ? 's' : ''}',
                seleccionado: estandarSel,
                esIgual: (e) => e.idPedidoEstandar == estandarSel?.idPedidoEstandar,
              );
              if (elegido != null) setStateSheet(() => estandarSel = elegido);
            },
          ),
          if (estandarSel != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Se van a crear ${estandarSel!.cantidadSubpedidos} subpedido${estandarSel!.cantidadSubpedidos != 1 ? 's' : ''} '
                'con ${estandarSel!.cantidadItems} ítem${estandarSel!.cantidadItems != 1 ? 's' : ''} en total.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
        ],

        // LOGÍSTICA — cada campo depende de Configuración de creación.
        if (config.etaHabilitada ||
            config.lugarEntregaHabilitado ||
            config.vehiculoEntregaHabilitado) ...[
          const SizedBox(height: 14),
          const _SectionLabel('Logística'),
          const SizedBox(height: 8),
        ],
        if (config.etaHabilitada)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PickerField(
                    label:
                        'ETA - fecha${config.etaObligatoria ? ' *' : ''}',
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
                      final elegida = await showHoraWheelPicker(
                        context,
                        horaInicial: etaHora,
                      );
                      if (elegida != null) setStateSheet(() => etaHora = elegida);
                    },
                  ),
                ),
              ],
            ),
          ),
        if (config.lugarEntregaHabilitado)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PickerField(
              label:
                  'Lugar de entrega${config.lugarEntregaObligatorio ? ' *' : ''}',
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
                if (elegido != null) setStateSheet(() => lugarEntrega = elegido);
              },
            ),
          ),
        if (config.vehiculoEntregaHabilitado)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PickerField(
              label:
                  'Vehículo${config.vehiculoEntregaObligatorio ? ' *' : ''}',
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
          ),

        // DOCUMENTACIÓN — si queda tildado, al crear el pedido el servidor
        // manda un mail de aviso a la dirección configurada en Ajustes ->
        // Ventas -> Pedidos -> Documentación. Cada checkbox depende de su
        // propio switch en Configuración de creación.
        if (config.permisoPgnHabilitado || config.permisoAduanaHabilitado) ...[
          const _SectionLabel('Documentación'),
          if (config.permisoPgnHabilitado)
            CheckboxListTile(
              value: requierePgn,
              onChanged: (v) => setStateSheet(() => requierePgn = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Requiere PGN',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ),
          if (config.permisoAduanaHabilitado)
            CheckboxListTile(
              value: requiereAduana,
              onChanged: (v) => setStateSheet(() => requiereAduana = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Requiere Aduana',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ),
          const SizedBox(height: 4),
        ],

        if (config.observacionHabilitada)
          TextField(
            controller: observacionesCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Observaciones'),
          ),
      ];
    },
    onGuardar: () async {
      if (cliente == null) throw Exception('Elegí un cliente');
      if ((etaFecha == null) != (etaHora == null)) {
        throw Exception(
          'Completá la fecha y la hora de la ETA, o dejá las dos vacías',
        );
      }

      // Obligatoriedad según Configuración de creación — el servidor la
      // vuelve a validar igual (pedidos_service.py::_validar_config_creacion_tx),
      // esto es solo para dar el error antes de pegarle a la red. La
      // sucursal solo se exige si el cliente tiene alguna para elegir
      // (mismo criterio que el backend).
      final faltantes = <String>[];
      if (config.sucursalObligatoria &&
          sucursales.isNotEmpty &&
          sucursal == null) {
        faltantes.add('la sucursal');
      }
      if (config.etaObligatoria && etaFecha == null) faltantes.add('la ETA');
      if (config.lugarEntregaObligatorio && lugarEntrega == null) {
        faltantes.add('el lugar de entrega');
      }
      if (config.vehiculoEntregaObligatorio && vehiculo == null) {
        faltantes.add('el vehículo de entrega');
      }
      if (faltantes.isNotEmpty) {
        throw Exception('Falta completar: ${faltantes.join(", ")}');
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

      final pedido = await repositorio.crear(
        codigoPedido: _generarCodigoPedido(),
        idCliente: cliente!.idCliente,
        idClienteSucursal: sucursal?.idSucursal,
        observaciones: observacionesCtrl.text.trim().isEmpty
            ? null
            : observacionesCtrl.text.trim(),
        idLugarEntrega: lugarEntrega?.idLugar,
        eta: eta,
        idVehiculoEntrega: vehiculo?.idVehiculo,
        requierePgn: requierePgn,
        requiereAduana: requiereAduana,
      );

      if (origen == _Origen.estandar && estandarSel != null) {
        await repositorio.aplicarEstandar(
          idPedidoEstandar: estandarSel!.idPedidoEstandar,
          idPedido: pedido.idPedido,
        );
      }

      creado = pedido;
    },
  );

  return ok == true ? creado : null;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          texto.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppColors.faint,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}
