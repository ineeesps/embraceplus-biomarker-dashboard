import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_widget/screens/participant_selection_screen.dart';

void main() {
  group('Pruebas de Interfaz - ParticipantSelectionScreen', () {
    testWidgets('Renderización de tarjetas de participante y cumplimiento', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockParticipants = [
        ParticipantData(
          id: 'HN-TEST',
          compliance: 92.5,
          status: 'NORMAL',
          dateRange: '15 May - 18 May',
          totalHours: 72,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ParticipantSelectionScreen(
            username: 'alberto',
            assignedParticipants: const ['HN-TEST'],
            preloadedData: mockParticipants,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar la tarjeta del participante de prueba y sus campos
      expect(find.text('HN-TEST'), findsOneWidget);
      expect(find.text('92.50%'), findsOneWidget);
      expect(find.text('15 May - 18 May'), findsOneWidget);
      expect(find.text('72 h de cobertura temporal'), findsOneWidget);
    });

    testWidgets('Búsqueda por ID filtra la cuadrícula correctamente', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockParticipants = [
        ParticipantData(
          id: 'HN-ALPHA',
          compliance: 88.0,
          status: 'NORMAL',
          dateRange: '15 May',
          totalHours: 24,
        ),
        ParticipantData(
          id: 'HN-BETA',
          compliance: 45.0,
          status: 'CRÍTICO',
          dateRange: '15 May',
          totalHours: 24,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ParticipantSelectionScreen(
            username: 'alberto',
            assignedParticipants: const ['HN-ALPHA', 'HN-BETA'],
            preloadedData: mockParticipants,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Inicialmente se ven ambos participantes
      expect(find.text('HN-ALPHA'), findsOneWidget);
      expect(find.text('HN-BETA'), findsOneWidget);

      // Introducir texto de búsqueda 'ALPHA'
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'ALPHA');
      await tester.pumpAndSettle();

      // Debería ver HN-ALPHA pero no HN-BETA
      expect(find.text('HN-ALPHA'), findsOneWidget);
      expect(find.text('HN-BETA'), findsNothing);
    });
  });
}
