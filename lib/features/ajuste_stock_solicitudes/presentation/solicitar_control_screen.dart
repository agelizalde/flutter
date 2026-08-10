import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../ajuste_stock/domain/ajuste_stock_models.dart' show motivosAjusteStock;
import '../../recepcion/domain/recepcion_models.dart' show UbicacionSimple;
import '../application/ajuste_stock_solicitudes_providers.dart';
import '../domain/solicitud_models.dart';

enum _Paso { ubicacion, detalle }

/// Le pide a otro usuario que vaya a contar una ubicación (flujo B de
/// Ajuste de Stock). A diferencia de `NuevoAjusteScreen`, acá no se cuenta
/// nada -- solo se elige dónde, por qué y a quién, y queda PENDIENTE hasta
/// que el asignado hace el conteo real desde "Mis solicitudes".
class SolicitarControlScreen extends ConsumerStatefulWidget {
  const SolicitarControlScreen({super.key});

  @override
  ConsumerState<SolicitarControlScreen> createState() => _SolicitarControlScreenState();
}

class _SolicitarControlScreenState extends ConsumerState<SolicitarControlScreen> {
  final _ubicacionController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _observacionController = TextEditingController();
  Timer? _debounceUbicacion;
  Timer? _debounceUsuario;

  _Paso _paso = _Paso.ubicacion;
  UbicacionSimple? _ubicacion;
  UsuarioAsignable? _usuarioAsignado;
  String _motivoCategoria = motivosAjusteStock.first.$1;
  bool _guardando = false;

  @override
  void dispose() {
    _debounceUbicacion?.cancel();
    _debounceUsuario?.cancel();
    _ubicacionController.dispose();
    _usuarioController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  void _onUbicacionChanged(String value) {
    _debounceUbicacion?.cancel();
    _debounceUbicacion = Timer(const Duration(milliseconds: 400), () {
      ref.read(solicitudBusquedaUbicacionProvider.notifier).state = value;
    });
  }

  void _onUsuarioChanged(String value) {
    _debounceUsuario?.cancel();
    _debounceUsuario = Timer(const Duration(milliseconds: 300), () {
      ref.read(solicitudBusquedaUsuarioProvider.notifier).state = value;
    });
  }

  void _elegirUbicacion(UbicacionSimple u) {
    setState(() {
      _ubicacion = u;
      _paso = _Paso.detalle;
    });
  }

  Future<void> _enviar() async {
    if (_usuarioAsignado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí a quién asignarle el control')),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await ref.read(ajusteStockSolicitudesRepositoryProvider).crear(
        idAlmacen: _ubicacion!.idAlmacen!,
        idZona: _ubicacion!.idZona!,
        idUbicacion: _ubicacion!.idUbicacion,
        idUsuarioAsignado: _usuarioAsignado!.idUsuario,
        motivoCategoria: _motivoCategoria,
        observaciones: _observacionController.text.trim().isEmpty
            ? null
            : _observacionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se le pidió a ${_usuarioAsignado!.nombreMostrar} contar ${_ubicacion!.nombre}')),
      );
      context.pop();
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
      appBar: AppBar(title: const Text('Solicitar control de stock')),
      body: switch (_paso) {
        _Paso.ubicacion => _PasoUbicacion(
            controller: _ubicacionController,
            onChanged: _onUbicacionChanged,
            onSeleccionar: _elegirUbicacion,
          ),
        _Paso.detalle => _PasoDetalle(
            ubicacion: _ubicacion!,
            motivoCategoria: _motivoCategoria,
            usuarioController: _usuarioController,
            usuarioAsignado: _usuarioAsignado,
            observacionController: _observacionController,
            guardando: _guardando,
            onMotivoChanged: (v) => setState(() => _motivoCategoria = v),
            onUsuarioChanged: _onUsuarioChanged,
            onUsuarioSeleccionado: (u) => setState(() => _usuarioAsignado = u),
            onVolver: () => setState(() => _paso = _Paso.ubicacion),
            onEnviar: _enviar,
          ),
      },
    );
  }
}

class _PasoUbicacion extends ConsumerWidget {
  const _PasoUbicacion({required this.controller, required this.onChanged, required this.onSeleccionar});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<UbicacionSimple> onSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(solicitudResultadosUbicacionProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: controller,
            autofocus: true,
            onChanged: onChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar ubicación a hacer contar (nombre o código)...',
              prefixIcon: Icon(Icons.search),
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

class _PasoDetalle extends ConsumerWidget {
  const _PasoDetalle({
    required this.ubicacion,
    required this.motivoCategoria,
    required this.usuarioController,
    required this.usuarioAsignado,
    required this.observacionController,
    required this.guardando,
    required this.onMotivoChanged,
    required this.onUsuarioChanged,
    required this.onUsuarioSeleccionado,
    required this.onVolver,
    required this.onEnviar,
  });

  final UbicacionSimple ubicacion;
  final String motivoCategoria;
  final TextEditingController usuarioController;
  final UsuarioAsignable? usuarioAsignado;
  final TextEditingController observacionController;
  final bool guardando;
  final ValueChanged<String> onMotivoChanged;
  final ValueChanged<String> onUsuarioChanged;
  final ValueChanged<UsuarioAsignable?> onUsuarioSeleccionado;
  final VoidCallback onVolver;
  final Future<void> Function() onEnviar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(solicitudResultadosUsuarioProvider);

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
        DropdownButtonFormField<String>(
          initialValue: motivoCategoria,
          items: motivosAjusteStock
              .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
              .toList(),
          onChanged: (v) => onMotivoChanged(v ?? motivoCategoria),
        ),
        const SizedBox(height: 20),
        const Text('Asignar a', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sub)),
        const SizedBox(height: 8),
        if (usuarioAsignado != null)
          Material(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              leading: const Icon(Icons.person, color: AppColors.accentDark),
              title: Text(usuarioAsignado!.nombreMostrar, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => onUsuarioSeleccionado(null),
              ),
            ),
          )
        else ...[
          TextField(
            controller: usuarioController,
            onChanged: onUsuarioChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar usuario del depósito...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          usuariosAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Sin usuarios disponibles en este depósito', style: TextStyle(color: AppColors.muted)),
                );
              }
              return Column(
                children: items
                    .map((u) => Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onUsuarioSeleccionado(u),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Text(u.nombreMostrar, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
        const SizedBox(height: 20),
        const Text('Observación (opcional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.sub)),
        const SizedBox(height: 8),
        TextField(
          controller: observacionController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Notas para quien va a contar...'),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: guardando ? null : () => onEnviar(),
          child: guardando
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}

