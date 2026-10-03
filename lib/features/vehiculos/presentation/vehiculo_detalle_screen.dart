import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../core/widgets/picker_field.dart';
import '../../auth/application/auth_controller.dart';
import '../application/vehiculos_providers.dart';
import '../domain/vehiculo_models.dart';

/// Ficha de un vehículo: datos básicos + historial de mantenimientos, con
/// alta rápida de uno nuevo (título libre, sin asignar partes/periodicidad —
/// ver nota en `VehiculosHomeScreen`).
class VehiculoDetalleScreen extends ConsumerWidget {
  const VehiculoDetalleScreen({super.key, required this.idVehiculo});

  final int idVehiculo;

  Future<void> _nuevoMantenimiento(BuildContext context, WidgetRef ref) async {
    final tituloCtrl = TextEditingController();
    final descripcionCtrl = TextEditingController();
    final kilometrajeCtrl = TextEditingController();
    final costoCtrl = TextEditingController();
    DateTime fecha = DateTime.now();
    XFile? archivo;

    final ok = await showFormSheet(
      context,
      titulo: 'Nuevo mantenimiento',
      textoGuardar: 'Guardar mantenimiento',
      initialChildSize: 0.75,
      camposBuilder: (context, setStateSheet) => [
        TextField(
          controller: tituloCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Título *', hintText: 'Ej: Cambio de aceite'),
        ),
        const SizedBox(height: 12),
        PickerField(
          label: 'Fecha *',
          value: formatFecha(fecha),
          onTap: () async {
            final elegida = await showDatePicker(
              context: context,
              initialDate: fecha,
              firstDate: DateTime(fecha.year - 5),
              lastDate: DateTime.now(),
            );
            if (elegida != null) setStateSheet(() => fecha = elegida);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: kilometrajeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Kilometraje', hintText: 'Ej: 45000'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: costoCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Costo (Gs.)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descripcionCtrl,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descripción / observaciones'),
        ),
        const SizedBox(height: 12),
        if (archivo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.attach_file, size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    archivo!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ),
                InkWell(
                  onTap: () => setStateSheet(() => archivo = null),
                  child: const Icon(Icons.close, size: 18, color: AppColors.muted),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: () async {
            final foto = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (foto != null) setStateSheet(() => archivo = foto);
          },
          icon: const Icon(Icons.attach_file),
          label: Text(archivo == null ? 'Adjuntar foto (opcional)' : 'Cambiar foto adjunta'),
        ),
      ],
      onGuardar: () async {
        final titulo = tituloCtrl.text.trim();
        if (titulo.isEmpty) throw Exception('El título es obligatorio');

        final kilometraje = kilometrajeCtrl.text.trim().isEmpty ? null : int.tryParse(kilometrajeCtrl.text.trim());
        if (kilometrajeCtrl.text.trim().isNotEmpty && kilometraje == null) {
          throw Exception('Kilometraje inválido');
        }

        final costoTexto = costoCtrl.text.trim().replaceAll(',', '.');
        final costo = costoTexto.isEmpty ? null : double.tryParse(costoTexto);
        if (costoTexto.isNotEmpty && costo == null) throw Exception('Costo inválido');

        await ref
            .read(vehiculosRepositoryProvider)
            .crearMantenimiento(
              idVehiculo,
              titulo: titulo,
              descripcion: descripcionCtrl.text.trim().isEmpty ? null : descripcionCtrl.text.trim(),
              fechaRealizado: fecha,
              kilometraje: kilometraje,
              costo: costo,
              archivo: archivo,
            );
      },
    );

    if (ok == true) {
      ref.invalidate(mantenimientosProvider(idVehiculo));
      ref.invalidate(vehiculoDetalleProvider(idVehiculo));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;
    final puedeCargar = usuario?.tienePermiso('vehiculos.editar') ?? false;

    final vehiculoAsync = ref.watch(vehiculoDetalleProvider(idVehiculo));
    final mantenimientosAsync = ref.watch(mantenimientosProvider(idVehiculo));

    return Scaffold(
      appBar: AppBar(title: const Text('Vehículo')),
      floatingActionButton: puedeCargar
          ? FloatingActionButton.extended(
              onPressed: () => _nuevoMantenimiento(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Mantenimiento'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vehiculoDetalleProvider(idVehiculo));
          ref.invalidate(mantenimientosProvider(idVehiculo));
        },
        child: vehiculoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx))),
            ],
          ),
          data: (vehiculo) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                _VehiculoHeader(vehiculo: vehiculo),
                const SizedBox(height: 22),
                const Text(
                  'HISTORIAL DE MANTENIMIENTOS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted, letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                mantenimientosAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 30),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
                  ),
                  data: (mantenimientos) {
                    if (mantenimientos.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Center(
                          child: Text('Todavía no hay mantenimientos cargados', style: TextStyle(color: AppColors.muted)),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final m in mantenimientos) ...[
                          _MantenimientoTile(mantenimiento: m),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VehiculoHeader extends StatelessWidget {
  const _VehiculoHeader({required this.vehiculo});

  final Vehiculo vehiculo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.accentSoft,
            backgroundImage: vehiculo.fotoUrl != null ? NetworkImage(Env.resolveStorageUrl(vehiculo.fotoUrl!)) : null,
            child: vehiculo.fotoUrl == null
                ? const Icon(Icons.local_shipping_outlined, size: 28, color: AppColors.accentDark)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehiculo.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.text)),
                if (vehiculo.subtituloDisplay.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(vehiculo.subtituloDisplay, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
                if (vehiculo.kilometrajeActual != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${vehiculo.kilometrajeActual} km actuales',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accentDark),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MantenimientoTile extends StatelessWidget {
  const _MantenimientoTile({required this.mantenimiento});

  final Mantenimiento mantenimiento;

  @override
  Widget build(BuildContext context) {
    final m = mantenimiento;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.tituloDisplay,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.text),
                ),
              ),
              Text(formatFecha(m.fechaRealizado), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          if (m.descripcion != null && m.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(m.descripcion!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (m.kilometraje != null)
                _Dato(icon: Icons.speed_outlined, texto: '${m.kilometraje} km'),
              if (m.costo != null) _Dato(icon: Icons.payments_outlined, texto: formatGs(m.costo!)),
              if (m.responsableNombre != null) _Dato(icon: Icons.person_outline, texto: m.responsableNombre!),
              if (m.archivoUrl != null) const _Dato(icon: Icons.attach_file, texto: 'Con archivo adjunto'),
            ],
          ),
          if (m.archivoUrl != null && m.esImagenAdjunta) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                Env.resolveStorageUrl(m.archivoUrl!),
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(texto, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    );
  }
}
