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
///
/// El backend devuelve una fila por lote — acá se unifican por producto
/// (mismo producto puede tener varios lotes en la misma ubicación) sumando
/// la cantidad y quedándose con el vencimiento más próximo, porque para
/// este listado el lote no importa (a diferencia de traslados/ajuste de
/// stock, que sí necesitan elegir un lote puntual y siguen usando
/// `ExistenciaStock` sin unificar).
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
          final unificados = _unificarPorProducto(items);
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: unificados.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = unificados[i];
              return _ProductoUnificadoTile(
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

/// Total unificado de un producto en la ubicación — colapsa todos los
/// lotes de `items` en una fila por `idProducto`.
class _ProductoUnificado {
  const _ProductoUnificado({
    required this.idProducto,
    required this.productoNombre,
    required this.unidadSimbolo,
    required this.unidadPesable,
    required this.cantidadTotal,
    this.fechaVencimientoProxima,
  });

  final int idProducto;
  final String productoNombre;
  final String unidadSimbolo;
  final bool unidadPesable;
  final double cantidadTotal;
  final DateTime? fechaVencimientoProxima;
}

List<_ProductoUnificado> _unificarPorProducto(List<ExistenciaStock> items) {
  final porProducto = <int, _ProductoUnificado>{};
  for (final e in items) {
    final actual = porProducto[e.idProducto];
    porProducto[e.idProducto] = _ProductoUnificado(
      idProducto: e.idProducto,
      productoNombre: e.productoNombre,
      unidadSimbolo: e.unidadSimbolo,
      unidadPesable: e.unidadPesable,
      cantidadTotal: (actual?.cantidadTotal ?? 0) + e.cantidad,
      fechaVencimientoProxima: _masProxima(actual?.fechaVencimientoProxima, e.fechaVencimiento),
    );
  }
  return porProducto.values.toList()
    ..sort((a, b) => a.productoNombre.compareTo(b.productoNombre));
}

/// La más próxima entre dos fechas de vencimiento, ignorando nulls (un lote
/// sin control de vencimiento no debe "tapar" el vencimiento real de otro).
DateTime? _masProxima(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

class _ProductoUnificadoTile extends StatelessWidget {
  const _ProductoUnificadoTile({required this.producto, required this.onTap});

  final _ProductoUnificado producto;
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
                        producto.productoNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                      ),
                      if (producto.fechaVencimientoProxima != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Vence ${formatFecha(producto.fechaVencimientoProxima!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${formatCantidad(producto.cantidadTotal, pesable: producto.unidadPesable)} ${producto.unidadSimbolo}',
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
