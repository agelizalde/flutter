import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/ajuste_stock_providers.dart';
import '../domain/ajuste_stock_models.dart';

/// Lista completa de ajustes de stock, con búsqueda + filtro de estado.
/// La creación vive en `AjusteStockHomeScreen` (botón "Nuevo ajuste" /
/// "Merma") — esta pantalla es de solo lectura/consulta.
class AjusteStockHistorialScreen extends ConsumerStatefulWidget {
  const AjusteStockHistorialScreen({super.key});

  @override
  ConsumerState<AjusteStockHistorialScreen> createState() => _AjusteStockHistorialScreenState();
}

class _AjusteStockHistorialScreenState extends ConsumerState<AjusteStockHistorialScreen> {
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
      ref.read(ajusteStockBusquedaProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(ajusteStockBusquedaProvider);
    final estado = ref.watch(ajusteStockEstadoFiltroProvider);
    final async = ref.watch(ajustesStockListadoProvider((query, estado)));

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de ajustes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar por código, observación...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                for (final f in const [
                  (null, 'Todos'),
                  ('BORRADOR', 'Borrador'),
                  ('CONFIRMADO', 'Confirmado'),
                  ('APLICADO', 'Aplicado'),
                  ('ANULADO', 'Anulado'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: estado == f.$1,
                      onSelected: (_) => ref.read(ajusteStockEstadoFiltroProvider.notifier).state = f.$1,
                      selectedColor: AppColors.accentSoft,
                      labelStyle: TextStyle(
                        color: estado == f.$1 ? AppColors.accentDark : AppColors.sub,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      side: BorderSide(color: estado == f.$1 ? AppColors.accent : AppColors.border),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(ajustesStockListadoProvider),
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
                        Icon(Icons.fact_check_outlined, size: 40, color: AppColors.faint),
                        SizedBox(height: 12),
                        Center(child: Text('Sin resultados', style: TextStyle(color: AppColors.muted))),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _AjusteTile(ajuste: items[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AjusteTile extends StatelessWidget {
  const _AjusteTile({required this.ajuste});

  final AjusteStock ajuste;

  @override
  Widget build(BuildContext context) {
    final estado = _EstadoVisual.de(ajuste.estado);
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
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fact_check_outlined, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ajuste.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ajuste.ubicacionNombre} (${ajuste.ubicacionCodigo}) · ${ajuste.totalItems} ítem(s)'
                      '${ajuste.totalDiferencias > 0 ? ' · ${ajuste.totalDiferencias} con diferencia' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: estado.bg, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  estado.etiqueta,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estado.fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVisual {
  const _EstadoVisual(this.etiqueta, this.bg, this.fg);

  final String etiqueta;
  final Color bg;
  final Color fg;

  static _EstadoVisual de(String estado) {
    switch (estado) {
      case 'BORRADOR':
        return const _EstadoVisual('Borrador', AppColors.soft, AppColors.sub);
      case 'CONFIRMADO':
        return const _EstadoVisual('Confirmado', AppColors.inBg, AppColors.inTx);
      case 'APLICADO':
        return const _EstadoVisual('Aplicado', AppColors.okBg, AppColors.okTx);
      case 'ANULADO':
        return const _EstadoVisual('Anulado', AppColors.erBg, AppColors.erTx);
      default:
        return _EstadoVisual(estado, AppColors.soft, AppColors.sub);
    }
  }
}
