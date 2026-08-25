import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../application/creador_providers.dart';
import '../../domain/creador_models.dart';
import '../widgets/creador_tab_list.dart';
import '../../../../core/widgets/form_sheet.dart';
import '../../../../core/widgets/picker_field.dart';
import '../../../../core/widgets/selector_sheet.dart';

const _diacriticos = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
  'ñ': 'n',
  'Á': 'A',
  'É': 'E',
  'Í': 'I',
  'Ó': 'O',
  'Ú': 'U',
  'Ü': 'U',
  'Ñ': 'N',
};

/// Mismo algoritmo que `ProductoNuevoModal.jsx` (web, `generarCodigoInterno`)
/// — el `codigo_interno` no lo pide el spec, se autogenera a partir del
/// nombre para no bloquear el alta rápida con un campo técnico.
String _generarCodigoInterno(String nombre) {
  final sinTildes = nombre.split('').map((c) => _diacriticos[c] ?? c).join();
  var base = sinTildes.trim().toUpperCase().replaceAll(
    RegExp(r'[^A-Z0-9]+'),
    '-',
  );
  base = base.replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.length > 28) base = base.substring(0, 28);
  final ahora = DateTime.now().millisecondsSinceEpoch;
  final sufijo = ahora.toString().substring(ahora.toString().length - 5);
  return 'PROD-${base.isEmpty ? ahora : base}-$sufijo';
}

/// Camino completo de una categoría (ej. "Almacén / Carnes / Vacuna"),
/// caminando hacia arriba por `idPadre` sobre la lista plana ya cargada —
/// igual criterio que la web (`ProductoNuevoModal.jsx::categoriaSeleccionadaLabel`).
String _categoriaPath(List<CategoriaCreador> todas, int idCategoriaTipo) {
  final porId = {for (final c in todas) c.idCategoriaTipo: c};
  final nombres = <String>[];
  CategoriaCreador? actual = porId[idCategoriaTipo];
  while (actual != null) {
    nombres.insert(0, actual.nombre);
    actual = actual.idPadre != null ? porId[actual.idPadre] : null;
  }
  return nombres.join(' / ');
}

/// Alta rápida de producto: Nombre, Marca, Tipo/categoría, Unidad de
/// medida, Proveedor de cabecera, IVA y "Requiere vencimiento / lote". El
/// resto queda con los defaults del spec (físico, vendible, comprable,
/// maneja stock, no ficticio) — se ajusta después desde el detalle
/// completo en el ERP web si hace falta.
class ProductosTab extends ConsumerWidget {
  const ProductosTab({
    super.key,
    required this.puedeCrear,
    required this.puedeEditar,
  });

  final bool puedeCrear;
  final bool puedeEditar;

  Future<void> _abrirForm(
    BuildContext context,
    WidgetRef ref, {
    ProductoCreador? producto,
  }) async {
    final api = ref.read(creadorApiProvider);

    // Precarga: categorías completas (para armar el "camino" del árbol) y,
    // si es edición, los flags de almacenaje (la lista de /productos no los
    // trae, ver `ProductoAlmacenajeSimple`). Se bloquea con un spinner corto
    // para que tocar "+"/una fila no se sienta como que no pasó nada.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    List<CategoriaCreador> categorias = const [];
    var requiereVencimientoLote = false;
    int? vidaUtilDias;
    try {
      categorias = await api.categoriasListar();
    } catch (_) {
      // Sin catálogo de categorías: el picker igual funciona vacío.
    }
    if (producto != null) {
      try {
        final almacenaje = await api.productoAlmacenaje(producto.idProducto);
        requiereVencimientoLote = almacenaje.requiereVencimientoLote;
        vidaUtilDias = almacenaje.vidaUtilDias;
      } catch (_) {
        // Si falla, se edita igual — el toggle arranca en false.
      }
    }

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) return;

