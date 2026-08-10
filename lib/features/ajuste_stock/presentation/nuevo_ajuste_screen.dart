import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../ajuste_stock_solicitudes/application/ajuste_stock_solicitudes_providers.dart';
import '../../ajuste_stock_solicitudes/domain/solicitud_models.dart';
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../../stock/domain/stock_models.dart' show ExistenciaStock, ProductoSimple;
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';
import 'agregar_item_ajuste_screen.dart';

enum _Paso { ubicacion, motivo, conteo }

const _modoAjuste = 'POR_PRODUCTO';

String _formatCantidad(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Conteo por producto: agrupa varias existencias (lotes) bajo un único
/// campo de cantidad.
class _GrupoProducto {
  _GrupoProducto({required this.idProducto, required this.nombre, required this.idUnidadMedida, required this.unidadSimbolo, required this.cantidadSistema});

  final int idProducto;
  final String nombre;
  final int idUnidadMedida;
  final String unidadSimbolo;
  final double cantidadSistema;
}

/// Crea un ajuste de stock: elegir ubicación → motivo (Conteo físico /
/// Vencimiento) → contar por producto. Siempre POR_PRODUCTO — no hay
/// elección de modo. Los dos motivos usan el campo de cantidad distinto:
/// - Conteo físico: cuánto hay realmente (a ciegas, el campo arranca vacío)
///   → el sistema reajusta el stock (puede sumar o restar).
/// - Vencimiento: cuánto está vencido (arranca en 0) → el sistema descuenta
///   esa cantidad del lote que realmente está vencido (ver
///   CRITERIO_RESTAR_VENCIMIENTO_MAS_CERCANO en el backend).
///
/// Queda en BORRADOR y hace falta confirmar + aplicar después desde el
/// detalle (ver `ajuste_stock_service.py`). El atajo de un solo paso para
/// merma/consumo interno vive aparte, en `MermaRapidaScreen`.
class NuevoAjusteScreen extends ConsumerStatefulWidget {
  const NuevoAjusteScreen({super.key, this.solicitud});

  /// Si viene de "Mis solicitudes" (flujo B), la ubicación y el motivo ya
  /// fueron fijados por quien pidió el control -- se saltea el paso de
  /// elegir ubicación y el motivo queda fijo. Al crear el ajuste con éxito,
  /// se linkea automáticamente la solicitud (`solicitud_completar` en el
  /// backend) en vez de solo navegar al detalle.
  final SolicitudAjusteStock? solicitud;

  @override
  ConsumerState<NuevoAjusteScreen> createState() => _NuevoAjusteScreenState();
}

class _NuevoAjusteScreenState extends ConsumerState<NuevoAjusteScreen> {
  final _searchController = TextEditingController();
  final _observacionController = TextEditingController();
  final _filtroConteoController = TextEditingController();
  Timer? _debounce;

  late _Paso _paso;
  UbicacionSimple? _ubicacion;
  late String _motivoCategoria;

  bool get _esVencimiento => _motivoCategoria == 'VENCIMIENTO';

  @override
  void initState() {
    super.initState();
    final solicitud = widget.solicitud;
    if (solicitud != null) {
      _ubicacion = UbicacionSimple(
        idUbicacion: solicitud.idUbicacion,
        nombre: solicitud.ubicacionNombre,
        codigo: solicitud.ubicacionCodigo,
        idZona: solicitud.idZona,
        idAlmacen: solicitud.idAlmacen,
      );
      _motivoCategoria = solicitud.motivoCategoria;
      _paso = _Paso.motivo;
    } else {
      _motivoCategoria = motivosNuevoAjuste.first.$1;
      _paso = _Paso.ubicacion;
    }
  }

  bool _cargandoExistencias = false;
  final Map<int, TextEditingController> _controladoresProducto = {};
  List<_GrupoProducto> _gruposProducto = const [];

  /// Productos sin stock previo en la ubicación — crearán lote nuevo al
  /// aplicar. Solo tiene sentido en Conteo físico (no se puede "descubrir"
  /// stock vencido de un producto que el sistema no sabe que existe ahí).
  final List<AjusteItemNuevo> _itemsNuevos = [];
  final Map<int, TextEditingController> _controladoresNuevos = {};

  bool _guardando = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _observacionController.dispose();
    _filtroConteoController.dispose();
    for (final c in _controladoresProducto.values) {
      c.dispose();
    }
    for (final c in _controladoresNuevos.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(ajusteBusquedaUbicacionProvider.notifier).state = value;
    });
  }

  void _elegirUbicacion(UbicacionSimple u) {
    setState(() {
      _ubicacion = u;
      _paso = _Paso.motivo;
    });
  }

  /// Las ubicaciones no tienen código de barra separado — el `codigo` (ej.
  /// "CONT-A") es lo que se imprime en la etiqueta física, así que el
  /// código escaneado se busca directo contra `GET /ubicaciones?q=`. Si
  /// hay un único resultado con `codigo` exactamente igual, se selecciona
  /// solo (mismo patrón que el destino de Traslados).
  Future<void> _escanearUbicacion() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    _debounce?.cancel();
    _searchController.text = codigo;
    ref.read(ajusteBusquedaUbicacionProvider.notifier).state = codigo;

    try {
      final resultados = await ref.read(ajusteResultadosUbicacionProvider.future);
      final exactas = resultados
          .where((u) => u.codigo.trim().toLowerCase() == codigo.trim().toLowerCase())
          .toList();
      if (!mounted) return;
      if (exactas.length == 1) {
        _elegirUbicacion(exactas.first);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  /// Busca el producto escaneado. Si ya está en la lista lo resalta con el
  /// filtro; si no está y el motivo es Conteo físico, abre el formulario de
  /// agregar producto nuevo con ese producto pre-cargado (en Vencimiento no
  /// tiene sentido: no se puede marcar como vencido algo que el sistema no
  /// tiene registrado ahí).
  Future<void> _escanearProductoConteo() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo == null || !mounted) return;

    try {
      final producto = await ref.read(ajusteStockRepositoryProvider).buscarProductoPorCodigoBarra(codigo);
      if (!mounted) return;

      final estaEnLaLista = _gruposProducto.any((g) => g.idProducto == producto.idProducto);

      if (estaEnLaLista) {
        setState(() => _filtroConteoController.text = producto.nombre);
      } else if (!_esVencimiento) {
        await _irAAgregarProducto(productoInicial: producto);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ese producto no tiene stock en esta ubicación')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  void _agregarItemsNuevos(List<AjusteItemNuevo> nuevos) {
    setState(() {
      for (final item in nuevos) {
        final idx = _itemsNuevos.length;
        _itemsNuevos.add(item);
        _controladoresNuevos[idx] = TextEditingController(
          text: _formatCantidad(item.cantidadInicial),
        );
      }
    });
  }

  Future<void> _irAAgregarProducto({ProductoSimple? productoInicial}) async {
    final resultado = await Navigator.of(context).push<List<AjusteItemNuevo>>(
      MaterialPageRoute(
        builder: (_) => AgregarItemAjusteScreen(productoInicial: productoInicial),
      ),
    );
    if (resultado != null && resultado.isNotEmpty && mounted) {
      _agregarItemsNuevos(resultado);
    }
  }

  Future<void> _continuarAConteo() async {
    setState(() {
      _cargandoExistencias = true;
    });
    try {
      final existencias = await ref
          .read(ajusteStockRepositoryProvider)
          .existenciasDeUbicacion(_ubicacion!.idUbicacion);
      if (!mounted) return;

      for (final c in _controladoresProducto.values) {
        c.dispose();
      }
      _controladoresProducto.clear();
      for (final c in _controladoresNuevos.values) {
        c.dispose();
      }
      _controladoresNuevos.clear();
      _itemsNuevos.clear();

      final porProducto = <int, List<ExistenciaStock>>{};
      for (final e in existencias) {
        porProducto.putIfAbsent(e.idProducto, () => []).add(e);
      }
      _gruposProducto = porProducto.entries.map((entry) {
        final lotes = entry.value;
        final total = lotes.fold<double>(0, (acc, e) => acc + e.cantidad);
        return _GrupoProducto(
          idProducto: entry.key,
          nombre: lotes.first.productoNombre,
          idUnidadMedida: lotes.first.idUnidadMedida,
          unidadSimbolo: lotes.first.unidadSimbolo,
          cantidadSistema: total,
        );
      }).toList();
      for (final g in _gruposProducto) {
        // Conteo físico: arranca vacío (conteo a ciegas, sin sesgar con el
        // número del sistema). Vencimiento: arranca en 0 (nada vencido por
        // defecto, el usuario solo toca los productos que sí tienen).
        _controladoresProducto[g.idProducto] = TextEditingController(
          text: _esVencimiento ? '0' : '',
        );
      }

      setState(() {
        _paso = _Paso.conteo;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cargandoExistencias = false);
    }
  }

  Future<void> _crear() async {
    final items = <AjusteStockItemCreateIn>[];

    for (final g in _gruposProducto) {
      final texto = _controladoresProducto[g.idProducto]?.text ?? '';
      final valor = double.tryParse(texto.replaceAll(',', '.'));
      if (valor == null || valor < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cantidad inválida para "${g.nombre}"')),
        );
        return;
      }

      double cantidadContada;
      if (_esVencimiento) {
        if (valor > g.cantidadSistema) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No puede haber más vencido que el stock de "${g.nombre}" (${_formatCantidad(g.cantidadSistema)} ${g.unidadSimbolo})',
              ),
            ),
          );
          return;
        }
        cantidadContada = g.cantidadSistema - valor;
      } else {
        cantidadContada = valor;
      }

      items.add(AjusteStockItemCreateIn(
        idProducto: g.idProducto,
        idUnidadMedida: g.idUnidadMedida,
        idUbicacion: _ubicacion!.idUbicacion,
        cantidadContada: cantidadContada,
      ));
    }

    // Items nuevos (lote a crear) — solo aplica en Conteo físico.
    for (var idx = 0; idx < _itemsNuevos.length; idx++) {
      final n = _itemsNuevos[idx];
      final texto = _controladoresNuevos[idx]?.text ?? '';
      final cantidad = double.tryParse(texto.replaceAll(',', '.'));
      if (cantidad == null || cantidad <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cantidad inválida para "${n.productoNombre}" (lote nuevo)')),
        );
        return;
      }
      items.add(AjusteStockItemCreateIn(
        idProducto: n.idProducto,
        idUnidadMedida: n.idUnidadMedida,
        idUbicacion: _ubicacion!.idUbicacion,
        cantidadContada: cantidad,
        esLoteNuevo: true,
        loteProveedor: n.loteProveedor,
        fechaVencimiento: n.fechaVencimiento,
        fechaFaenado: n.fechaFaenado,
      ));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay nada para contar en esa ubicación')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final idAjusteStock = await ref.read(ajusteStockRepositoryProvider).crear(
        modoAjuste: _modoAjuste,
        motivoCategoria: _motivoCategoria,
        idAlmacen: _ubicacion!.idAlmacen!,
        idZona: _ubicacion!.idZona!,
        idUbicacion: _ubicacion!.idUbicacion,
        observaciones: _observacionController.text.trim().isEmpty
            ? null
            : _observacionController.text.trim(),
        items: items,
      );
      if (widget.solicitud != null) {
        await ref.read(ajusteStockSolicitudesRepositoryProvider).completar(
          idSolicitud: widget.solicitud!.idSolicitud,
          idAjusteStock: idAjusteStock,
        );
      }
      if (!mounted) return;
      context.pushReplacement('/ajuste-stock/$idAjusteStock');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo ajuste de stock')),
      body: switch (_paso) {
        _Paso.ubicacion => _PasoUbicacion(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSeleccionar: _elegirUbicacion,
            onEscanear: _escanearUbicacion,
          ),
        _Paso.motivo => _PasoMotivo(
            ubicacion: _ubicacion!,
            motivoCategoria: _motivoCategoria,
            motivoFijo: widget.solicitud != null,
            observacionController: _observacionController,
            cargando: _cargandoExistencias,
            onMotivoChanged: (v) => setState(() => _motivoCategoria = v),
            onVolver: widget.solicitud != null
                ? () => Navigator.of(context).maybePop()
                : () => setState(() => _paso = _Paso.ubicacion),
            onContinuar: _continuarAConteo,
          ),
        _Paso.conteo => _PasoConteo(
            ubicacion: _ubicacion!,
            esVencimiento: _esVencimiento,
            gruposProducto: _gruposProducto,
            controladoresProducto: _controladoresProducto,
            itemsNuevos: _itemsNuevos,
            controladoresNuevos: _controladoresNuevos,
            filtroController: _filtroConteoController,
            onFiltroChanged: (_) => setState(() {}),
            onEscanearProducto: _escanearProductoConteo,
            onAgregarProducto: _irAAgregarProducto,
            guardando: _guardando,
            onVolver: () => setState(() => _paso = _Paso.motivo),
            onCrear: _crear,
          ),
      },
    );
  }
}

