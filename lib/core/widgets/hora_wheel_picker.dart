import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Minutos válidos para una ETA — mismo paso de 30 min que ya exigían
/// `NuevoPedidoSheet`/`ModificarEtaSheet` con el listado buscable de antes,
/// ahora como las dos posiciones de la ruedita de minutos.
const _minutosValidos = [0, 30];

/// Selector de hora tipo "reloj" (dos ruedas separadas hh : mm) pensado para
/// usarse con el pulgar en el teléfono — reemplaza al buscador de una lista
/// de 48 horarios (`showSelectorSheet<String>` sobre "00:00".."23:30") que
/// resultaba incómodo de tocar en una pantalla chica. Cada rueda es
/// infinita (`looping`) para poder ir "para arriba o para abajo" sin
/// toparse con un límite. Si no se pasa `horaInicial` arranca al mediodía
/// (12:00), un punto medio cómodo para moverse en cualquier dirección.
/// Devuelve la hora elegida como `"HH:mm"`, o `null` si se canceló.
Future<String?> showHoraWheelPicker(
  BuildContext context, {
  String? horaInicial,
}) {
  var hora = 12;
  var minutoIndex = 0;
  if (horaInicial != null) {
    final partes = horaInicial.split(':');
    hora = int.tryParse(partes.isNotEmpty ? partes[0] : '') ?? 12;
    final minuto = int.tryParse(partes.length > 1 ? partes[1] : '') ?? 0;
    // Por si llegara un minuto que no es 0/30 (no debería, pero por las
    // dudas): redondea al más cercano de los dos válidos.
    minutoIndex = minuto >= 15 ? 1 : 0;
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _HoraWheelPickerBody(horaInicial: hora, minutoIndexInicial: minutoIndex),
  );
}

class _HoraWheelPickerBody extends StatefulWidget {
  const _HoraWheelPickerBody({
    required this.horaInicial,
    required this.minutoIndexInicial,
  });

  final int horaInicial;
  final int minutoIndexInicial;

  @override
  State<_HoraWheelPickerBody> createState() => _HoraWheelPickerBodyState();
}

class _HoraWheelPickerBodyState extends State<_HoraWheelPickerBody> {
  late int _hora = widget.horaInicial;
  late int _minutoIndex = widget.minutoIndexInicial;

  /// El scroll de una rueda infinita entrega índices sin acotar (incluso
  /// negativos si se va "para arriba" más allá del arranque) — hay que
  /// volver a mapearlos al rango real con módulo, cuidando que Dart no
  /// devuelve resto negativo como en otros lenguajes.
  int _mod(int value, int size) => ((value % size) + size) % size;

  Widget _rueda({
    required int itemCount,
    required int initialItem,
    required String Function(int) etiqueta,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initialItem),
      itemExtent: 44,
      looping: true,
      onSelectedItemChanged: (i) => onChanged(_mod(i, itemCount)),
      children: List.generate(
        itemCount,
        (i) => Center(
          child: Text(
            etiqueta(i),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    const Expanded(
                      child: Text(
                        'Elegir hora',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 190,
                child: Row(
                  children: [
                    Expanded(
                      child: _rueda(
                        itemCount: 24,
                        initialItem: _hora,
                        etiqueta: (i) => i.toString().padLeft(2, '0'),
                        onChanged: (v) => setState(() => _hora = v),
                      ),
                    ),
                    const Text(
                      ':',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    Expanded(
                      child: _rueda(
                        itemCount: _minutosValidos.length,
                        initialItem: _minutoIndex,
                        etiqueta: (i) =>
                            _minutosValidos[i].toString().padLeft(2, '0'),
                        onChanged: (v) => setState(() => _minutoIndex = v),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    '${_hora.toString().padLeft(2, '0')}:'
                    '${_minutosValidos[_minutoIndex].toString().padLeft(2, '0')}',
                  ),
                  child: const Text('Elegir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
