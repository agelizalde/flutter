import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/recepcion_providers.dart';
import 'widgets/recepcion_tile.dart';

/// Lista filtrable de recepciones en estado `INGRESADA` o `PEND_CONTROL`
/// (nunca borradores/confirmadas/controladas/anuladas), acotada al
/// almacén base del usuario — ver `recepcionListadoProvider`. Búsqueda por
/// proveedor/almacén/observación dentro de ese subconjunto.
/// Se reusa para dos pantallas distintas según el `estadoFijo`:
/// - Historial completo (`/recepcion/historial`): ambos estados, **solo
///   las recepciones que hizo el usuario logueado**.
/// - Pendientes de control (`/recepcion/pendientes-control`): `estadoFijo
///   = 'PEND_CONTROL'`, **de todo el almacén sin importar quién la
///   recibió** (el control es responsabilidad del almacén, no de quien
///   recibió) — requiere el permiso `recepciones.controlar`, si no lo
///   tiene se bloquea la pantalla.
/// La acción de crear vive en `RecepcionHomeScreen`, esta pantalla es de
/// solo lectura/consulta.
class RecepcionHistorialScreen extends ConsumerStatefulWidget {
  const RecepcionHistorialScreen({
    super.key,
    this.estadoFijo,
    this.titulo = 'Historial de recepciones',
  });

  final String? estadoFijo;
  final String titulo;

  @override
  ConsumerState<RecepcionHistorialScreen> createState() => _RecepcionHistorialScreenState();
}

class _RecepcionHistorialScreenState extends ConsumerState<RecepcionHistorialScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.estadoFijo == 'PEND_CONTROL') {
      final usuario = ref.watch(authControllerProvider).value;
      if (!(usuario?.tienePermiso('recepciones.controlar') ?? false)) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.titulo)),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 40, color: AppColors.faint),
                  SizedBox(height: 12),
                  Text(
                    'No tenés permiso para ver los pendientes de control.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final async = ref.watch(recepcionListadoProvider((_query, widget.estadoFijo)));

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por proveedor, almacén...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _debounce?.cancel();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(recepcionListadoProvider),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      describeError(e),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.erTx),
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(
                          widget.estadoFijo == 'PEND_CONTROL' ? Icons.check_circle_outline : Icons.search_off,
                          size: 40,
                          color: AppColors.faint,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            widget.estadoFijo == 'PEND_CONTROL'
                                ? 'No tenés recepciones pendientes de control'
                                : 'Sin resultados',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => RecepcionTile(recepcion: items[i]),
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