class _PasoUbicacion extends ConsumerWidget {
  const _PasoUbicacion({
    required this.controller,
    required this.onChanged,
    required this.onSeleccionar,
    required this.onEscanear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<UbicacionSimple> onSeleccionar;
  final VoidCallback onEscanear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ajusteResultadosUbicacionProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Buscar ubicación a contar (nombre o código)...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                tooltip: 'Escanear ubicación',
                onPressed: onEscanear,
              ),
            ),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            data: (items) {
              if (controller.text.trim().isEmpty) {
                return const Center(child: Text('Escribí para buscar', style: TextStyle(color: AppColors.muted)));
              }
              if (items.isEmpty) {
                return const Center(child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final u = items[i];
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSeleccionar(u),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.location_on_outlined, color: AppColors.accentDark, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${u.nombre} (${u.codigo})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.faint),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PasoMotivo extends StatelessWidget {
  const _PasoMotivo({
    required this.ubicacion,
    required this.motivoCategoria,
    this.motivoFijo = false,
    required this.observacionController,
    required this.cargando,
    required this.onMotivoChanged,
    required this.onVolver,
    required this.onContinuar,
  });

  final UbicacionSimple ubicacion;
  final String motivoCategoria;

  /// `true` cuando la ubicación y el motivo vienen de una solicitud de otro
  /// usuario (flujo B) -- el motivo se muestra fijo en vez de elegible.
  final bool motivoFijo;
  final TextEditingController observacionController;
  final bool cargando;
  final ValueChanged<String> onMotivoChanged;
  final VoidCallback onVolver;
  final Future<void> Function() onContinuar;

  @override
  Widget build(BuildContext context) {
    final esVencimiento = motivoCategoria == 'VENCIMIENTO';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            IconButton(onPressed: onVolver, icon: const Icon(Icons.arrow_back)),
            Expanded(
              child: Text(
                '${ubicacion.nombre} (${ubicacion.codigo})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text('Motivo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sub)),
        const SizedBox(height: 8),
        if (motivoFijo)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: AppColors.soft, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    labelMotivoAjuste(motivoCategoria),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                ),
                const Text('Definido en la solicitud', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          )
        else
          SegmentedButton<String>(
            segments: motivosNuevoAjuste
                .map((m) => ButtonSegment(value: m.$1, label: Text(m.$2)))
                .toList(),
            selected: {motivoCategoria},
            onSelectionChanged: (s) => onMotivoChanged(s.first),
          ),
        const SizedBox(height: 6),
        Text(
          esVencimiento
              ? 'Vas a indicar cuántas unidades de cada producto están vencidas; el sistema descuenta esa cantidad del lote que realmente venció.'
              : 'Vas a contar cuánto hay realmente de cada producto; el sistema reajusta el stock (suma o resta) según la diferencia.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        const Text('Observación (opcional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sub)),
        const SizedBox(height: 8),
        TextField(
          controller: observacionController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Notas sobre este conteo...'),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: cargando ? null : onContinuar,
          child: cargando
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Continuar al conteo'),
        ),
      ],
    );
  }
}

