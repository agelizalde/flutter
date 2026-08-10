import '../../../core/errors/app_exception.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../stock/domain/stock_models.dart' show ProveedorSimple;
import '../application/recepcion_providers.dart';
import '../domain/recepcion_models.dart';

class NuevaRecepcionScreen extends ConsumerStatefulWidget {
  const NuevaRecepcionScreen({super.key});

  @override
  ConsumerState<NuevaRecepcionScreen> createState() =>
      _NuevaRecepcionScreenState();
}

class _NuevaRecepcionScreenState extends ConsumerState<NuevaRecepcionScreen> {
  final _observacionController = TextEditingController();

  ProveedorSimple? _proveedor;
  AlmacenSimple? _almacen;
  UbicacionSimple? _ubicacion;
  List<UbicacionSimple> _ubicacionesDisponibles = const [];
  bool _cargandoUbicaciones = false;
  bool _guardando = false;

  /// El almacén nunca se elige a mano ni se muestra en pantalla — el
  /// usuario solo trabaja con el almacén que tiene asignado como base
  /// (`id_almacen_seleccionado`). Mientras se resuelve, la pantalla
  /// muestra un loader; si genuinamente no tiene ninguno asignado, bloquea
  /// la creación con un mensaje en vez de dejar elegir uno. Un error de
  /// red/backend al resolver es un caso DISTINTO (`_errorResolviendo`) —
  /// antes ambos casos se confundían en el mismo mensaje genérico, lo que
  /// hacía pensar que el usuario no tenía almacén asignado cuando en
  /// realidad había sido un fallo transitorio sin reintento posible.
  bool _resolviendoAlmacen = true;
  bool _sinAlmacenAsignado = false;
  Object? _errorResolviendo;

  @override
  void initState() {
    super.initState();
    _resolverAlmacenDelUsuario();
  }

  Future<void> _resolverAlmacenDelUsuario() async {
    setState(() {
      _resolviendoAlmacen = true;
      _sinAlmacenAsignado = false;
      _errorResolviendo = null;
    });
    try {
      final usuario = await ref.read(authControllerProvider.future);
      final idAlmacenSeleccionado = usuario?.idAlmacenSeleccionado;
      if (idAlmacenSeleccionado == null) {
        if (mounted) setState(() => _sinAlmacenAsignado = true);
        return;
      }

      final almacenes = await ref.read(almacenesProvider.future);
      AlmacenSimple? encontrado;
      for (final a in almacenes) {
        if (a.idAlmacen == idAlmacenSeleccionado) {
          encontrado = a;
          break;
        }
      }
      if (!mounted) return;
      if (encontrado == null) {
        setState(() => _errorResolviendo =
            'Tu almacén base (ID $idAlmacenSeleccionado) no se encontró en la lista de almacenes activos. '
            'Puede que esté inactivo — avisale a un administrador.');
        return;
      }

      _almacen = encontrado;
      await _cargarUbicaciones(encontrado.idAlmacen);
    } catch (e) {
      if (mounted) setState(() => _errorResolviendo = e);
    } finally {
      if (mounted) setState(() => _resolviendoAlmacen = false);
    }
  }

  /// Busca las ubicaciones tipo RECEPCION del almacén resuelto y deja la
  /// primera marcada por defecto — si tiene más de una, el dropdown sigue
  /// permitiendo cambiarla.
  Future<void> _cargarUbicaciones(int idAlmacen) async {
    setState(() => _cargandoUbicaciones = true);
    try {
      final ubicaciones = await ref.read(recepcionRepositoryProvider).listarUbicacionesDeRecepcion(idAlmacen);
      if (!mounted) return;
      setState(() {
        _ubicacionesDisponibles = ubicaciones;
        _ubicacion = ubicaciones.isNotEmpty ? ubicaciones.first : null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _cargandoUbicaciones = false);
    }
  }

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  Future<void> _elegirProveedor() async {
    final seleccionado = await showModalBottomSheet<ProveedorSimple>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _BuscarProveedorSheet(),
    );
    if (seleccionado != null) {
      setState(() => _proveedor = seleccionado);
    }
  }

