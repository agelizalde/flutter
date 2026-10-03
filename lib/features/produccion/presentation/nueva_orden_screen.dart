import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/produccion_providers.dart';
import '../domain/produccion_models.dart';
import 'widgets/seccion_label.dart';

String _fmtDuracion(int segundos) {
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}min';
  return '${m}min';
}

String _fmtQty(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

/// Pantalla "cartel + cantidad" (pasos 1-4 del flujo pedido): muestra todo
/// lo que la receta necesita a escala de referencia, el operario carga
/// cuánto va a usar, el sistema estima en vivo (`POST .../preview`) y al
/// confirmar crea + inicia la orden en un solo paso.
///
/// Estética alineada a `ProduccionHomeScreen` (tarjetas planas blancas con
/// borde/ícono en cuadrado `accentSoft`, rótulos de sección uppercase vía
/// `SeccionLabel`) — antes tenía un cartel con gradiente de color por
/// "nivel" que no compartía look con el resto del flujo. El color ahora se
/// reserva para lo que de verdad puede salir mal: la cantidad (de ella se
/// escala todo lo demás), si hace falta ayuda para producir y los errores.
class NuevaOrdenScreen extends ConsumerStatefulWidget {
  const NuevaOrdenScreen({super.key, required this.idReceta});

  final int idReceta;

  @override
  ConsumerState<NuevaOrdenScreen> createState() => _NuevaOrdenScreenState();
}

class _NuevaOrdenScreenState extends ConsumerState<NuevaOrdenScreen> {
  final _cantidadController = TextEditingController();
  Timer? _debounce;

  OrdenPreview? _preview;
  bool _cargandoPreview = false;
  String? _errorPreview;
  bool _empezando = false;
  String? _errorEmpezar;

  @override
  void dispose() {
    _debounce?.cancel();
    _cantidadController.dispose();
    super.dispose();
  }

  void _onCantidadChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _preview = null;
      _errorPreview = null;
    });
    final cantidad = double.tryParse(value.replaceAll(',', '.'));
    if (cantidad == null || cantidad <= 0) return;

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _cargandoPreview = true);
      try {
        final preview = await ref
            .read(produccionRepositoryProvider)
            .preview(idReceta: widget.idReceta, cantidadReferenciaReal: cantidad);
        if (!mounted) return;
        setState(() => _preview = preview);
      } catch (e) {
        if (!mounted) return;
        setState(() => _errorPreview = describeError(e));
      } finally {
        if (mounted) setState(() => _cargandoPreview = false);
      }
    });
  }

  Future<void> _empezarAProducir() async {
    final preview = _preview;
    if (preview == null) return;
    final usuario = ref.read(authControllerProvider).value;
    final idAlmacen = usuario?.idAlmacenSeleccionado;
    if (idAlmacen == null) {
      setState(() => _errorEmpezar = 'Tu usuario no tiene un almacén asignado');
      return;
    }

    setState(() {
      _empezando = true;
      _errorEmpezar = null;
    });
    try {
      final idOrden = await ref.read(produccionRepositoryProvider).empezarAProducir(
        idReceta: widget.idReceta,
        cantidadReferenciaReal: preview.cantidadReferenciaReal,
        idAlmacen: idAlmacen,
      );
      ref.invalidate(ordenesEnCursoProvider);
      if (!mounted) return;
      context.go('/produccion/taller/$idOrden');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorEmpezar = describeError(e));
    } finally {
      if (mounted) setState(() => _empezando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recetaDetalleProvider(widget.idReceta));

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva producción')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(describeError(e), style: const TextStyle(color: AppColors.erTx)),
          ),
        ),
        data: (receta) => _buildBody(receta),
      ),
    );
  }

  Widget _buildBody(RecetaDetalle receta) {
    final referencia = receta.referencia;

    if (referencia == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: _ErrorBanner(
          'Esta receta no tiene un producto de consumo marcado como referencia — pedile a un administrador que la complete desde la web.',
        ),
      );
    }

    final tier = tierInfoFor(receta.vecesProducida);
    final necesitaAyuda = receta.usuariosRequeridos > 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // Cartel de la receta — misma tarjeta plana blanca con avatar
        // cuadrado `accentSoft` que usa `RecetaTile` en el Home, para que se
        // sienta el mismo lugar. El color ya no lo decide el "nivel": lo
        // decide si esta receta necesita más de un operario, el único dato
        // acá que de verdad importa que el operario note antes de arrancar.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.receipt_long_outlined, color: AppColors.accentDark, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receta.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.text),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(tier.icon, size: 12, color: tier.color),
                            const SizedBox(width: 4),
                            Text(
                              '${tier.label} · producida ${receta.vecesProducida}x',
                              style: TextStyle(fontSize: 12, color: tier.color, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _InfoChip(icono: Icons.timer_outlined, texto: _fmtDuracion(receta.tiempoReferenciaSegundos)),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icono: Icons.groups_outlined,
                    texto: '${receta.usuariosRequeridos} operario(s)',
                    // El único dato de esta tarjeta que puede llevar a un
                    // error real: si arrancás solo una receta pensada para
                    // varios, te quedás a mitad de camino sin poder seguir.
                    alerta: necesitaAyuda,
                  ),
                ],
              ),
              if (necesitaAyuda) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppColors.alertTx),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Esta receta necesita ${receta.usuariosRequeridos} operarios — consegí ayuda antes de arrancar.',
                        style: const TextStyle(fontSize: 12, color: AppColors.alertTx, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SeccionLabel(icono: Icons.inventory_2_outlined, texto: 'VAS A NECESITAR'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < receta.consumo.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                _FilaInsumo(
                  nombre: receta.consumo[i].productoNombre,
                  cantidad: '${_fmtQty(receta.consumo[i].cantidadPorReferencia)} ${receta.consumo[i].unidadSimbolo}',
                  destacado: receta.consumo[i].esReferencia,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SeccionLabel(icono: Icons.edit_note_outlined, texto: 'CANTIDAD A PRODUCIR'),
        const SizedBox(height: 10),
        // Esta es la única tarjeta con borde de acento de toda la pantalla:
        // es el único valor que el operario escribe a mano y del que se
        // escala TODO lo demás (consumo, resultado, mermas) — si acá hay un
        // error, se propaga a la orden entera.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent, width: 1.6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Cuánto vas a usar de ${referencia.productoNombre}?',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.text),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _cantidadController,
                onChanged: _onCantidadChanged,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.accentDark),
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: referencia.unidadSimbolo,
                  suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.bolt, size: 13, color: AppColors.accent),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Revisala bien: de acá se recalcula todo lo que sigue.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_cargandoPreview)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Calculando estimado...', style: TextStyle(color: AppColors.muted)),
              ],
            ),
          )
        else if (_errorPreview != null)
          _ErrorBanner(_errorPreview!)
        else if (_preview != null)
          _PreviewCartel(receta: receta, preview: _preview!),
        if (_errorEmpezar != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(_errorEmpezar!),
        ],
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: (_preview != null && !_empezando) ? _empezarAProducir : null,
          icon: _empezando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow),
          label: Text(_empezando ? 'Empezando...' : 'Empezar a producir'),
        ),
      ],
    );
  }
}

