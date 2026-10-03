import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/vehiculos_providers.dart';
import '../domain/vehiculo_models.dart';

/// Entrada al módulo de Mantenimiento (`/vehiculos`): listado de vehículos,
/// cada uno abre su ficha con el historial de mantenimientos (ver
/// `VehiculoDetalleScreen`). Versión simple del `MantenimientosTab.jsx` de
/// la web — sin asignar partes/periodicidad, solo ver e historial + carga
/// libre.
class VehiculosHomeScreen extends ConsumerStatefulWidget {
  const VehiculosHomeScreen({super.key});

  @override
  ConsumerState<VehiculosHomeScreen> createState() => _VehiculosHomeScreenState();
}

class _VehiculosHomeScreenState extends ConsumerState<VehiculosHomeScreen> {
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
      ref.read(vehiculosQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authControllerProvider).value;
    if (usuario != null && !usuario.tienePermiso('vehiculos.ver')) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
          title: const Text('Mantenimiento'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tenés permiso para ver el módulo de Mantenimiento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    final async = ref.watch(vehiculosListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
        title: const Text('Mantenimiento'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, tipo o patente...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(vehiculosListProvider),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          describeError(e),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.erTx),
                        ),
                      ),
                    ),
                  ],
                ),
                data: (vehiculos) {
                  if (vehiculos.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        const Icon(Icons.directions_car_outlined, size: 48, color: AppColors.faint),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text('Sin vehículos todavía', style: TextStyle(color: AppColors.muted)),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: vehiculos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _VehiculoTile(
                      vehiculo: vehiculos[i],
                      onTap: () => context.push('/vehiculos/${vehiculos[i].idVehiculo}'),
                    ),
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

class _VehiculoTile extends StatelessWidget {
  const _VehiculoTile({required this.vehiculo, required this.onTap});

  final Vehiculo vehiculo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.accentSoft,
                backgroundImage: vehiculo.fotoUrl != null ? NetworkImage(Env.resolveStorageUrl(vehiculo.fotoUrl!)) : null,
                child: vehiculo.fotoUrl == null
                    ? const Icon(Icons.local_shipping_outlined, color: AppColors.accentDark)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehiculo.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                    ),
                    if (vehiculo.subtituloDisplay.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        vehiculo.subtituloDisplay,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (vehiculo.kilometrajeActual != null) ...[
                Text(
                  '${vehiculo.kilometrajeActual} km',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.chevron_right, color: AppColors.faint),
            ],
          ),
        ),
      ),
    );
  }
}
