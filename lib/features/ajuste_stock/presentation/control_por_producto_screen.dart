import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../auth/application/auth_controller.dart';
import '../../stock/domain/stock_models.dart' show ProductoSimple;
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';
import 'agregar_ubicacion_producto_screen.dart';
import 'buscador_producto_ajuste.dart';

const _modoAjuste = 'POR_PRODUCTO';

String _formatCantidad(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
const _motivoCategoria = 'CONTEO_FISICO';

/// Ajuste creado para una ubicación — se muestra en el resumen final.
/// `aplicado` es false si quedó en BORRADOR (sin permisos o falló aplicar).
typedef _AjusteCreado = ({int idAjusteStock, String ubicacion, bool aplicado});

/// "Control por producto" (opción b de Nuevo ajuste): elegir producto → el
/// sistema lista cada ubicación del almacén donde está → el usuario cuenta
/// cuánto hay en cada una (a ciegas, campo vacío). Conteo físico.
///
/// El backend exige una sola ubicación por ajuste (`validar_consistencia`
/// en `AjusteStockCreateIn`), así que se crea un ajuste en BORRADOR por
/// ubicación; al final se listan para confirmar/aplicar desde el detalle.
///
/// "Agregar ubicación" suma ubicaciones donde el producto está pero el
/// sistema no lo tiene registrado: van como ítem de lote nuevo
/// (`es_lote_nuevo`), igual que "Agregar producto" del control por ubicación.
class ControlPorProductoScreen extends ConsumerStatefulWidget {
  const ControlPorProductoScreen({super.key});

  @override
  ConsumerState<ControlPorProductoScreen> createState() => _ControlPorProductoScreenState();
}

class _ControlPorProductoScreenState extends ConsumerState<ControlPorProductoScreen> {
  final _observacionController = TextEditingController();
  final Map<int, TextEditingController> _controladores = {};

  ProductoSimple? _producto;
  bool _cargando = false;
  List<StockEnUbicacion> _ubicaciones = const [];

  /// Ubicaciones agregadas a mano (lote nuevo), cada una con su cantidad
  /// editable en la lista.
  final List<UbicacionAgregada> _agregadas = [];
  final List<TextEditingController> _controladoresAgregadas = [];
  bool _guardando = false;
  List<_AjusteCreado>? _creados;

  @override
  void dispose() {
    _observacionController.dispose();
    _limpiarControladores();
    super.dispose();
  }

  void _limpiarControladores() {
    for (final c in _controladores.values) {
      c.dispose();
    }
    _controladores.clear();
    for (final c in _controladoresAgregadas) {
      c.dispose();
    }
    _controladoresAgregadas.clear();
    _agregadas.clear();
  }

  Future<void> _agregarUbicacion() async {
    final ya = {
      ..._ubicaciones.map((u) => u.idUbicacion),
      ..._agregadas.map((a) => a.ubicacion.idUbicacion),
    };
    final resultado = await Navigator.of(context).push<UbicacionAgregada>(
      MaterialPageRoute(
        builder: (_) => AgregarUbicacionProductoScreen(producto: _producto!, idsUbicacionYaListadas: ya),
      ),
    );
    if (resultado == null || !mounted) return;
    setState(() {
      _agregadas.add(resultado);
      _controladoresAgregadas.add(
        TextEditingController(text: _formatCantidad(resultado.item.cantidadInicial)),
      );
    });
  }

  void _quitarAgregada(int i) {
    setState(() {
      _agregadas.removeAt(i);
      _controladoresAgregadas.removeAt(i).dispose();
    });
  }

  Future<void> _seleccionarProducto(ProductoSimple p) async {
    final idAlmacen = ref.read(authControllerProvider).value?.idAlmacenSeleccionado;
    if (idAlmacen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay un almacén seleccionado')),
      );
      return;
    }

    setState(() {
      _producto = p;
      _cargando = true;
    });
    try {
      final ubicaciones = await ref
          .read(ajusteStockRepositoryProvider)
          .stockPorUbicacionDeProducto(p.idProducto, idAlmacen: idAlmacen);
      if (!mounted) return;
      _limpiarControladores();
      for (var i = 0; i < ubicaciones.length; i++) {
        _controladores[i] = TextEditingController();
      }
      setState(() => _ubicaciones = ubicaciones);
    } catch (e) {
      if (!mounted) return;
      setState(() => _producto = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _volverAProducto() {
    _limpiarControladores();
    setState(() {
      _producto = null;
      _ubicaciones = const [];
    });
  }

  Future<void> _crear() async {
    final cantidades = <double>[];
    for (var i = 0; i < _ubicaciones.length; i++) {
      final u = _ubicaciones[i];
      final valor = double.tryParse((_controladores[i]?.text ?? '').replaceAll(',', '.'));
      if (valor == null || valor < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falta la cantidad de ${u.ubicacionNombre}')),
        );
        return;
      }
      if (u.idZona == null || u.idAlmacen == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo resolver la zona de ${u.ubicacionNombre}')),
        );
        return;
      }
      cantidades.add(valor);
    }

    final cantidadesAgregadas = <double>[];
    for (var i = 0; i < _agregadas.length; i++) {
      final valor = double.tryParse(_controladoresAgregadas[i].text.replaceAll(',', '.'));
      if (valor == null || valor <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cantidad inválida en ${_agregadas[i].ubicacion.nombre} (debe ser mayor a 0)')),
        );
        return;
      }
      cantidadesAgregadas.add(valor);
    }
    final total = _ubicaciones.length + _agregadas.length;
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá al menos una ubicación para contar')),
      );
      return;
    }

    final observaciones = _observacionController.text.trim();
    final repo = ref.read(ajusteStockRepositoryProvider);
    final aplicarDirecto = ref.read(puedeAplicarAjusteDirectoProvider);
    String? errorAplicacion;

    /// Confirma+aplica si corresponde; un fallo no corta el resto (el
    /// ajuste ya existe y queda para terminar a mano desde el detalle).
    Future<bool> aplicar(int id) async {
      if (!aplicarDirecto) return false;
      try {
        await repo.confirmarYAplicar(id);
        return true;
      } catch (e) {
        errorAplicacion ??= describeError(e);
        return false;
      }
    }
    final creados = <_AjusteCreado>[];

    setState(() => _guardando = true);
    try {
      for (var i = 0; i < _ubicaciones.length; i++) {
        final u = _ubicaciones[i];
        final id = await repo.crear(
          modoAjuste: _modoAjuste,
          motivoCategoria: _motivoCategoria,
          idAlmacen: u.idAlmacen!,
          idZona: u.idZona!,
          idUbicacion: u.idUbicacion,
          observaciones: observaciones.isEmpty ? null : observaciones,
          items: [
            AjusteStockItemCreateIn(
              idProducto: _producto!.idProducto,
              idUnidadMedida: u.idUnidadMedida,
              idUbicacion: u.idUbicacion,
              cantidadContada: cantidades[i],
            ),
          ],
        );
        creados.add((
          idAjusteStock: id,
          ubicacion: '${u.ubicacionNombre} (${u.ubicacionCodigo})',
          aplicado: await aplicar(id),
        ));
      }
      for (var i = 0; i < _agregadas.length; i++) {
        final (:ubicacion, :item) = _agregadas[i];
        final id = await repo.crear(
          modoAjuste: _modoAjuste,
          motivoCategoria: _motivoCategoria,
          idAlmacen: ubicacion.idAlmacen!,
          idZona: ubicacion.idZona!,
          idUbicacion: ubicacion.idUbicacion,
          observaciones: observaciones.isEmpty ? null : observaciones,
          items: [
            AjusteStockItemCreateIn(
              idProducto: item.idProducto,
              idUnidadMedida: item.idUnidadMedida,
              idUbicacion: ubicacion.idUbicacion,
              cantidadContada: cantidadesAgregadas[i],
              esLoteNuevo: true,
              loteProveedor: item.loteProveedor,
              fechaVencimiento: item.fechaVencimiento,
              fechaFaenado: item.fechaFaenado,
            ),
          ],
        );
        creados.add((
          idAjusteStock: id,
          ubicacion: '${ubicacion.nombre} (${ubicacion.codigo})',
          aplicado: await aplicar(id),
        ));
      }
      if (!mounted) return;
      setState(() => _creados = creados);
      if (errorAplicacion != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Algunos ajustes no se pudieron aplicar: $errorAplicacion')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Cada ajuste es su propia transacción: si falla a mitad, los ya
      // creados quedan en BORRADOR — se muestran para no perderlos de vista.
      if (creados.isNotEmpty) setState(() => _creados = creados);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            creados.isEmpty
                ? describeError(e)
                : 'Se crearon ${creados.length} de $total ajustes. Error: ${describeError(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_creados != null) {
      body = _Resultado(producto: _producto!, creados: _creados!);
    } else if (_producto == null) {
      body = BuscadorProductoAjuste(
        ayuda: 'Elegí el producto a controlar. Después vas a contar cuánto hay en cada ubicación donde está.',
        onSeleccionar: _seleccionarProducto,
      );
    } else if (_cargando) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _PasoConteo(
        producto: _producto!,
        ubicaciones: _ubicaciones,
        controladores: _controladores,
        agregadas: _agregadas,
        controladoresAgregadas: _controladoresAgregadas,
        onAgregarUbicacion: _agregarUbicacion,
        onQuitarAgregada: _quitarAgregada,
        observacionController: _observacionController,
        guardando: _guardando,
        onVolver: _volverAProducto,
        onCrear: _crear,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Control por producto')),
      body: body,
    );
  }
}