  Future<void> _crear() async {
    if (_proveedor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un proveedor')),
      );
      return;
    }
    if (_almacen == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo determinar tu almacén base. Reintentá más tarde.')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      final recepcion = await ref
          .read(recepcionRepositoryProvider)
          .crearManual(
            idProveedor: _proveedor!.idProveedor,
            idAlmacen: _almacen!.idAlmacen,
            idUbicacionRecepcion: _ubicacion?.idUbicacion,
            observacion: _observacionController.text.trim().isEmpty
                ? null
                : _observacionController.text.trim(),
          );
      ref.invalidate(recepcionesRecientesProvider);
      ref.invalidate(recepcionListadoProvider);
      if (!mounted) return;
      context.pushReplacement('/recepcion/${recepcion.idRecepcion}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolviendoAlmacen) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva recepción')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_sinAlmacenAsignado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva recepción')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warehouse_outlined, size: 40, color: AppColors.faint),
                const SizedBox(height: 12),
                const Text(
                  'No tenés un almacén base asignado todavía. Pedile a un '
                  'administrador que te asigne uno antes de crear una recepción.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorResolviendo != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva recepción')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: AppColors.erTx),
                const SizedBox(height: 12),
                Text(
                  _errorResolviendo is String ? _errorResolviendo as String : describeError(_errorResolviendo!),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _resolverAlmacenDelUsuario,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva recepción')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _Label('Proveedor'),
          _SelectorField(
            valor: _proveedor?.nombreComercial ?? _proveedor?.razonSocial,
            placeholder: 'Elegir proveedor',
            onTap: _elegirProveedor,
          ),
          const SizedBox(height: 20),
          const _Label('Ubicación de recepción'),
          if (_cargandoUbicaciones)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            )
          else
            DropdownButtonFormField<UbicacionSimple?>(
              // `key` fuerza a recrear el FormField al terminar de cargar
              // las ubicaciones — `initialValue` solo se aplica una vez al
              // crearse, así que sin esto no reflejaría la preselección.
              key: ValueKey('ubicacion-${_ubicacion?.idUbicacion}'),
              initialValue: _ubicacion,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Automática (configuración del depósito)'),
                ),
                ..._ubicacionesDisponibles.map(
                  (u) => DropdownMenuItem(value: u, child: Text('${u.nombre} (${u.codigo})')),
                ),
              ],
              onChanged: (v) => setState(() => _ubicacion = v),
              decoration: const InputDecoration(hintText: 'Ubicación'),
            ),
          if (!_cargandoUbicaciones && _ubicacionesDisponibles.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'No hay ubicaciones de recepción creadas para tu depósito — se va a usar '
                'la configuración automática (si existe).',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 20),
          const _Label('Observación (opcional)'),
          TextField(
            controller: _observacionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Notas sobre esta recepción...',
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _guardando ? null : _crear,
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Crear recepción'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.sub,
        ),
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.valor,
    required this.placeholder,
    required this.onTap,
  });

  final String? valor;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 18,
              color: valor == null ? AppColors.faint : AppColors.accent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valor ?? placeholder,
                style: TextStyle(
                  color: valor == null ? AppColors.faint : AppColors.text,
                  fontWeight: valor == null ? FontWeight.normal : FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.search, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _BuscarProveedorSheet extends ConsumerStatefulWidget {
  const _BuscarProveedorSheet();

  @override
  ConsumerState<_BuscarProveedorSheet> createState() =>
      _BuscarProveedorSheetState();
}

class _BuscarProveedorSheetState extends ConsumerState<_BuscarProveedorSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(recepcionBusquedaProveedorProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recepcionResultadosProveedorProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const Text(
                'Buscar proveedor',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Nombre, RUC...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: async.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(describeError(e))),
                  data: (items) {
                    if (_controller.text.trim().isEmpty) {
                      return const Center(
                        child: Text('Escribí para buscar', style: TextStyle(color: AppColors.muted)),
                      );
                    }
                    if (items.isEmpty) {
                      return const Center(
                        child: Text('Sin resultados', style: TextStyle(color: AppColors.muted)),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = items[i];
                        return _ProveedorResultRow(
                          proveedor: p,
                          onTap: () => Navigator.of(context).pop(p),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProveedorResultRow extends StatelessWidget {
  const _ProveedorResultRow({required this.proveedor, required this.onTap});

  final ProveedorSimple proveedor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.local_shipping_outlined, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proveedor.nombreComercial ?? proveedor.razonSocial,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    Text(
                      proveedor.codigoProveedor,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
