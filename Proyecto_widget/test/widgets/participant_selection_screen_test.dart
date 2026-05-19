import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_widget/screens/participant_selection_screen.dart';
import 'package:lucide_icons/lucide_icons.dart';

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

    testWidgets('3. Validación de KPIs, cambio de vista (Tabla/Cuadrícula), subida de participante y diálogo de cierre de sesión', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockParticipants = [
        ParticipantData(
          id: 'HN-TEST',
          compliance: 90.0,
          status: 'ÓPTIMO',
          dateRange: '15 May - 16 May',
          totalHours: 48,
        ),
        ParticipantData(
          id: 'HN-CRIT',
          compliance: 50.0,
          status: 'CRÍTICO',
          dateRange: '15 May - 16 May',
          totalHours: 48,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ParticipantSelectionScreen(
            username: 'alberto',
            assignedParticipants: const ['HN-TEST', 'HN-CRIT'],
            preloadedData: mockParticipants,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verificar KPIs
      expect(find.text('Total Participantes'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      expect(find.text('Tasa de Uso Media'), findsOneWidget);
      expect(find.text('70.00%'), findsOneWidget);

      expect(find.text('Alertas Activas'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // 2. Verificar cambio de vista (Grid a Tabla)
      final tableIconButton = find.byIcon(Icons.table_rows_rounded);
      expect(tableIconButton, findsOneWidget);
      await tester.tap(tableIconButton);
      await tester.pumpAndSettle();

      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('ID Participante'), findsOneWidget);
      expect(find.text('HN-TEST'), findsOneWidget);
      expect(find.text('HN-CRIT'), findsOneWidget);

      final gridIconButton = find.byIcon(Icons.grid_view_rounded);
      expect(gridIconButton, findsOneWidget);
      await tester.tap(gridIconButton);
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);

      // 3. Abrir modal de subida de participante
      final uploadButton = find.byIcon(LucideIcons.uploadCloud).first;
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      expect(find.text('Subir Nuevos Datos'), findsOneWidget);
      expect(find.text('ID del Participante:'), findsOneWidget);
      
      final cancelUploadButton = find.text('Cancelar');
      expect(cancelUploadButton, findsOneWidget);
      await tester.tap(cancelUploadButton);
      await tester.pumpAndSettle();
      expect(find.text('Subir Nuevos Datos'), findsNothing);

      // 4. Diálogo de cierre de sesión
      final logoutButton = find.byIcon(LucideIcons.logOut).first;
      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      expect(find.text('Cerrar Sesión'), findsNWidgets(2));
      expect(find.text('¿Estás seguro de que deseas cerrar la sesión? Volverás a la pantalla de inicio.'), findsOneWidget);
      
      final cancelLogoutButton = find.text('Cancelar');
      expect(cancelLogoutButton, findsOneWidget);
      await tester.tap(cancelLogoutButton);
      await tester.pumpAndSettle();
      expect(find.text('¿Estás seguro de que deseas cerrar la sesión? Volverás a la pantalla de inicio.'), findsNothing);
    });
  });
}