class _PasoConteo extends StatelessWidget {
  const _PasoConteo({
    required this.ubicacion,
    required this.esVencimiento,
    required this.gruposProducto,
    required this.controladoresProducto,
    required this.itemsNuevos,
    required this.controladoresNuevos,
    required this.filtroController,
    required this.onFiltroChanged,
    required this.onEscanearProducto,
    required this.onAgregarProducto,
    required this.guardando,
    required this.onVolver,
    required this.onCrear,
  });

  final UbicacionSimple ubicacion;
  final bool esVencimiento;
  final List<_GrupoProducto> gruposProducto;
  final Map<int, TextEditingController> controladoresProducto;
  final List<AjusteItemNuevo> itemsNuevos;
  final Map<int, TextEditingController> controladoresNuevos;
  final TextEditingController filtroController;
  final ValueChanged<String> onFiltroChanged;
  final VoidCallback onEscanearProducto;
  final VoidCallback onAgregarProducto;
  final bool guardando;
  final VoidCallback onVolver;
  final Future<void> Function() onCrear;

  @override
  Widget build(BuildContext context) {
    final existentesVacios = gruposProducto.isEmpty;
    final sinNada = existentesVacios && itemsNuevos.isEmpty;

    final filtro = filtroController.text.trim().toLowerCase();
    final gruposFiltrados = filtro.isEmpty
        ? gruposProducto
        : gruposProducto.where((g) => g.nombre.toLowerCase().contains(filtro)).toList();
    final nuevosFiltrados = filtro.isEmpty
        ? itemsNuevos
        : itemsNuevos
            .where((n) => n.productoNombre.toLowerCase().contains(filtro))
            .toList();

    final itemsExistentes = gruposFiltrados.length;
    // +1 = botón agregar (solo en Conteo físico)
    final totalFilas = itemsExistentes + nuevosFiltrados.length + (esVencimiento ? 0 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(onPressed: onVolver, icon: const Icon(Icons.arrow_back)),
              Expanded(
                child: Text(
                  'Contar: ${ubicacion.nombre} (${ubicacion.codigo})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Text(
            esVencimiento
                ? 'Indicá cuántas unidades de cada producto están vencidas. Dejá en 0 los que no tengan vencidos.'
                : 'Contá lo que hay realmente en esta ubicación. Todos los productos necesitan una cantidad.',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        if (!existentesVacios)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: filtroController,
              onChanged: onFiltroChanged,
              decoration: InputDecoration(
                hintText: 'Buscar producto en esta ubicación...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppColors.accent),
                  tooltip: 'Escanear producto',
                  onPressed: onEscanearProducto,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            itemCount: totalFilas,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              // Filas de grupos existentes
              if (i < itemsExistentes) {
                final g = gruposFiltrados[i];
                return _FilaConteo(
                  titulo: g.nombre,
                  subtitulo: esVencimiento
                      ? 'Stock actual: ${_formatCantidad(g.cantidadSistema)} ${g.unidadSimbolo}'
                      : 'Todos los lotes de este producto',
                  unidadSimbolo: g.unidadSimbolo,
                  controller: controladoresProducto[g.idProducto]!,
                  hintText: esVencimiento ? null : 'Contar',
                );
              }

              // Filas de items nuevos
              final idxNuevo = i - itemsExistentes;
              if (idxNuevo < nuevosFiltrados.length) {
                // Buscar el índice real en itemsNuevos para usar el controlador correcto
                final n = nuevosFiltrados[idxNuevo];
                final idxReal = itemsNuevos.indexOf(n);
                return _FilaConteoNuevo(
                  nombre: n.productoNombre,
                  loteProveedor: n.loteProveedor,
                  unidadSimbolo: n.unidadSimbolo,
                  controller: controladoresNuevos[idxReal]!,
                );
              }

              // Último elemento: botón "+ Agregar producto" (solo Conteo físico)
              return Center(
                child: TextButton.icon(
                  onPressed: onAgregarProducto,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar producto'),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ElevatedButton(
            onPressed: sinNada || guardando ? null : () => onCrear(),
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

/// Fila para un item nuevo (sin stock previo en la ubicación). Muestra el
/// chip "NUEVO" como indicador visual y la cantidad es editable igual que
/// en `_FilaConteo`.
class _FilaConteoNuevo extends StatelessWidget {
  const _FilaConteoNuevo({
    required this.nombre,
    required this.loteProveedor,
    required this.unidadSimbolo,
    required this.controller,
  });

  final String nombre;
  final String? loteProveedor;
  final String unidadSimbolo;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final subtitulo = loteProveedor != null
        ? 'Lote nuevo · $loteProveedor'
        : 'Lote nuevo';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentSoft, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NUEVO',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                      ),
                    ),
                  ],
                ),
                Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(suffixText: unidadSimbolo),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaConteo extends StatelessWidget {
  const _FilaConteo({
    required this.titulo,
    required this.subtitulo,
    required this.unidadSimbolo,
    required this.controller,
    this.hintText,
  });

  final String titulo;
  final String subtitulo;
  final String unidadSimbolo;
  final TextEditingController controller;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                ),
                Text(subtitulo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(suffixText: unidadSimbolo, hintText: hintText),
            ),
          ),
        ],
      ),
    );
  }
}
