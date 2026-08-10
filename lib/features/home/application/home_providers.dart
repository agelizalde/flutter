import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../ajuste_stock_solicitudes/application/ajuste_stock_solicitudes_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../picking_operario/application/picking_providers.dart';
import '../../recepcion/application/recepcion_providers.dart';
import '../../recepcion/domain/recepcion_models.dart';

/// Tarjeta de "Pendientes para vos" (Home y tab Tareas) — un ítem por cada
/// fuente de pendientes que ya existe en otro módulo, sin backend nuevo.
class TareaPendiente {
  const TareaPendiente({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.colorPrioridad,
    required this.ruta,
  });

  final IconData icono;
  final String titulo;
  final String descripcion;
  final Color colorPrioridad;
  final String ruta;
}

/// Recepciones del almacén base del usuario en estado `PEND_CONTROL` — solo
/// para contar cuántas hay, mismo criterio de "todo el almacén, no solo lo
/// que recibió el usuario" que ya usa `recepcionListadoProvider` para la
/// pantalla "Pendientes de control".
final _recepcionesPendControlHomeProvider = FutureProvider.autoDispose<List<Recepcion>>((ref) async {
  final usuario = await ref.watch(authControllerProvider.future);
  if (usuario == null) return const [];
  return ref.watch(recepcionRepositoryProvider).listarRecepciones(
        estado: 'PEND_CONTROL',
        idAlmacen: usuario.idAlmacenSeleccionado,
        limit: 5,
      );
});

/// Agregador de "Pendientes para vos": combina 4 fuentes que ya se piden en
/// otras pantallas (control de stock solicitado, recepciones para
/// controlar, devoluciones de picking, subpedidos de picking sin terminar)
/// en una sola lista ordenada por prioridad — sin pedir nada nuevo al
/// backend. Cada fuente aporta como máximo 1 tarjeta (resumida, "hay N"),
/// no una tarjeta por fila individual.
final pendientesHomeProvider = Provider<List<TareaPendiente>>((ref) {
  final tareas = <TareaPendiente>[];

  final despickeo = ref.watch(tareasDespickeoProvider).value ?? const [];
  if (despickeo.isNotEmpty) {
    tareas.add(
      TareaPendiente(
        icono: Icons.undo_outlined,
        titulo: 'Devolución pendiente',
        descripcion: despickeo.length == 1
            ? '1 producto para reacomodar'
            : '${despickeo.length} productos para reacomodar',
        colorPrioridad: AppColors.prioridadUrgente,
        ruta: '/picking-operario/quitar-productos',
      ),
    );
  }

  final solicitudes = ref.watch(misSolicitudesPendientesProvider).value ?? const [];
  if (solicitudes.isNotEmpty) {
    tareas.add(
      TareaPendiente(
        icono: Icons.fact_check_outlined,
        titulo: 'Control de stock solicitado',
        descripcion: solicitudes.length == 1
            ? '1 ubicación para contar'
            : '${solicitudes.length} ubicaciones para contar',
        colorPrioridad: AppColors.prioridadAlta,
        ruta: '/ajuste-stock/mis-solicitudes',
      ),
    );
  }

  final recepcionesPendControl = ref.watch(_recepcionesPendControlHomeProvider).value ?? const [];
  if (recepcionesPendControl.isNotEmpty) {
    tareas.add(
      TareaPendiente(
        icono: Icons.move_to_inbox_outlined,
        titulo: 'Recepción para controlar',
        descripcion: recepcionesPendControl.length == 1
            ? '1 recepción pendiente de control'
            : '${recepcionesPendControl.length} recepciones pendientes de control',
        colorPrioridad: AppColors.prioridadMedia,
        ruta: '/recepcion/pendientes-control',
      ),
    );
  }

  final misTareas = ref.watch(misTareasProvider).value;
  final subpedidosPicking = misTareas?.subpedidos.where((sp) => sp.tienePendientes).toList() ?? const [];
  if (subpedidosPicking.isNotEmpty) {
    tareas.add(
      TareaPendiente(
        icono: Icons.shopping_basket_outlined,
        titulo: 'Picking pendiente',
        descripcion: subpedidosPicking.length == 1
            ? '1 subpedido por completar'
            : '${subpedidosPicking.length} subpedidos por completar',
        colorPrioridad: AppColors.prioridadInformativa,
        ruta: '/picking-operario',
      ),
    );
  }

  return tareas;
});
