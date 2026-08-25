import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/creador_providers.dart';
import '../../domain/creador_models.dart';
import '../widgets/creador_tab_list.dart';
import '../../../../core/widgets/form_sheet.dart';

/// Pestaña más simple del Creador (un solo campo) — sirve de plantilla para
/// el resto: buscador+lista con [CreadorTabList] y alta/edición con
/// [showFormSheet].
class MarcasTab extends ConsumerWidget {
  const MarcasTab({
    super.key,
    required this.puedeCrear,
    required this.puedeEditar,
  });

  final bool puedeCrear;
  final bool puedeEditar;

  Future<void> _abrirForm(
    BuildContext context,
    WidgetRef ref, {
    MarcaCreador? marca,
  }) async {
    final controller = TextEditingController(text: marca?.nombre ?? '');
    final ok = await showFormSheet(
      context,
      titulo: marca == null ? 'Nueva marca' : 'Editar marca',
      camposBuilder: (context, setStateSheet) => [
        TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre *'),
        ),
      ],
      onGuardar: () async {
        final nombre = controller.text.trim();
        if (nombre.isEmpty) throw Exception('El nombre es obligatorio');
        final api = ref.read(creadorApiProvider);
        if (marca == null) {
          await api.marcaCrear(nombre: nombre);
        } else {
          await api.marcaEditar(
            idMarca: marca.idMarca,
            nombre: nombre,
            expectedVersion: marca.rowVersion,
          );
        }
      },
    );
    if (ok == true) ref.invalidate(creadorMarcasListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(creadorMarcasListProvider);
    return CreadorTabList<MarcaCreador>(
      value: async,
      hintBuscar: 'Buscar marca...',
      onBuscar: (q) => ref.read(creadorMarcasQueryProvider.notifier).state = q,
      onRefresh: () => ref.invalidate(creadorMarcasListProvider),
      onAgregar: puedeCrear ? () => _abrirForm(context, ref) : null,
      textoVacio: 'Sin marcas todavía',
      itemBuilder: (context, m) => CreadorTile(
        titulo: m.nombre,
        activo: m.activo,
        onTap: puedeEditar ? () => _abrirForm(context, ref, marca: m) : () {},
      ),
    );
  }
}
