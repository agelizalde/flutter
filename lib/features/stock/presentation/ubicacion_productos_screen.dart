import '../../../core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/utils/parsing.dart';
import '../application/stock_providers.dart';
import '../domain/stock_models.dart';

/// Productos físicamente presentes en una ubicación puntual — paso
/// intermedio de la búsqueda "por ubicación" (CONTEXTO_WHEREHOUSE.md:
/// `/stock/por-ubicacion` agrupa por ubicación, no da el detalle por
/// producto, así que acá se usa `/stock/existencias?id_ubicacion=`).
class UbicacionProductosScreen extends ConsumerWidget {
  const UbicacionProductosScreen({
    super.key,
    required this.idUbicacion,
    this.nombreUbicacion,
  });

  final int idUbicacion;
  final String? nombreUbicacion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(existenciasPorUbicacionProvider(idUbicacion));

    return Scaffold(
      appBar: AppBar(title: Text(nombreUbicacion ?? 'Ubicación')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            describeError(e),
            style: const TextStyle(color: AppColors.erTx),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'No hay stock en esta ubicación',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = items[i];
              return _ExistenciaTile(
                existencia: e,
                onTap: () => context.push('/stock/producto/${e.idProducto}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _ExistenciaTile extends StatelessWidget {
  const _ExistenciaTile({required this.existencia, required this.onTap});

  final ExistenciaStock existencia;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existencia.productoNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lote ${existencia.loteInterno}'
                        '${existencia.fechaVencimiento != null ? ' · Vence ${formatFecha(existencia.fechaVencimiento!)}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${existencia.cantidad.toStringAsFixed(0)} ${existencia.unidadSimbolo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                    ),
                    const Text(
                      'en stock',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
