import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wherehouse/app/app.dart';
import 'package:wherehouse/core/auth/usuario_actual.dart';
import 'package:wherehouse/features/auth/application/auth_controller.dart';

/// No depende de `flutter_secure_storage` real (no hay plugin registrado en
/// el entorno de test) — resuelve "sin sesión" de inmediato.
class _FakeAuthController extends AuthController {
  @override
  Future<UsuarioActual?> build() async => null;
}

void main() {
  testWidgets('Muestra la pantalla de login cuando no hay sesión', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_FakeAuthController.new)],
        child: const WherehouseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wherehouse'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
