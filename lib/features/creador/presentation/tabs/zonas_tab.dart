import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/creador_providers.dart';
import '../../domain/creador_models.dart';
import '../widgets/creador_tab_list.dart';
import '../../../../core/widgets/form_sheet.dart';

/// Alta rápida de zona: Nombre, código y tipo. La zona se crea siempre en
/// el almacén base del usuario (`id_almacen_seleccionado`, ver
/// `creadorAlmacenActualProvider`) — el spec no la pide como campo porque
/// en este módulo un operario de depósito solo gestiona su propio almacén.
class ZonasTab extends ConsumerWidget {
  const ZonasTab({
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
    ZonaCreador? zona,
  }) async {
    final nombreCtrl = TextEditingController(text: zona?.nombre ?? '');
    final codigoCtrl = TextEditingController(text: zona?.codigo ?? '');
    var tipo = zona?.tipo ?? 'GENERAL';

    final ok = await showFormSheet(
      context,
      titulo: zona == null ? 'Nueva zona' : 'Editar zona',
      camposBuilder: (context, setStateSheet) => [
        TextField(
          controller: nombreCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre *'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: codigoCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Código'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: tipo,
          decoration: const InputDecoration(labelText: 'Tipo *'),
          items: tiposZona
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setStateSheet(() => tipo = v ?? tipo),
        ),
      ],
      onGuardar: () async {
        final nombre = nombreCtrl.text.trim();
        if (nombre.isEmpty) throw Exception('El nombre es obligatorio');
        final api = ref.read(creadorApiProvider);
        final codigo = codigoCtrl.text.trim();
        if (zona == null) {
          await api.zonaCrear(
            idAlmacen: idAlmacen,
            nombre: nombre,
            codigo: codigo.isEmpty ? null : codigo,
            tipo: tipo,
          );
        } else {
          await api.zonaEditar(
            idZona: zona.idZona,
            expectedVersion: zona.rowVersion,
            nombre: nombre,
            codigo: codigo.isEmpty ? null : codigo,
            tipo: tipo,
          );
        }
      },
    );
    if (ok == true) {
      ref.invalidate(creadorZonasListProvider);
      ref.invalidate(creadorZonasDelAlmacenProvider);
    }
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

    final async = ref.watch(creadorZonasListProvider);
    return CreadorTabList<ZonaCreador>(
      value: async,
      hintBuscar: 'Buscar zona...',
      onBuscar: (q) => ref.read(creadorZonasQueryProvider.notifier).state = q,
      onRefresh: () => ref.invalidate(creadorZonasListProvider),
      onAgregar: puedeCrear ? () => _abrirForm(context, ref, idAlmacen) : null,
      textoVacio: 'Sin zonas todavía',
      itemBuilder: (context, z) => CreadorTile(
        titulo: z.nombre,
        subtitulo:
            '${z.tipo}${z.codigo != null && z.codigo!.isNotEmpty ? ' · ${z.codigo}' : ''}',
        activo: z.activo,
        onTap: puedeEditar
            ? () => _abrirForm(context, ref, idAlmacen, zona: z)
            : () {},
      ),
    );
  }
}
