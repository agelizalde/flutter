import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../errors/app_exception.dart';

/// Chrome común de los formularios de alta rápida en bottom sheet — nació
/// con los 5 formularios del módulo Creador y hoy también lo usa Pedidos
/// (`NuevoPedidoSheet`): header con título + cerrar, cuerpo scrolleable con
/// los campos propios de cada entidad, y footer con Cancelar/Guardar.
/// Centraliza el estado de "guardando" / error de servidor para no
/// repetirlo en cada formulario.
Future<bool?> showFormSheet(
  BuildContext context, {
  required String titulo,
  required List<Widget> Function(BuildContext context, StateSetter setState)
  camposBuilder,
  required Future<void> Function() onGuardar,
  String textoGuardar = 'Guardar',
  // Alto inicial/mín/máx del sheet como fracción de pantalla — los 5
  // formularios de Creador entran cómodos con el default, pero uno con más
  // campos (ej. `NuevoPedidoSheet`) puede pedir arrancar más alto para que
  // no haga falta arrastrar ni scrollear para ver todo.
  double initialChildSize = 0.6,
  double minChildSize = 0.35,
  double maxChildSize = 0.95,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FormSheetBody(
      titulo: titulo,
      camposBuilder: camposBuilder,
      onGuardar: onGuardar,
      textoGuardar: textoGuardar,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
    ),
  );
}

class _FormSheetBody extends StatefulWidget {
  const _FormSheetBody({
    required this.titulo,
    required this.camposBuilder,
    required this.onGuardar,
    required this.textoGuardar,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
  });

  final String titulo;
  final List<Widget> Function(BuildContext context, StateSetter setState)
  camposBuilder;
  final Future<void> Function() onGuardar;
  final String textoGuardar;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;

  @override
  State<_FormSheetBody> createState() => _FormSheetBodyState();
}

class _FormSheetBodyState extends State<_FormSheetBody> {
  bool _guardando = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await widget.onGuardar();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e);
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: widget.initialChildSize,
        minChildSize: widget.minChildSize,
        maxChildSize: widget.maxChildSize,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.titulo,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _guardando
                            ? null
                            : () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.erBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.erTx,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setStateSheet) => ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      children: widget.camposBuilder(context, setStateSheet),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: ElevatedButton(
                    onPressed: _guardando ? null : _submit,
                    child: _guardando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(widget.textoGuardar),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