class _PasoConteo extends StatelessWidget {
  const _PasoConteo({
    required this.producto,
    required this.ubicaciones,
    required this.controladores,
    required this.agregadas,
    required this.controladoresAgregadas,
    required this.onAgregarUbicacion,
    required this.onQuitarAgregada,
    required this.observacionController,
    required this.guardando,
    required this.onVolver,
    required this.onCrear,
  });

  final ProductoSimple producto;
  final List<StockEnUbicacion> ubicaciones;
  final Map<int, TextEditingController> controladores;
  final List<UbicacionAgregada> agregadas;
  final List<TextEditingController> controladoresAgregadas;
  final VoidCallback onAgregarUbicacion;
  final ValueChanged<int> onQuitarAgregada;
  final TextEditingController observacionController;
  final bool guardando;
  final VoidCallback onVolver;
  final Future<void> Function() onCrear;

  @override
  Widget build(BuildContext context) {
    final sinNada = ubicaciones.isEmpty && agregadas.isEmpty;
    // filas: existentes + agregadas + botón agregar + observación
    final totalFilas = ubicaciones.length + agregadas.length + 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductoElegidoHeader(nombre: producto.nombre, codigo: producto.codigoInterno, onCambiar: guardando ? null : onVolver),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
          child: Text(
            ubicaciones.isEmpty
                ? 'El sistema no tiene stock de este producto en el almacén. Si lo encontraste en alguna ubicación, agregala.'
                : 'Contá cuánto hay realmente en cada ubicación. Todas necesitan una cantidad (0 si no hay nada). '
                    'Si está en otra ubicación, agregala.',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: totalFilas,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final idxAgregada = i - ubicaciones.length;
              if (idxAgregada >= 0 && idxAgregada < agregadas.length) {
                return _FilaAgregada(
                  agregada: agregadas[idxAgregada],
                  controller: controladoresAgregadas[idxAgregada],
                  guardando: guardando,
                  onQuitar: () => onQuitarAgregada(idxAgregada),
                );
              }
              if (i == totalFilas - 2) {
                return Center(
                  child: TextButton.icon(
                    onPressed: guardando ? null : onAgregarUbicacion,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Agregar ubicación'),
                  ),
                );
              }
              if (i == totalFilas - 1) {
                return TextField(
                  controller: observacionController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Observación (opcional)'),
                );
              }
              final u = ubicaciones[i];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.accentDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.ubicacionNombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                          ),
                          Text(u.ubicacionCodigo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: controladores[i],
                        enabled: !guardando,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(suffixText: u.unidadSimbolo, hintText: 'Contar'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ElevatedButton(
            onPressed: guardando || sinNada ? null : () => onCrear(),
            child: guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Crear ajuste'),
          ),
        ),
      ],
    );
  }
}