/// Pastilla plana (fondo `soft`/texto `muted`, mismo peso visual que las
/// tarjetas del Home) — con `alerta: true` pasa a naranja para señalar el
/// único dato de esta tarjeta que puede derivar en un error real (arrancar
/// solo una receta que necesita ayuda).
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icono, required this.texto, this.alerta = false});

  final IconData icono;
  final String texto;
  final bool alerta;

  @override
  Widget build(BuildContext context) {
    final bg = alerta ? AppColors.alertBg : AppColors.soft;
    final fg = alerta ? AppColors.alertTx : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Banner de error consistente con el resto de la app (`erBg`/`erTx` +
/// ícono), en vez de texto suelto — un error acá (ej. stock insuficiente al
/// confirmar) es justo el tipo de cosa que no debería pasar desapercibida.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.mensaje);

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.erBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.erTx),
          const SizedBox(width: 8),
          Expanded(child: Text(mensaje, style: const TextStyle(color: AppColors.erTx, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _FilaInsumo extends StatelessWidget {
  const _FilaInsumo({required this.nombre, required this.cantidad, this.destacado = false});

  final String nombre;
  final String cantidad;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (destacado) ...[
            const Icon(Icons.star, size: 15, color: AppColors.accent),
            const SizedBox(width: 8),
          ] else ...[
            const Icon(Icons.circle, size: 6, color: AppColors.faint),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(nombre, style: const TextStyle(fontSize: 14, color: AppColors.text, fontWeight: FontWeight.w600)),
          ),
          Text(cantidad, style: const TextStyle(fontSize: 14, color: AppColors.sub, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Estimado en vivo — resultado y merma esperados combinados por posición
/// con la receta (mismo orden que devuelve el backend en ambas consultas).
class _PreviewCartel extends StatelessWidget {
  const _PreviewCartel({required this.receta, required this.preview});

  final RecetaDetalle receta;
  final OrdenPreview preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A2563EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AppColors.accentDark),
              const SizedBox(width: 6),
              const Text('El sistema estima', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accentDark, fontSize: 12.5)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _EstimadoTile(label: 'Tiempo', valor: _fmtDuracion(preview.tiempoEstimadoSegundos)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _EstimadoTile(label: 'Operarios', valor: '${preview.usuariosRequeridos}'),
              ),
            ],
          ),
          if (receta.resultado.length == preview.resultado.length)
            for (var i = 0; i < receta.resultado.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _EstimadoTile(
                  label: receta.resultado[i].productoNombre,
                  valor: '${_fmtQty(preview.resultado[i].cantidadPlanificada)} ${receta.resultado[i].unidadSimbolo}',
                  ancho: double.infinity,
                ),
              ),
          if (receta.mermas.length == preview.mermas.length && receta.mermas.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0x22000000)),
            const SizedBox(height: 10),
            // Merma = producto que se pierde en esta producción — se separa
            // visualmente en tono de advertencia (mismo `waBg`/`waTx` que
            // usa el resto de la app para avisos suaves) para que no se lea
            // como "otro resultado más" al pasar la vista rápido.
            Row(
              children: [
                const Icon(Icons.local_fire_department_outlined, size: 13, color: AppColors.waTx),
                const SizedBox(width: 5),
                Text('MERMA ESPERADA', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.waTx.withValues(alpha: 0.85))),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < receta.mermas.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(receta.mermas[i].productoNombre, style: const TextStyle(fontSize: 12.5, color: AppColors.sub))),
                    Text(
                      '${_fmtQty(preview.mermas[i].cantidadPlanificada)} ${receta.mermas[i].unidadSimbolo}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.waTx, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EstimadoTile extends StatelessWidget {
  const _EstimadoTile({required this.label, required this.valor, this.ancho});

  final String label;
  final String valor;
  final double? ancho;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 15, color: AppColors.text, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
