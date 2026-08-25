import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/creador_providers.dart';
import '../../domain/creador_models.dart';
import '../widgets/creador_tab_list.dart';
import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../../../core/widgets/selector_sheet.dart';

/// Alta rápida de ubicación: Zona, Nombre, Código, Tipo y si tiene ubicación
/// padre. El `nivel` (`RACK`/`POSICION`) no lo pide el spec — se infiere:
/// con padre es `POSICION` (el padre tiene que ser un `RACK`, regla del
/// backend en `ubicacion_ubicacion.py::_validate_parent_relation`), sin
/// padre es `RACK` (el típico "mueble" que después contiene posiciones).
class UbicacionesTab extends ConsumerWidget {
  const UbicacionesTab({
    super.key,
    required this.puedeCrear,
    required this.puedeEditar,
  });

  final bool puedeCrear;
  final bool puedeEditar;

  Future<void> _abrirForm(
    BuildContext context,
    WidgetRef ref,
    int idAlmacen, {
    UbicacionCreador? ubicacion,
  }) async {
    final nombreCtrl = TextEditingController(text: ubicacion?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: ubicacion?.codigo ?? '');
    var tipo = ubicacion?.tipoUbicacion ?? 'ALMACENAJE';
    ZonaCreador? zona = ubicacion == null
        ? null
        : ZonaCreador(
            idZona: ubicacion.idZona,
            idAlmacen: idAlmacen,
            nombre: ubicacion.zonaNombre ?? 'Zona ${ubicacion.idZona}',
            tipo: 'GENERAL',
            activo: true,
            rowVersion: 1,
          );
    var tienePadre = ubicacion?.idUbicacionPadre != null;
    UbicacionCreador? padre;
    if (ubicacion?.idUbicacionPadre != null) {
      padre = UbicacionCreador(
        idUbicacion: ubicacion!.idUbicacionPadre!,
        idZona: ubicacion.idZona,
        nombre:
            ubicacion.ubicacionPadreNombre ??
            'Ubicación ${ubicacion.idUbicacionPadre}',
        codigo: '',
        tipoUbicacion: 'ALMACENAJE',
        nivel: 'RACK',
        activo: true,
        rowVersion: 1,
      );
    }

    final api = ref.read(creadorApiProvider);

    final ok = await showFormSheet(
      context,
      titulo: ubicacion == null ? 'Nueva ubicación' : 'Editar ubicación',
      camposBuilder: (context, setStateSheet) => [
        PickerField(
          label: 'Zona *',
          value: zona?.nombre,
          onTap: () async {
            final elegida = await showSelectorSheet<ZonaCreador>(
              context,
              titulo: 'Elegir zona',
              cargar: (q) => api.zonasListar(idAlmacen: idAlmacen, q: q),
              etiqueta: (z) => z.nombre,
              subtitulo: (z) => z.tipo,
              seleccionado: zona,
              esIgual: (z) => zona != null && z.idZona == zona!.idZona,
            );
            if (elegida != null) {
              setStateSheet(() {
                zona = elegida;
                // Cambiar de zona invalida cualquier padre elegido antes.
                padre = null;
                tienePadre = false;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: nombreCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: codigoCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Código *'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: tipo,
          decoration: const InputDecoration(labelText: 'Tipo *'),
          items: tiposUbicacion
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setStateSheet(() => tipo = v ?? tipo),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Tiene ubicación padre',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Ej: una posición dentro de un rack',
            style: TextStyle(fontSize: 12),
          ),
          value: tienePadre,
          onChanged: zona == null
              ? null
              : (v) => setStateSheet(() {
                  tienePadre = v;
                  if (!v) padre = null;
                }),
        ),
        if (tienePadre)
          PickerField(
            label: 'Ubicación padre (rack) *',
            value: padre?.nombre,
            enabled: zona != null,
            onTap: zona == null
                ? () {}
                : () async {
                    final elegida = await showSelectorSheet<UbicacionCreador>(
                      context,
                      titulo: 'Elegir ubicación padre',
                      cargar: (q) => api.ubicacionesListar(
                        idZona: zona!.idZona,
                        nivel: 'RACK',
                        q: q,
                      ),
                      etiqueta: (u) => u.nombre,
                      subtitulo: (u) => u.codigo,
                      seleccionado: padre,
                      esIgual: (u) =>
                          padre != null && u.idUbicacion == padre!.idUbicacion,
                    );
                    if (elegida != null) setStateSheet(() => padre = elegida);
                  },
          ),
      ],
      onGuardar: () async {
        final nombre = nombreCtrl.text.trim();
        final codigo = codigoCtrl.text.trim();
        if (zona == null) throw Exception('La zona es obligatoria');
        if (nombre.isEmpty) throw Exception('El nombre es obligatorio');
        if (codigo.isEmpty) throw Exception('El código es obligatorio');
        if (tienePadre && padre == null)
          throw Exception('Elegí la ubicación padre');

        final nivel = tienePadre ? 'POSICION' : 'RACK';
        if (ubicacion == null) {
          await api.ubicacionCrear(
            idZona: zona!.idZona,
            nombre: nombre,
            codigo: codigo,
            tipoUbicacion: tipo,
            nivel: nivel,
            idUbicacionPadre: tienePadre ? padre!.idUbicacion : null,
          );
        } else {
          await api.ubicacionEditar(
            idUbicacion: ubicacion.idUbicacion,
            expectedVersion: ubicacion.rowVersion,
            idZona: zona!.idZona,
            nombre: nombre,
            codigo: codigo,
            tipoUbicacion: tipo,
            nivel: nivel,
            idUbicacionPadre: tienePadre ? padre!.idUbicacion : null,
          );
        }
      },
    );
    if (ok == true) ref.invalidate(creadorUbicacionesListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idAlmacen = ref.watch(creadorAlmacenActualProvider);
    if (idAlmacen == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Tu usuario no tiene un almacén base asignado — pedile a un admin que te asigne uno.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    final async = ref.watch(creadorUbicacionesListProvider);
    return CreadorTabList<UbicacionCreador>(
      value: async,
      hintBuscar: 'Buscar ubicación...',
      onBuscar: (q) =>
          ref.read(creadorUbicacionesQueryProvider.notifier).state = q,
      onRefresh: () => ref.invalidate(creadorUbicacionesListProvider),
      onAgregar: puedeCrear ? () => _abrirForm(context, ref, idAlmacen) : null,
      textoVacio: 'Sin ubicaciones todavía',
      itemBuilder: (context, u) => CreadorTile(
        titulo: u.nombre,
        subtitulo: '${u.zonaNombre ?? ''} · ${u.codigo} · ${u.nivel}'.trim(),
        activo: u.activo,
        onTap: puedeEditar
            ? () => _abrirForm(context, ref, idAlmacen, ubicacion: u)
            : () {},
      ),
    );
  }
}
