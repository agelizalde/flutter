import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/creador_providers.dart';
import '../../domain/creador_models.dart';
import '../widgets/creador_tab_list.dart';
import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../../../core/widgets/selector_sheet.dart';

/// Flujo de 2 pasos, a diferencia del resto de las pestañas del Creador:
/// primero se elige el producto (mismo picker que usa `ProductosTab` para
/// marca/proveedor/etc.) y recién entonces se ve/agrega su lista de
/// códigos de barra. Un producto puede tener varios; `principal` marca cuál
/// usar por defecto (ej. al escanear), el backend deja uno solo marcado por
/// producto (ver `producto_codigo_barra_service.py::_set_principal_exclusivo`).
class CodigosBarraTab extends ConsumerWidget {
  const CodigosBarraTab({
    super.key,
    required this.puedeCrear,
    required this.puedeEditar,
  });

  final bool puedeCrear;
  final bool puedeEditar;

  Future<void> _elegirProducto(BuildContext context, WidgetRef ref) async {
    final api = ref.read(creadorApiProvider);
    final actual = ref.read(creadorCodigosBarraProductoProvider);
    final elegido = await showSelectorSheet<ProductoCreador>(
      context,
      titulo: 'Elegir producto',
      cargar: (q) => api.productosListar(q: q),
      etiqueta: (p) => p.nombre,
      subtitulo: (p) => p.codigoInterno,
      seleccionado: actual,
      esIgual: (p) => p.idProducto == actual?.idProducto,
    );
    if (elegido != null) {
      ref.read(creadorCodigosBarraProductoProvider.notifier).state = elegido;
    }
  }

  Future<void> _abrirForm(
    BuildContext context,
    WidgetRef ref,
    ProductoCreador producto, {
    CodigoBarraCreador? codigo,
  }) async {
    final codigoCtrl = TextEditingController(text: codigo?.codigoBarra ?? '');
    final observacionesCtrl = TextEditingController(
      text: codigo?.observaciones ?? '',
    );
    var tipo = codigo?.tipoCodigo ?? 'EAN13';
    var principal = codigo?.principal ?? false;
    var activo = codigo?.activo ?? true;

    final ok = await showFormSheet(
      context,
      titulo: codigo == null ? 'Nuevo código de barras' : 'Editar código de barras',
      textoGuardar: codigo == null ? 'Agregar código' : 'Guardar cambios',
      camposBuilder: (context, setStateSheet) => [
        Text(
          producto.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: codigoCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Código de barras *'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: tipo,
          decoration: const InputDecoration(labelText: 'Tipo *'),
          items: tiposCodigoBarra
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setStateSheet(() => tipo = v ?? tipo),
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Código principal',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Se usa por defecto para este producto (ej. al escanear)',
            style: TextStyle(fontSize: 12),
          ),
          value: principal,
          onChanged: (v) => setStateSheet(() => principal = v),
        ),
        if (codigo != null)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Activo',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            value: activo,
            onChanged: (v) => setStateSheet(() => activo = v),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: observacionesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Observaciones'),
        ),
      ],
      onGuardar: () async {
        final valor = codigoCtrl.text.trim();
        if (valor.isEmpty) throw Exception('El código de barras es obligatorio');
        final api = ref.read(creadorApiProvider);
        final observaciones = observacionesCtrl.text.trim();

        if (codigo == null) {
          await api.codigoBarraCrear(
            idProducto: producto.idProducto,
            codigoBarra: valor,
            tipoCodigo: tipo,
            principal: principal,
            observaciones: observaciones.isEmpty ? null : observaciones,
          );
        } else {
          final actualizado = await api.codigoBarraEditar(
            idCodigoBarra: codigo.idCodigoBarra,
            expectedVersion: codigo.rowVersion,
            codigoBarra: valor,
            tipoCodigo: tipo,
            principal: principal,
            observaciones: observaciones.isEmpty ? null : observaciones,
          );
          if (activo != codigo.activo) {
            if (activo) {
              await api.codigoBarraReactivar(
                idCodigoBarra: actualizado.idCodigoBarra,
                expectedVersion: actualizado.rowVersion,
              );
            } else {
              await api.codigoBarraDesactivar(
                idCodigoBarra: actualizado.idCodigoBarra,
                expectedVersion: actualizado.rowVersion,
              );
            }
          }
        }
      },
    );
    if (ok == true) ref.invalidate(creadorCodigosBarraListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final producto = ref.watch(creadorCodigosBarraProductoProvider);
    final async = ref.watch(creadorCodigosBarraListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: PickerField(
            label: 'Producto',
            value: producto == null
                ? null
                : '${producto.nombre} (${producto.codigoInterno})',
            placeholder: 'Elegí un producto...',
            onTap: () => _elegirProducto(context, ref),
          ),
        ),
        Expanded(
          child: producto == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Elegí un producto para ver y agregar sus códigos de barra.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              : CreadorTabList<CodigoBarraCreador>(
                  value: async,
                  hintBuscar: 'Buscar código de barras...',
                  onBuscar: (q) => ref
                      .read(creadorCodigosBarraQueryProvider.notifier)
                      .state = q,
                  onRefresh: () =>
                      ref.invalidate(creadorCodigosBarraListProvider),
                  onAgregar:
                      puedeCrear ? () => _abrirForm(context, ref, producto) : null,
                  textoVacio: 'Este producto todavía no tiene códigos de barra',
                  itemBuilder: (context, c) => CreadorTile(
                    titulo: c.codigoBarra,
                    subtitulo:
                        '${c.tipoCodigo}${c.principal ? ' · Principal' : ''}',
                    activo: c.activo,
                    onTap: puedeEditar
                        ? () => _abrirForm(context, ref, producto, codigo: c)
                        : () {},
                  ),
                ),
        ),
      ],
    );
  }
}
