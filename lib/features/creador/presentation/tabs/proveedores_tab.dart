import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../application/creador_providers.dart';
import '../../domain/creador_models.dart';
import '../widgets/creador_tab_list.dart';
import '../../../../core/widgets/form_sheet.dart';

/// Alta rápida de proveedor: Nombre comercial, Razón social, RUC y código
/// verificador. `tipo_persona` (JURIDICA), `tipo_pago_compra` (CONTADO) y
/// `id_moneda_base` (PYG) se precargan solos — ver spec y
/// `CreadorApi.proveedorCrear`.
class ProveedoresTab extends ConsumerWidget {
  const ProveedoresTab({
    super.key,
    required this.puedeCrear,
    required this.puedeEditar,
  });

  final bool puedeCrear;
  final bool puedeEditar;

  Future<void> _abrirForm(
    BuildContext context,
    WidgetRef ref, {
    ProveedorCreador? proveedor,
  }) async {
    final nombreComercialCtrl = TextEditingController(
      text: proveedor?.nombreComercial ?? '',
    );
    final razonSocialCtrl = TextEditingController(
      text: proveedor?.razonSocial ?? '',
    );
    final rucCtrl = TextEditingController(text: proveedor?.ruc ?? '');
    final dvCtrl = TextEditingController(text: proveedor?.dv ?? '');

    final ok = await showFormSheet(
      context,
      titulo: proveedor == null ? 'Nuevo proveedor' : 'Editar proveedor',
      camposBuilder: (context, setStateSheet) => [
        TextField(
          controller: nombreComercialCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre comercial'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: razonSocialCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Razón social *'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: rucCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'RUC'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: dvCtrl,
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'D.V.',
                  counterText: '',
                ),
              ),
            ),
          ],
        ),
        if (proveedor == null) ...[
          const SizedBox(height: 8),
          const Text(
            'Se precarga como persona jurídica, pago contado y moneda Gs. — editable luego desde el ERP web.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
      onGuardar: () async {
        final razonSocial = razonSocialCtrl.text.trim();
        if (razonSocial.isEmpty)
          throw Exception('La razón social es obligatoria');
        final api = ref.read(creadorApiProvider);
        final nombreComercial = nombreComercialCtrl.text.trim();
        final ruc = rucCtrl.text.trim();
        final dv = dvCtrl.text.trim();

        if (proveedor == null) {
          int? idMonedaBase;
          try {
            final monedas = await api.monedasListar();
            idMonedaBase = monedas
                .firstWhere(
                  (m) => m.codigoIso == 'PYG',
                  orElse: () => monedas.first,
                )
                .idMoneda;
          } catch (_) {
            // Sin catálogo de monedas disponible: se crea sin moneda base,
            // se completa después desde la web.
          }
          await api.proveedorCrear(
            nombreComercial: nombreComercial.isEmpty ? null : nombreComercial,
            razonSocial: razonSocial,
            ruc: ruc.isEmpty ? null : ruc,
            codigoVerificador: dv.isEmpty ? null : dv,
            idMonedaBase: idMonedaBase,
          );
        } else {
          await api.proveedorEditar(
            idProveedor: proveedor.idProveedor,
            expectedVersion: proveedor.rowVersion,
            nombreComercial: nombreComercial.isEmpty ? null : nombreComercial,
            razonSocial: razonSocial,
            ruc: ruc.isEmpty ? null : ruc,
            codigoVerificador: dv.isEmpty ? null : dv,
          );
        }
      },
    );
    if (ok == true) ref.invalidate(creadorProveedoresListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(creadorProveedoresListProvider);
    return CreadorTabList<ProveedorCreador>(
      value: async,
      hintBuscar: 'Buscar por razón social o RUC...',
      onBuscar: (q) =>
          ref.read(creadorProveedoresQueryProvider.notifier).state = q,
      onRefresh: () => ref.invalidate(creadorProveedoresListProvider),
      onAgregar: puedeCrear ? () => _abrirForm(context, ref) : null,
      textoVacio: 'Sin proveedores todavía',
      itemBuilder: (context, p) => CreadorTile(
        titulo: p.etiqueta,
        subtitulo: p.ruc != null && p.ruc!.isNotEmpty
            ? 'RUC ${p.ruc}${p.dv != null ? '-${p.dv}' : ''}'
            : null,
        activo: p.activo,
        onTap: puedeEditar
            ? () => _abrirForm(context, ref, proveedor: p)
            : () {},
      ),
    );
  }
}
