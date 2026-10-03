import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/produccion_providers.dart';
import 'widgets/mi_produccion_tile.dart';

/// Historial personal de producción — órdenes FINALIZADAS donde el usuario
/// logueado aparece como creador u operario, cualquier almacén (ver
/// `misProduccionesProvider`). Solo lo ya cerrado: para lo pendiente
/// (EN_PROCESO/PAUSADA) está "Retomar" en el Home. Accesible desde el ícono
/// de opciones en [ProduccionHomeScreen]; primera entrada de ese menú,
/// pensada para crecer.
class MisProduccionesScreen extends ConsumerWidget {
  const MisProduccionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(misProduccionesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis producciones')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(misProduccionesProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (ordenes) {
            if (ordenes.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 60),
                  Center(child: Text('Todavía no finalizaste ninguna producción', style: TextStyle(color: AppColors.muted))),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: ordenes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => MiProduccionTile(orden: ordenes[i]),
            );
          },
        ),
      ),
    );
  }
}
