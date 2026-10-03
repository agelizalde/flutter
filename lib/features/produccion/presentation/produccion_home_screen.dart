import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/produccion_providers.dart';
import 'widgets/orden_en_curso_tile.dart';
import 'widgets/receta_tile.dart';
import 'widgets/seccion_label.dart';

/// Punto de entrada de Producción — "Retomar" (órdenes EN_PROCESO/PAUSADA)
/// arriba, elegir receta abajo. Análogo a `TallerInicioPage.jsx` de la web,
/// pero pensado para mobile: sin panel admin, solo el flujo del operario.
class ProduccionHomeScreen extends ConsumerStatefulWidget {
  const ProduccionHomeScreen({super.key});

  @override
  ConsumerState<ProduccionHomeScreen> createState() => _ProduccionHomeScreenState();
}

class _ProduccionHomeScreenState extends ConsumerState<ProduccionHomeScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onBuscar(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(produccionBusquedaRecetaProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordenesAsync = ref.watch(ordenesEnCursoProvider);
    final recetasAsync = ref.watch(recetasListadoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Producción'),
        actions: [
          PopupMenuButton<_ProduccionMenuOpcion>(
            icon: const Icon(Icons.more_vert),
            onSelected: (opcion) {
              switch (opcion) {
                case _ProduccionMenuOpcion.misProducciones:
                  context.push('/produccion/mis-producciones');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _ProduccionMenuOpcion.misProducciones,
                child: Text('Ver mis producciones'),
              ),
              // Más opciones se agregan acá.
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordenesEnCursoProvider);
          ref.invalidate(recetasListadoProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            ordenesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (ordenes) {
                if (ordenes.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SeccionLabel(icono: Icons.history, texto: 'RETOMAR'),
                    const SizedBox(height: 10),
                    for (final o in ordenes) ...[
                      OrdenEnCursoTile(orden: o),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 22),
                  ],
                );
              },
            ),
            const SeccionLabel(icono: Icons.receipt_long_outlined, texto: 'ELEGÍ QUÉ PRODUCIR'),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              onChanged: _onBuscar,
              decoration: const InputDecoration(
                hintText: 'Buscar receta...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 14),
            recetasAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
              ),
              data: (recetas) {
                if (recetas.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 32, color: AppColors.faint),
                          SizedBox(height: 10),
                          Text('No hay recetas activas', style: TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final r in recetas) ...[
                      RecetaTile(
                        receta: r,
                        onTap: () => context.push('/produccion/nueva/${r.idReceta}'),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Opciones del menú de arriba a la derecha en el Home de Producción — hoy
/// solo "Ver mis producciones", pensado para sumar más entradas después.
enum _ProduccionMenuOpcion { misProducciones }
