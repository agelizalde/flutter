import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../recepcion/domain/recepcion_models.dart';
import '../application/stock_providers.dart';

/// Ubicaciones dentro de una zona — paso intermedio de "escanear zona"
/// (buscador/escáner genérico, ver `features/escaner`). Catálogo completo
/// (`GET /ubicaciones?id_zona=`), no filtrado por stock, para que una
/// ubicación vacía también aparezca (mismo criterio que
/// `EscanerRepository._buscarUbicacion`). Tocar una ubicación lleva a
/// `UbicacionProductosScreen`, que ya lista ahí los productos unificados
/// con su vencimiento más próximo; desde esa pantalla, tocar un producto
/// muestra su desglose por lote (`ProductoDetalleScreen`).
class ZonaUbicacionesScreen extends ConsumerWidget {
  const ZonaUbicacionesScreen({
    super.key,
    required this.idZona,
    this.nombreZona,
  });

  final int idZona;
  final String? nombreZona;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ubicacionesDeZonaProvider(idZona));

    return Scaffold(
      appBar: AppBar(title: Text(nombreZona ?? 'Zona')),
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
                'Sin ubicaciones en esta zona',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final u = items[i];
              return _UbicacionTile(
                ubicacion: u,
                onTap: () => context.push('/stock/ubicacion/${u.idUbicacion}', extra: u.nombre),
              );
            },
          );
        },
      ),
    );
  }
}

class _UbicacionTile extends StatelessWidget {
  const _UbicacionTile({required this.ubicacion, required this.onTap});

  final UbicacionSimple ubicacion;
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
                const Icon(Icons.location_on_outlined, color: AppColors.muted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ubicacion.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      if (ubicacion.codigo.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          ubicacion.codigo,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