/// Fila de una ubicación agregada a mano: chip "NUEVA", datos del lote y
/// cantidad editable; se puede quitar.
class _FilaAgregada extends StatelessWidget {
  const _FilaAgregada({
    required this.agregada,
    required this.controller,
    required this.guardando,
    required this.onQuitar,
  });

  final UbicacionAgregada agregada;
  final TextEditingController controller;
  final bool guardando;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final (:ubicacion, :item) = agregada;
    final detalleLote = [
      'Lote nuevo',
      if (item.loteProveedor != null) item.loteProveedor!,
      if (item.fechaVencimiento != null) 'vence ${formatFecha(item.fechaVencimiento!)}',
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentSoft, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          const Icon(Icons.add_location_alt_outlined, color: AppColors.accentDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        ubicacion.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(6)),
                      child: const Text(
                        'NUEVA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                      ),
                    ),
                  ],
                ),
                Text(
                  detalleLote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: TextField(
              controller: controller,
              enabled: !guardando,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(suffixText: item.unidadSimbolo),
            ),
          ),
          IconButton(
            onPressed: guardando ? null : onQuitar,
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            tooltip: 'Quitar',
          ),
        ],
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.producto, required this.creados});

  final ProductoSimple producto;
  final List<_AjusteCreado> creados;

  @override
  Widget build(BuildContext context) {
    final pendientes = creados.where((c) => !c.aplicado).length;
    final titulo = pendientes == 0
        ? (creados.length == 1 ? 'Se aplicó 1 ajuste' : 'Se aplicaron ${creados.length} ajustes')
        : (creados.length == 1 ? 'Se creó 1 ajuste en borrador' : 'Se crearon ${creados.length} ajustes ($pendientes en borrador)');
    final ayuda = pendientes == 0
        ? '${producto.nombre} · uno por ubicación. El stock ya quedó corregido.'
        : '${producto.nombre} · uno por ubicación. Los que están en borrador hay que confirmarlos y aplicarlos desde el detalle.';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.accent, size: 48),
        const SizedBox(height: 12),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
        const SizedBox(height: 4),
        Text(
          ayuda,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        for (final c in creados) ...[
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push('/ajuste-stock/${c.idAjusteStock}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.accentDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        c.ubicacion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                    ),
                    Text(
                      c.aplicado ? 'Aplicado' : 'Borrador',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.aplicado ? AppColors.okTx : AppColors.sub,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppColors.faint),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
