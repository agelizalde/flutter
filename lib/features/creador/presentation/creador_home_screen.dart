import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../auth/application/auth_controller.dart';
import 'tabs/codigos_barra_tab.dart';
import 'tabs/marcas_tab.dart';
import 'tabs/productos_tab.dart';
import 'tabs/proveedores_tab.dart';
import 'tabs/ubicaciones_tab.dart';
import 'tabs/zonas_tab.dart';

class _Catalogo {
  const _Catalogo(this.titulo, this.permisoBase, this.builder);

  final String titulo;

  /// `modulo` de los permisos `modulo.ver`/`modulo.crear`/`modulo.editar`
  /// de este catálogo (ver tab "App" del rol en el ERP web).
  final String permisoBase;
  final Widget Function(bool puedeCrear, bool puedeEditar) builder;
}

/// "Creador": acceso rápido para dar de alta y editar los catálogos base
/// del ERP desde el depósito (Proveedores, Marcas, Productos, Zonas y
/// Ubicaciones), sin tener que ir al ERP web. Cada pestaña se arma según
/// permiso — si el usuario no tiene `.ver` de un catálogo, esa pestaña ni
/// aparece (mismo criterio que el resto de la app, ver `HomeScreen`).
class CreadorHomeScreen extends ConsumerWidget {
  const CreadorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authControllerProvider).value;

    final catalogos = <_Catalogo>[
      _Catalogo(
        'Proveedores',
        'compras_proveedores',
        (crear, editar) =>
            ProveedoresTab(puedeCrear: crear, puedeEditar: editar),
      ),
      _Catalogo(
        'Marcas',
        'productos_marcas',
        (crear, editar) => MarcasTab(puedeCrear: crear, puedeEditar: editar),
      ),
      _Catalogo(
        'Productos',
        'productos',
        (crear, editar) => ProductosTab(puedeCrear: crear, puedeEditar: editar),
      ),
      _Catalogo(
        // Gatea con los mismos permisos `productos.*` — el backend de
        // códigos de barra (`producto_codigo_barra_rout.py`) reusa
        // `productos.ver`/`productos.editar`, no tiene permiso propio.
        'Código de barra',
        'productos',
        (crear, editar) =>
            CodigosBarraTab(puedeCrear: crear, puedeEditar: editar),
      ),
      _Catalogo(
        'Zonas',
        'ubicacionzona',
        (crear, editar) => ZonasTab(puedeCrear: crear, puedeEditar: editar),
      ),
      _Catalogo(
        'Ubicaciones',
        'ubicacion',
        (crear, editar) =>
            UbicacionesTab(puedeCrear: crear, puedeEditar: editar),
      ),
    ];

    final visibles = catalogos
        .where((c) => usuario?.tienePermiso('${c.permisoBase}.ver') ?? false)
        .toList();

    if (visibles.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Creador'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No tenés permiso para ver ninguno de los catálogos de este módulo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: visibles.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Creador'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [for (final c in visibles) Tab(text: c.titulo)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final c in visibles)
              c.builder(
                usuario?.tienePermiso('${c.permisoBase}.crear') ?? false,
                usuario?.tienePermiso('${c.permisoBase}.editar') ?? false,
              ),
          ],
        ),
      ),
    );
  }
}
