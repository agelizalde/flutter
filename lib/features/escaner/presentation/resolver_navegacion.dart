import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../recepcion/application/recepcion_providers.dart';
import '../../recepcion/domain/recepcion_models.dart';
import '../domain/escaneo_resultado.dart';
import 'contenedor_detalle_screen.dart';

/// Punto único de navegación después de resolver un código escaneado —
/// usado tanto por `BuscadorScreen` (buscador con cámara) como por el
/// botón "Escanear" del bottom nav, para no duplicar esta lógica.
///
/// Producto/Ubicación/Pedido/Orden de producción tienen un solo destino
/// real hoy, así que se navega directo. OC es la excepción: puede haber
/// una recepción en curso ligada a esa OC, así que se ofrece una hoja de
/// acciones (`GET /recepciones/ver/oc/{id}`) — esto es lo que cubre el
/// caso "Recepción" del escaneo contextual, que no tiene código propio.
Future<void> resolverYNavegar(
  BuildContext context,
  WidgetRef ref,
  EscaneoResultado resultado, {
  String? codigoNoEncontrado,
}) async {
  switch (resultado) {
    case EscaneoProducto(:final idProducto):
      context.push('/stock/producto/$idProducto');
    case EscaneoUbicacion(:final idUbicacion, :final nombre):
      context.push('/stock/ubicacion/$idUbicacion', extra: nombre);
    case EscaneoZona(:final idZona, :final nombre):
      context.push('/stock/zona/$idZona', extra: nombre);
    case EscaneoOc(:final idOc):
      await _abrirAccionesOc(context, ref, idOc);
    case EscaneoPedido(:final idPedido):
      context.push('/pedidos/info/$idPedido');
    case EscaneoOrdenProduccion(:final idOrden):
      context.push('/produccion/taller/$idOrden');
    case EscaneoContenedor(:final detalle):
      Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => ContenedorDetalleScreen(detalle: detalle)),
      );
    case EscaneoNoEncontrado():
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código no reconocido: ${codigoNoEncontrado ?? ''}')),
      );
  }
}

Future<void> _abrirAccionesOc(BuildContext context, WidgetRef ref, int idOc) async {
  List<Recepcion> recepciones = const [];
  try {
    recepciones = await ref.read(recepcionRepositoryProvider).recepcionesPorOc(idOc);
  } catch (_) {
    // Si falla la consulta de recepciones asociadas, se sigue mostrando la
    // hoja igual, solo que sin esas 2 acciones extra — "Ver info de OC"
    // (la acción segura, de solo lectura) sigue disponible siempre.
  }
  recepciones = recepciones.where((r) => r.estado != 'ANULADA').toList();

  Recepcion? recepcionRelevante;
  for (final r in recepciones) {
    if (r.estado == 'PEND_CONTROL') {
      recepcionRelevante = r;
      break;
    }
  }
  recepcionRelevante ??= recepciones.isNotEmpty ? recepciones.first : null;

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AccionesOcSheet(idOc: idOc, recepcionRelevante: recepcionRelevante),
  );
}

class _AccionesOcSheet extends StatelessWidget {
  const _AccionesOcSheet({required this.idOc, required this.recepcionRelevante});

  final int idOc;
  final Recepcion? recepcionRelevante;

  @override
  Widget build(BuildContext context) {
    final recepcion = recepcionRelevante;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ORDEN DE COMPRA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _AccionTile(
              icono: Icons.receipt_long_outlined,
              titulo: 'Ver info de OC',
              onTap: () {
                Navigator.of(context).pop();
                context.push('/recepcion/oc/info/$idOc');
              },
            ),
            if (recepcion != null && recepcion.estado == 'PEND_CONTROL')
              _AccionTile(
                icono: Icons.fact_check_outlined,
                titulo: 'Controlar recepción',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/recepcion/${recepcion.idRecepcion}/controlar');
                },
              )
            else if (recepcion != null)
              _AccionTile(
                icono: Icons.move_to_inbox_outlined,
                titulo: 'Continuar recepción',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/recepcion/${recepcion.idRecepcion}');
                },
              )
            else
              _AccionTile(
                icono: Icons.move_to_inbox_outlined,
                titulo: 'Recibir esta OC',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/recepcion/oc/$idOc/items');
                },
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _AccionTile extends StatelessWidget {
  const _AccionTile({required this.icono, required this.titulo, required this.onTap});

  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(icono, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
