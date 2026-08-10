import '../../../core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../application/stock_providers.dart';
import '../domain/stock_models.dart';

/// Productos cuyo proveedor cabecera (`productos.id_proveedor_cabecera`)
/// es el proveedor elegido — paso intermedio de la búsqueda "por
/// proveedor". `/productos` no trae cantidades de stock, por eso la fila
/// solo muestra nombre/código; el detalle completo se ve al entrar.
class ProveedorProductosScreen extends ConsumerWidget {
  const ProveedorProductosScreen({
    super.key,
    required this.idProveedor,
    this.nombreProveedor,
  });

  final int idProveedor;
  final String? nombreProveedor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productosPorProveedorProvider(idProveedor));

    return Scaffold(
      appBar: AppBar(title: Text(nombreProveedor ?? 'Proveedor')),
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
                'Este proveedor no tiene productos cargados',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = items[i];
              return _ProductoSimpleTile(
                producto: p,
                onTap: () => context.push('/stock/producto/${p.idProducto}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductoSimpleTile extends StatelessWidget {
  const _ProductoSimpleTile({required this.producto, required this.onTap});

  final ProductoSimple producto;
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        producto.nombre,
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
                        producto.codigoInterno,
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
                const Icon(Icons.chevron_right, color: AppColors.faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
