import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../application/produccion_providers.dart';
import '../domain/produccion_models.dart';

String _fmtDuracion(int segundos) {
  var s = segundos;
  if (s < 0) s = 0;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = s % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m ${ss.toString().padLeft(2, '0')}s';
  return '${ss}s';
}

String _fmtFecha(DateTime f) {
  final d = f.day.toString().padLeft(2, '0');
  final m = f.month.toString().padLeft(2, '0');
  final hh = f.hour.toString().padLeft(2, '0');
  final mm = f.minute.toString().padLeft(2, '0');
  return '$d/$m/${f.year} $hh:$mm';
}

String _fmtCantidad(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Reporte de solo lectura de una producción ya cerrada (FINALIZADA/ANULADA)
/// — a diferencia de [OrdenEnCursoScreen] (que atiende el flujo activo:
/// cronómetro, pausar/reanudar), esta pantalla es puro historial: qué se
/// produjo, cuánto, merma, cuánto tardó, quién la hizo, en qué lote y dónde
/// quedó guardada. Se llega acá desde "Mis producciones".
class OrdenDetalleScreen extends ConsumerWidget {
  const OrdenDetalleScreen({super.key, required this.idOrden});

  final int idOrden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ordenDetalleProvider(idOrden));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de producción')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (orden) => _Cuerpo(orden: orden),
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({required this.orden});

  final OrdenProduccion orden;

  @override
  Widget build(BuildContext context) {
    final anulada = orden.estado == 'ANULADA';
    final finalizada = orden.estado == 'FINALIZADA';
    final duracion = orden.tiempoRealSegundos ?? orden.tiempoTranscurridoSegundos;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _Cabecera(orden: orden),
        const SizedBox(height: 20),
        if (!anulada) ...[
          _Seccion(
            titulo: 'SE PRODUJO',
            icono: Icons.emoji_events_outlined,
            children: [for (final r in orden.resultado) _FilaResultado(linea: r)],
          ),
          if (orden.mermas.isNotEmpty) ...[
            const SizedBox(height: 20),
            _Seccion(
              titulo: 'MERMA',
              icono: Icons.local_fire_department_outlined,
              children: [
                for (final m in orden.mermas)
                  _FilaCantidad(nombre: m.productoNombre, cantidad: m.cantidadReal, unidad: m.unidadSimbolo),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _Seccion(
            titulo: 'INSUMOS USADOS',
            icono: Icons.inventory_2_outlined,
            children: [
              for (final c in orden.consumo)
                _FilaCantidad(nombre: c.productoNombre, cantidad: c.cantidadReal, unidad: c.unidadSimbolo),
            ],
          ),
          const SizedBox(height: 20),
        ] else ...[
          _Seccion(
            titulo: 'ANULACIÓN',
            icono: Icons.cancel_outlined,
            children: [_FilaDato('Motivo', orden.motivoAnulacion ?? 'Sin especificar')],
          ),
          const SizedBox(height: 20),
        ],
        _Seccion(
          titulo: 'DATOS',
          icono: Icons.info_outline,
          children: [
            _FilaDato('Hecho por', orden.operarioNombre ?? orden.creadorNombre ?? '—'),
            _FilaDato('Duración', _fmtDuracion(duracion)),
            _FilaDato('Almacén', orden.almacenNombre ?? '—'),
            if (orden.iniciadoEn != null) _FilaDato('Iniciada', _fmtFecha(orden.iniciadoEn!)),
            if (finalizada && orden.finalizadoEn != null) _FilaDato('Finalizada', _fmtFecha(orden.finalizadoEn!)),
            if (anulada && orden.actualizadoEn != null) _FilaDato('Anulada', _fmtFecha(orden.actualizadoEn!)),
            _FilaDato('Código', orden.codigo),
          ],
        ),
        if (finalizada) ...[
          const SizedBox(height: 24),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => context.push('/produccion/taller/${orden.idOrden}/etiquetas'),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Ver e imprimir etiquetas'),
            ),
          ),
        ],
      ],
    );
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.orden});

  final OrdenProduccion orden;

  ({Color color, Color fondo, String etiqueta}) get _estilo {
    switch (orden.estado) {
      case 'FINALIZADA':
        return (color: AppColors.okTx, fondo: AppColors.okBg, etiqueta: 'Finalizada');
      case 'ANULADA':
        return (color: AppColors.erTx, fondo: AppColors.erBg, etiqueta: 'Anulada');
      case 'EN_PROCESO':
        return (color: AppColors.okTx, fondo: AppColors.okBg, etiqueta: 'En curso');
      case 'PAUSADA':
        return (color: AppColors.waTx, fondo: AppColors.waBg, etiqueta: 'Pausada');
      default:
        return (color: AppColors.muted, fondo: AppColors.soft, etiqueta: 'Borrador');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estilo = _estilo;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orden.recetaNombre ?? orden.codigo,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.text),
                ),
                const SizedBox(height: 4),
                Text(orden.codigo, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: estilo.fondo, borderRadius: BorderRadius.circular(10)),
            child: Text(
              estilo.etiqueta,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: estilo.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.icono, required this.children});

  final String titulo;
  final IconData icono;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 15, color: AppColors.muted),
            const SizedBox(width: 6),
            Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({required this.linea});

  final OrdenLineaResultado linea;

  @override
  Widget build(BuildContext context) {
    final subtitulo = [
      if (linea.loteInterno != null && linea.loteInterno!.isNotEmpty) 'Lote ${linea.loteInterno}',
      if (linea.ubicacionNombre != null && linea.ubicacionNombre!.isNotEmpty) 'Guardado en ${linea.ubicacionNombre}',
      if (linea.fechaVencimiento != null) 'Vence ${_fmtFecha(linea.fechaVencimiento!).split(' ').first}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (linea.esPrincipal)
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 6),
              child: Icon(Icons.star, size: 14, color: Color(0xFFCA8A04)),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(linea.productoNombre, style: const TextStyle(fontSize: 13.5, color: AppColors.text, fontWeight: FontWeight.w600)),
                if (subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitulo, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          Text(
            '${_fmtCantidad(linea.cantidadReal ?? linea.cantidadPlanificada)} ${linea.unidadSimbolo}',
            style: const TextStyle(fontSize: 13.5, color: AppColors.sub, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FilaCantidad extends StatelessWidget {
  const _FilaCantidad({required this.nombre, required this.cantidad, required this.unidad});

  final String nombre;
  final double? cantidad;
  final String unidad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(nombre, style: const TextStyle(fontSize: 13.5, color: AppColors.text))),
          Text(
            '${_fmtCantidad(cantidad ?? 0)} $unidad',
            style: const TextStyle(fontSize: 13.5, color: AppColors.sub, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato(this.etiqueta, this.valor);

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(etiqueta, style: const TextStyle(fontSize: 13.5, color: AppColors.muted))),
          Text(valor, style: const TextStyle(fontSize: 13.5, color: AppColors.text, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
