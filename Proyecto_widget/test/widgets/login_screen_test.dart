import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/screens/login_screen.dart';

void main() {
  group('Pruebas de Interfaz - LoginScreen', () {
    testWidgets('Renderización de campos y textos principales', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verificar que el título de la plataforma y el subtítulo clínico estén visibles
      expect(find.text('EmbracePlus'), findsOneWidget);
      expect(find.text('CLINICAL RESEARCH PLATFORM'), findsOneWidget);
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.text('Acceso exclusivo para investigadores'), findsOneWidget);

      // Verificar que los TextFields de Usuario y Contraseña estén renderizados
      expect(find.widgetWithText(TextField, 'Usuario'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Contraseña'), findsOneWidget);

      // Verificar el botón de ingresar
      expect(find.widgetWithText(ElevatedButton, 'Acceder al sistema'), findsOneWidget);
    });

    testWidgets('Ingreso de credenciales actualiza los controladores', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Introducir texto en el usuario
      final usuarioField = find.widgetWithText(TextField, 'Usuario');
      await tester.enterText(usuarioField, 'alberto');
      expect(find.text('alberto'), findsOneWidget);

      // Introducir texto en la contraseña
      final contrasenaField = find.widgetWithText(TextField, 'Contraseña');
      await tester.enterText(contrasenaField, '123');
      expect(find.text('123'), findsOneWidget);
    });
  });
}