    final nombreCtrl = TextEditingController(text: producto?.nombre ?? '');
    final vidaUtilCtrl = TextEditingController(
      text: vidaUtilDias?.toString() ?? '',
    );
    int? idMarca = producto?.idMarca;
    String? marcaNombre = producto?.marcaNombre;
    int? idCategoriaTipo = producto?.idCategoriaTipo;
    String? categoriaLabel = idCategoriaTipo != null
        ? _categoriaPath(categorias, idCategoriaTipo)
        : null;
    int? idUnidadBase = producto?.idUnidadBase;
    String? unidadLabel = producto?.unidadNombre;
    int? idProveedorCabecera = producto?.idProveedorCabecera;
    String? proveedorLabel = producto?.proveedorNombre;
    int? idImpuesto = producto?.idImpuesto;
    String? impuestoLabel = producto?.impuestoNombre;

    final ok = await showFormSheet(
      context,
      titulo: producto == null ? 'Nuevo producto' : 'Editar producto',
      textoGuardar: producto == null ? 'Crear producto' : 'Guardar cambios',
      camposBuilder: (context, setStateSheet) => [
        TextField(
          controller: nombreCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre del producto *'),
        ),
        const SizedBox(height: 12),
        PickerField(
          label: 'Marca *',
          value: marcaNombre,
          onTap: () async {
            final elegida = await showSelectorSheet<MarcaCreador>(
              context,
              titulo: 'Elegir marca',
              cargar: (q) => api.marcasListar(q: q),
              etiqueta: (m) => m.nombre,
              seleccionado: idMarca == null
                  ? null
                  : MarcaCreador(
                      idMarca: idMarca!,
                      nombre: marcaNombre ?? '',
                      activo: true,
                      rowVersion: 1,
                    ),
              esIgual: (m) => m.idMarca == idMarca,
            );
            if (elegida != null) {
              setStateSheet(() {
                idMarca = elegida.idMarca;
                marcaNombre = elegida.nombre;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        PickerField(
          label: 'Tipo / categoría *',
          value: categoriaLabel,
          onTap: () async {
            final elegida = await showSelectorSheet<CategoriaCreador>(
              context,
              titulo: 'Elegir categoría',
              cargar: (q) async {
                final lista = q.isEmpty
                    ? categorias
                    : await api.categoriasListar(q: q);
                return lista;
              },
              etiqueta: (c) => _categoriaPath(categorias, c.idCategoriaTipo),
              seleccionado: idCategoriaTipo == null
                  ? null
                  : CategoriaCreador(
                      idCategoriaTipo: idCategoriaTipo!,
                      nombre: '',
                    ),
              esIgual: (c) => c.idCategoriaTipo == idCategoriaTipo,
            );
            if (elegida != null) {
              setStateSheet(() {
                idCategoriaTipo = elegida.idCategoriaTipo;
                categoriaLabel = _categoriaPath(
                  categorias,
                  elegida.idCategoriaTipo,
                );
              });
            }
          },
        ),
        const SizedBox(height: 12),
        PickerField(
          label: 'Unidad de medida *',
          value: unidadLabel,
          onTap: () async {
            final elegida = await showSelectorSheet<UnidadCreador>(
              context,
              titulo: 'Elegir unidad',
              cargar: (_) => api.unidadesListar(),
              etiqueta: (u) => u.etiqueta,
              seleccionado: idUnidadBase == null
                  ? null
                  : UnidadCreador(
                      idUnidad: idUnidadBase!,
                      nombre: unidadLabel ?? '',
                    ),
              esIgual: (u) => u.idUnidad == idUnidadBase,
            );
            if (elegida != null) {
              setStateSheet(() {
                idUnidadBase = elegida.idUnidad;
                unidadLabel = elegida.etiqueta;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        PickerField(
          label: 'Proveedor de cabecera *',
          value: proveedorLabel,
          onTap: () async {
            final elegido = await showSelectorSheet<ProveedorCreador>(
              context,
              titulo: 'Elegir proveedor',
              cargar: (q) => api.proveedoresListar(q: q),
              etiqueta: (p) => p.etiqueta,
              subtitulo: (p) => p.ruc,
              seleccionado: idProveedorCabecera == null
                  ? null
                  : ProveedorCreador(
                      idProveedor: idProveedorCabecera!,
                      nombreComercial: proveedorLabel,
                      razonSocial: proveedorLabel ?? '',
                      ruc: null,
                      dv: null,
                      activo: true,
                      rowVersion: 1,
                    ),
              esIgual: (p) => p.idProveedor == idProveedorCabecera,
            );
            if (elegido != null) {
              setStateSheet(() {
                idProveedorCabecera = elegido.idProveedor;
                proveedorLabel = elegido.etiqueta;
              });
            }
          },
        ),
        const SizedBox(height: 12),
        PickerField(
          label: 'IVA',
          value: impuestoLabel,
          placeholder: 'Sin asignar',
          onTap: () async {
            final elegido = await showSelectorSheet<ImpuestoCreador>(
              context,
              titulo: 'Elegir IVA',
              cargar: (_) => api.impuestosListar(),
              etiqueta: (i) => i.nombre,
              seleccionado: idImpuesto == null
                  ? null
                  : ImpuestoCreador(
                      idImpuesto: idImpuesto!,
                      nombre: impuestoLabel ?? '',
                    ),
              esIgual: (i) => i.idImpuesto == idImpuesto,
            );
            setStateSheet(() {
              idImpuesto = elegido?.idImpuesto;
              impuestoLabel = elegido?.nombre;
            });
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Requiere vencimiento / lote',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Obliga a informar lote y fecha de vencimiento en depósito',
            style: TextStyle(fontSize: 12),
          ),
          value: requiereVencimientoLote,
          onChanged: (v) => setStateSheet(() => requiereVencimientoLote = v),
        ),
        if (requiereVencimientoLote) ...[
          const SizedBox(height: 4),
          TextField(
            controller: vidaUtilCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Vida útil (días) *',
              hintText: 'Ej: 365',
            ),
          ),
        ],
      ],
      onGuardar: () async {
        final nombre = nombreCtrl.text.trim();
        if (nombre.isEmpty) throw Exception('El nombre es obligatorio');
        if (idMarca == null) throw Exception('Elegí una marca');
        if (idCategoriaTipo == null)
          throw Exception('Elegí un tipo / categoría');
        if (idUnidadBase == null) throw Exception('Elegí una unidad de medida');
        if (idProveedorCabecera == null)
          throw Exception('Elegí un proveedor de cabecera');

        int? vidaUtil;
        if (requiereVencimientoLote) {
          vidaUtil = int.tryParse(vidaUtilCtrl.text.trim());
          if (vidaUtil == null || vidaUtil <= 0) {
            throw Exception('Indicá la vida útil en días');
          }
        }

        if (producto == null) {
          await api.productoCrear(
            codigoInterno: _generarCodigoInterno(nombre),
            nombre: nombre,
            idMarca: idMarca,
            idCategoriaTipo: idCategoriaTipo,
            idUnidadBase: idUnidadBase!,
            idProveedorCabecera: idProveedorCabecera,
            idImpuesto: idImpuesto,
            requiereVencimientoLote: requiereVencimientoLote,
            vidaUtilDias: vidaUtil,
          );
        } else {
          await api.productoEditar(
            idProducto: producto.idProducto,
            expectedVersion: producto.rowVersion,
            nombre: nombre,
            idMarca: idMarca,
            idCategoriaTipo: idCategoriaTipo,
            idUnidadBase: idUnidadBase!,
            idProveedorCabecera: idProveedorCabecera,
            idImpuesto: idImpuesto,
            requiereVencimientoLote: requiereVencimientoLote,
            vidaUtilDias: vidaUtil,
          );
        }
      },
    );
    if (ok == true) ref.invalidate(creadorProductosListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(creadorProductosListProvider);
    return CreadorTabList<ProductoCreador>(
      value: async,
      hintBuscar: 'Buscar producto por nombre o código...',
      onBuscar: (q) =>
          ref.read(creadorProductosQueryProvider.notifier).state = q,
      onRefresh: () => ref.invalidate(creadorProductosListProvider),
      onAgregar: puedeCrear ? () => _abrirForm(context, ref) : null,
      textoVacio: 'Sin productos todavía',
      itemBuilder: (context, p) => CreadorTile(
        titulo: p.nombre,
        subtitulo:
            '${p.codigoInterno}${p.marcaNombre != null ? ' · ${p.marcaNombre}' : ''}',
        activo: p.activo,
        onTap: puedeEditar
            ? () =>
                  _abrirForm(context, ref, producto: p).catchError((Object e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(describeError(e))));
                    }
                  })
            : () {},
      ),
    );
  }
}
