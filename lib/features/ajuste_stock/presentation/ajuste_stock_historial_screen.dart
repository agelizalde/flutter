import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';

/// Historial: ajustes APLICADOS del último mes en el almacén seleccionado,
/// del más reciente al más viejo. Cada fila muestra quién lo hizo, cuándo,
/// el tipo de ajuste y cuántos cambios generó. Tocar una fila abre el
/// detalle, que es donde se puede anular (dentro de la hora siguiente a la
/// aplicación, ver `AjusteStock.puedeRevertir`).
class AjusteStockHistorialScreen extends ConsumerWidget {
  const AjusteStockHistorialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ajustesStockListadoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ajustes')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ajustesStockListadoProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Icon(Icons.fact_check_outlined, size: 40, color: AppColors.faint),
                  SizedBox(height: 12),
                  Center(
                    child: Text('No hubo ajustes aplicados en el último mes', style: TextStyle(color: AppColors.muted)),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              itemCount: items.length + 1,
              separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 4 : 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    '${items.length} ajuste${items.length == 1 ? '' : 's'} aplicado${items.length == 1 ? '' : 's'} en el último mes',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
                  );
                }
                return _AjusteTile(ajuste: items[i - 1]);
              },
            );
          },
        ),
      ),
    );
  }
}

/// "Tipo de ajuste" legible a partir del motivo: los conteos son un control
/// de stock; las bajas (rotura, consumo interno, vencimiento, otro) son
/// mermas. Ojo: el backend no guarda si fue control por ubicación o por
/// producto, así que eso no se puede distinguir acá.
String _tipoAjuste(String motivoCategoria) {
  switch (motivoCategoria) {
    case 'CONTEO_FISICO':
    case 'CONTEO_RUTINARIO':
      return 'Control de stock';
    case 'ROTURA':
    case 'CONSUMO_INTERNO':
    case 'VENCIMIENTO':
    case 'OTRO':
      return 'Merma · ${labelMotivoAjuste(motivoCategoria)}';
    default:
      return labelMotivoAjuste(motivoCategoria);
  }
}

class _AjusteTile extends StatelessWidget {
  const _AjusteTile({required this.ajuste});

  final AjusteStock ajuste;

  @override
  Widget build(BuildContext context) {
    final usuario = ajuste.usuarioAplicacionUsername ?? ajuste.usuarioConteoUsername ?? 'Sin usuario';
    final fecha = ajuste.fechaAplicacion ?? ajuste.fechaConteo;
    final cambios = ajuste.totalDiferencias;
    final esMerma = _tipoAjuste(ajuste.motivoCategoria).startsWith('Merma');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/ajuste-stock/${ajuste.idAjusteStock}'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: esMerma ? AppColors.waBg : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  esMerma ? Icons.recycling_outlined : Icons.fact_check_outlined,
                  color: esMerma ? AppColors.waTx : AppColors.accentDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (fecha != null) formatFechaHora(fecha),
                        _tipoAjuste(ajuste.motivoCategoria),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.sub),
                    ),
                    Text(
                      ajuste.ubicacionNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.faint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cambios > 0 ? AppColors.inBg : AppColors.soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  cambios == 1 ? '1 cambio' : '$cambios cambios',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cambios > 0 ? AppColors.inTx : AppColors.sub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
