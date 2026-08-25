import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/parsing.dart';
import '../application/firmas_providers.dart';
import '../domain/firma_solicitud.dart';

/// Detalle genérico de una solicitud de firma (monto/regla/motivo, más
/// aprobar/rechazar si está PENDIENTE) — equivalente mobile de
/// `SolicitudGenerica` en `SolicitudDetail.jsx`. A diferencia de la web,
/// esta pantalla no tiene una vista específica por tipo de documento (la
/// hoja A4 de la OC, por ejemplo, es web-only); alcanza para decidir
/// aprobar o rechazar sin tener que abrir la web.
class FirmaSolicitudDetalleScreen extends ConsumerWidget {
  const FirmaSolicitudDetalleScreen({super.key, required this.idFirmaSolicitud});

  final int idFirmaSolicitud;

  Future<void> _aprobar(BuildContext context, WidgetRef ref, FirmaSolicitud solicitud) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar solicitud'),
        content: Text('¿Confirmás la firma de "${solicitud.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Aprobar')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(firmasRepositoryProvider)
          .aprobar(idFirmaSolicitud: solicitud.idFirmaSolicitud, expectedVersion: solicitud.rowVersion);
      ref.invalidate(firmaSolicitudDetalleProvider(solicitud.idFirmaSolicitud));
      ref.invalidate(firmasPendientesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma aprobada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  Future<void> _rechazar(BuildContext context, WidgetRef ref, FirmaSolicitud solicitud) async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RechazarFirmaSheet(),
    );
    if (motivo == null) return;

    try {
      await ref
          .read(firmasRepositoryProvider)
          .rechazar(idFirmaSolicitud: solicitud.idFirmaSolicitud, expectedVersion: solicitud.rowVersion, motivo: motivo);
      ref.invalidate(firmaSolicitudDetalleProvider(solicitud.idFirmaSolicitud));
      ref.invalidate(firmasPendientesProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(firmaSolicitudDetalleProvider(idFirmaSolicitud));

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitud de firma')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (solicitud) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(firmaSolicitudDetalleProvider(idFirmaSolicitud)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _HeaderCard(solicitud: solicitud),
                const SizedBox(height: 16),
                _DatosCard(solicitud: solicitud),
                if (solicitud.pendiente) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _aprobar(context, ref, solicitud),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Aprobar'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.okTx),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _rechazar(context, ref, solicitud),
                    icon: const Icon(Icons.block, size: 20, color: AppColors.erTx),
                    label: const Text('Rechazar', style: TextStyle(color: AppColors.erTx)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.erTx)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  solicitud.titulo,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  'Solicitud #${solicitud.idFirmaSolicitud}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _EstadoBadge(estado: solicitud.estado),
        ],
      ),
    );
  }
}

class _DatosCard extends StatelessWidget {
  const _DatosCard({required this.solicitud});

  final FirmaSolicitud solicitud;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Dato(etiqueta: 'Monto', valor: formatGs(solicitud.monto)),
          const Divider(height: 20, color: AppColors.border),
          _Dato(
            etiqueta: 'Regla aplicada',
            valor: solicitud.reglaNombre ??
                (solicitud.documentoTipoPermisoFallback != null
                    ? 'Ninguna — requiere el permiso "${solicitud.documentoTipoPermisoFallback}"'
                    : '— (no requería firma)'),
          ),
          const Divider(height: 20, color: AppColors.border),
          _Dato(etiqueta: 'Solicitado por', valor: solicitud.solicitanteUsername ?? '—'),
          const Divider(height: 20, color: AppColors.border),
          _Dato(etiqueta: 'Fecha de solicitud', valor: formatFechaHora(solicitud.fechaSolicitud)),
          if (solicitud.idUsuarioResolutor != null) ...[
            const Divider(height: 20, color: AppColors.border),
            _Dato(etiqueta: 'Resuelto por', valor: solicitud.resolutorUsername ?? '—'),
            if (solicitud.fechaResolucion != null) ...[
              const Divider(height: 20, color: AppColors.border),
              _Dato(etiqueta: 'Fecha de resolución', valor: formatFechaHora(solicitud.fechaResolucion!)),
            ],
          ],
          if (solicitud.motivo != null && solicitud.motivo!.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.border),
            _Dato(etiqueta: 'Motivo', valor: solicitud.motivo!),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
      ],
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (etiqueta, bg, fg) = switch (estado) {
      'PENDIENTE' => ('Pendiente', AppColors.waBg, AppColors.waTx),
      'APROBADO' => ('Aprobado', AppColors.okBg, AppColors.okTx),
      'RECHAZADO' => ('Rechazado', AppColors.erBg, AppColors.erTx),
      'ANULADA' => ('Anulada', AppColors.soft, AppColors.sub),
      'NO_REQUERIDA' => ('No requerida', AppColors.soft, AppColors.sub),
      _ => (estado, AppColors.soft, AppColors.sub),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(etiqueta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _RechazarFirmaSheet extends StatefulWidget {
  const _RechazarFirmaSheet();

  @override
  State<_RechazarFirmaSheet> createState() => _RechazarFirmaSheetState();
}

class _RechazarFirmaSheetState extends State<_RechazarFirmaSheet> {
  final _motivoController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  void _confirmar() {
    final motivo = _motivoController.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = 'El motivo es obligatorio para rechazar');
      return;
    }
    Navigator.of(context).pop(motivo);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              const Text(
                'Rechazar solicitud',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              const Text('El motivo es obligatorio.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 16),
              TextField(
                controller: _motivoController,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Motivo del rechazo'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _confirmar,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.erTx),
                child: const Text('Confirmar rechazo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
