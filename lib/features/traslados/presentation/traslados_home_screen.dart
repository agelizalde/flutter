import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/traslados_providers.dart';
import '../domain/traslado_models.dart';
import 'widgets/alerta_reacomodo_tile.dart';
import 'widgets/traslado_tile.dart';

/// Traslados y Acomodos son el mismo módulo (ver CONTEXTO_WHEREHOUSE.md):
/// "Pendientes" son las alertas de reacomodo (existencias en zonas
/// RECEPCION/REACOMODO esperando ubicación final) y "Historial" son los
/// traslados ya ejecutados. Ambas pestañas conviven en una sola pantalla,
/// igual que en la web (`TrasladosPage.jsx`).
class TrasladosHomeScreen extends ConsumerWidget {
  const TrasladosHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final puedeCrear = usuario?.tienePermiso('traslados.crear') ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Traslados'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Pendientes'), Tab(text: 'Historial')],
          ),
        ),
        body: const TabBarView(
          children: [_PendientesTab(), _HistorialTab()],
        ),
        floatingActionButton: puedeCrear
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final ok = await context.push<bool>('/traslados/nuevo');
                  if (ok == true) {
                    ref.invalidate(trasladosAlertasProvider);
                    ref.invalidate(trasladosListadoProvider);
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuevo traslado'),
              )
            : null,
      ),
    );
  }
}

class _PendientesTab extends ConsumerWidget {
  const _PendientesTab();

  Future<void> _trasladar(BuildContext context, WidgetRef ref, AlertaReacomodo alerta) async {
    final ok = await context.push<bool>('/traslados/nuevo', extra: alerta);
    if (ok == true) {
      ref.invalidate(trasladosAlertasProvider);
      ref.invalidate(trasladosListadoProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trasladosAlertasProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(trasladosAlertasProvider),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (alertas) {
          if (alertas.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.check_circle_outline, size: 40, color: AppColors.faint),
                SizedBox(height: 12),
                Center(
                  child: Text(
                    'No hay existencias pendientes de acomodar',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ],
            );
          }

          final recepcion = alertas.where((a) => a.tipoUbicacion == 'RECEPCION').toList();
          final reacomodo = alertas.where((a) => a.tipoUbicacion == 'REACOMODO').toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              if (recepcion.isNotEmpty) ...[
                _SeccionLabel('ZONA DE RECEPCIÓN (${recepcion.length})'),
                const SizedBox(height: 10),
                for (final a in recepcion) ...[
                  AlertaReacomodoTile(
                    alerta: a,
                    onTrasladar: () => _trasladar(context, ref, a),
                    onVerTraslado: (id) => context.push('/traslados/$id'),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 14),
              ],
              if (reacomodo.isNotEmpty) ...[
                _SeccionLabel('ZONA DE REACOMODO (${reacomodo.length})'),
                const SizedBox(height: 10),
                for (final a in reacomodo) ...[
                  AlertaReacomodoTile(
                    alerta: a,
                    onTrasladar: () => _trasladar(context, ref, a),
                    onVerTraslado: (id) => context.push('/traslados/$id'),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SeccionLabel extends StatelessWidget {
  const _SeccionLabel(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
    );
  }
}

class _HistorialTab extends ConsumerStatefulWidget {
  const _HistorialTab();

  @override
  ConsumerState<_HistorialTab> createState() => _HistorialTabState();
}

class _HistorialTabState extends ConsumerState<_HistorialTab> {
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
      ref.read(trasladosBusquedaProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(trasladosBusquedaProvider);
    final estado = ref.watch(trasladosEstadoFiltroProvider);
    final async = ref.watch(trasladosListadoProvider((query, estado)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar por código, producto...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FiltroChip(
                etiqueta: 'Todos',
                seleccionado: estado == null,
                onTap: () => ref.read(trasladosEstadoFiltroProvider.notifier).state = null,
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                etiqueta: 'Confirmados',
                seleccionado: estado == 'CONFIRMADO',
                onTap: () => ref.read(trasladosEstadoFiltroProvider.notifier).state = 'CONFIRMADO',
              ),
              const SizedBox(width: 8),
              _FiltroChip(
                etiqueta: 'Anulados',
                seleccionado: estado == 'ANULADO',
                onTap: () => ref.read(trasladosEstadoFiltroProvider.notifier).state = 'ANULADO',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(trasladosListadoProvider),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 100),
                      Icon(Icons.search_off, size: 40, color: AppColors.faint),
                      SizedBox(height: 12),
                      Center(child: Text('Sin resultados', style: TextStyle(color: AppColors.muted))),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => TrasladoTile(traslado: items[i]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FiltroChip extends StatelessWidget {
  const _FiltroChip({required this.etiqueta, required this.seleccionado, required this.onTap});

  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(etiqueta),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accentSoft,
      labelStyle: TextStyle(
        color: seleccionado ? AppColors.accentDark : AppColors.sub,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      side: BorderSide(color: seleccionado ? AppColors.accent : AppColors.border),
    );
  }
}
