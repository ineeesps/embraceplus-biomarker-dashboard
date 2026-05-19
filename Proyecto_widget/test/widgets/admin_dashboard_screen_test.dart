import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:proyecto_widget/screens/admin_dashboard_screen.dart';
import 'package:proyecto_widget/services/api_service.dart';

class MockApiService extends ApiService {
  int createCallCount = 0;
  int toggleCallCount = 0;
  int updateCallCount = 0;
  int deleteCallCount = 0;

  @override
  Future<List<Map<String, dynamic>>> getAdminInvestigators() async {
    return [
      {
        'id': 1,
        'username': 'admin',
        'nombre_completo': 'Administrador del Sistema',
        'role': 'admin',
        'is_active': true,
        'last_login': '2026-05-19T10:00:00Z',
        'participantes_asignados': [],
        'pacientes_count': 0,
      },
      {
        'id': 2,
        'username': 'alberto',
        'nombre_completo': 'Alberto Durán',
        'role': 'investigador',
        'is_active': true,
        'last_login': null,
        'participantes_asignados': ['HN', 'PRUEBA 1'],
        'pacientes_count': 2,
      },
      {
        'id': 3,
        'username': 'ines',
        'nombre_completo': 'Inés Pleguezuelos',
        'role': 'investigador',
        'is_active': false,
        'last_login': '2026-05-18T15:30:00Z',
        'participantes_asignados': ['user1', 'user2'],
        'pacientes_count': 2,
      },
    ];
  }

  @override
  Future<List<String>> getAdminAllParticipants() async {
    return ['HN', 'PRUEBA 1', 'user1', 'user2', 'TEST_NEW'];
  }

  @override
  Future<void> createAdminInvestigator(Map<String, dynamic> data) async {
    createCallCount++;
  }

  @override
  Future<void> toggleInvestigatorStatus(int id, bool isActive) async {
    toggleCallCount++;
  }

  @override
  Future<void> updateInvestigatorDetails(int id, String nombreCompleto, String username) async {
    updateCallCount++;
  }

  @override
  Future<void> deleteInvestigator(int id) async {
    deleteCallCount++;
  }
}

void main() {
  group('Pruebas de Interfaz - AdminDashboardScreen', () {
    late MockApiService mockApi;

    setUp(() {
      mockApi = MockApiService();
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: Scaffold(
          body: AdminDashboardScreen(
            username: 'admin',
            api: mockApi,
          ),
        ),
      );
    }

    testWidgets('1. Renderiza pestañas, estadísticas filtradas por rol e interactividad del buscador', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Directorio de Investigadores y Accesos'), findsNWidgets(2));
      expect(find.text('Admin Active'), findsOneWidget);

      final tabGeneral = find.byIcon(LucideIcons.layoutTemplate).first;
      await tester.tap(tabGeneral);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Investigadores Activos'), findsOneWidget);

      final tabInvestigadores = find.byIcon(LucideIcons.users).first;
      await tester.tap(tabInvestigadores);
      await tester.pumpAndSettle();

      expect(find.text('Alberto Durán'), findsOneWidget);
      expect(find.text('Inés Pleguezuelos'), findsOneWidget);

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Alberto');
      await tester.pumpAndSettle();

      expect(find.text('Alberto Durán'), findsOneWidget);
      expect(find.text('Inés Pleguezuelos'), findsNothing);
    });

    testWidgets('2. Diálogo Nuevo Investigador y validación de creación', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final btnNuevo = find.widgetWithText(ElevatedButton, 'Nuevo Investigador');
      await tester.tap(btnNuevo);
      await tester.pumpAndSettle();

      expect(find.text('Alta de Investigador'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Ej: Juan Pérez'), 'Nuevo Investigador Clinico');
      await tester.enterText(find.widgetWithText(TextFormField, 'Ej: juan_perez'), 'nuevo_inv');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mínimo 4 caracteres'), 'password123');

      await tester.tap(find.text('CREAR'));
      await tester.pumpAndSettle();

      expect(mockApi.createCallCount, 1);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('3. Opciones del menú de acciones: Modificar detalles del Investigador', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final popupMenuButtons = find.byType(PopupMenuButton<String>);
      expect(popupMenuButtons, findsNWidgets(3));

      await tester.tap(popupMenuButtons.at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar Datos'));
      await tester.pumpAndSettle();

      expect(find.text('Editar Investigador'), findsOneWidget);
      
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();

      expect(mockApi.updateCallCount, 1);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('4. Modificar estado (Activar/Desactivar cuenta) desde menú contextual', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final popupMenuButtons = find.byType(PopupMenuButton<String>);
      await tester.tap(popupMenuButtons.at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desactivar cuenta'));
      await tester.pumpAndSettle();

      expect(mockApi.toggleCallCount, 1);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('5. Confirmación de Cierre de Sesión muestra el diálogo y texto unificado', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final btnLogout = find.byIcon(LucideIcons.logOut).first;
      await tester.tap(btnLogout);
      await tester.pumpAndSettle();

      expect(find.text('Cerrar Sesión'), findsNWidgets(2));
      expect(find.text('¿Estás seguro de que deseas cerrar la sesión? Volverás a la pantalla de inicio.'), findsOneWidget);
    });
  });
}
