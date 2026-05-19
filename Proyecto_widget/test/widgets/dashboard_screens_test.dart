import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_widget/providers/dashboard_provider.dart';
import 'package:proyecto_widget/models/biomarker.dart';
import 'package:proyecto_widget/screens/dashboard_screen.dart';
import 'package:proyecto_widget/screens/movimiento_screen.dart';
import 'package:proyecto_widget/screens/cardiaco_screen.dart';
import 'package:proyecto_widget/screens/estres_screen.dart';
import 'package:proyecto_widget/screens/sueno_screen.dart';

// Definición del Mock robusto sobreescribiendo getters de carga y rangos temporales
class MockDashboardProvider extends DashboardProvider {
  @override
  List<Biomarker> get metrics => [
    Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'pulse_rate', value: 75.0, qualityFlag: 'ok'),
  ];
  
  @override
  List<Biomarker> get movimientoMetrics => [
    Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'step_count', value: 120.0, qualityFlag: 'ok'),
    Biomarker(time: DateTime(2026, 5, 18, 12, 1), sensorType: 'met', value: 1.5, qualityFlag: 'ok'),
  ];
  
  @override
  List<Biomarker> get cardiacoMetrics => [
    Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'pulse_rate', value: 72.0, qualityFlag: 'ok'),
    Biomarker(time: DateTime(2026, 5, 18, 12, 1), sensorType: 'respiratory_rate', value: 16.0, qualityFlag: 'ok'),
  ];

  @override
  List<Biomarker> get estresMetrics => [
    Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'eda', value: 1.2, qualityFlag: 'ok'),
    Biomarker(time: DateTime(2026, 5, 18, 12, 1), sensorType: 'temperature', value: 36.5, qualityFlag: 'ok'),
  ];

  @override
  List<Biomarker> get suenoMetrics => [
    Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'sleep_detection', value: 1.0, qualityFlag: 'ok'),
    Biomarker(time: DateTime(2026, 5, 18, 12, 1), sensorType: 'body_position', value: 2.0, qualityFlag: 'ok'),
  ];

  @override
  bool get isEstresLoading => false;
  @override
  bool get isSuenoLoading => false;
  @override
  bool get isCardiacoLoading => false;
  @override
  bool get isMovimientoLoading => false;

  @override
  DateTime? get estresStart => DateTime(2026, 5, 18, 0, 0);
  @override
  DateTime? get estresEnd => DateTime(2026, 5, 18, 23, 59);

  @override
  DateTime? get suenoStart => DateTime(2026, 5, 18, 0, 0);
  @override
  DateTime? get suenoEnd => DateTime(2026, 5, 18, 23, 59);

  @override
  DateTime? get cardiacoStart => DateTime(2026, 5, 18, 0, 0);
  @override
  DateTime? get cardiacoEnd => DateTime(2026, 5, 18, 23, 59);

  @override
  DateTime? get movimientoStart => DateTime(2026, 5, 18, 0, 0);
  @override
  DateTime? get movimientoEnd => DateTime(2026, 5, 18, 23, 59);
  
  @override
  double? get compliancePercentage => 85.0;
  
  @override
  String get lastActivity => 'STILL';
  
  @override
  String get lastPosition => 'SIT/LIE';
  
  @override
  int? get totalSteps => 3400;
  
  @override
  double? get sleepHours => 7.5;
  
  @override
  double? get avgStress => 0.25;
  
  @override
  int? get avgBpm => 72;

  @override
  Future<void> fetchMetrics(String participantId, String username) async {}
  @override
  Future<void> fetchMovimientoMetrics(String participantId, String username) async {}
  @override
  Future<void> fetchCardiacoMetrics(String participantId, String username) async {}
  @override
  Future<void> fetchEstresMetrics(String participantId, String username) async {}
  @override
  Future<void> fetchSuenoMetrics(String participantId, String username) async {}
}

void main() {
  Widget buildTestableWidget(Widget screen) {
    return ChangeNotifierProvider<DashboardProvider>(
      create: (_) => MockDashboardProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: screen,
        ),
      ),
    );
  }

  group('Pruebas de Interfaz - Pantallas del Dashboard Clínico', () {
    testWidgets('1. Resumen General (DashboardScreen) renderiza KPIs y Gráfico de Uso', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(
        const DashboardScreen(participantId: 'HN', username: 'alberto'),
      ));
      await tester.pumpAndSettle();

      // Verificar que los KPIs principales del resumen se rendericen en pantalla
      expect(find.text('85.00%'), findsOneWidget); // Tasa de uso
      expect(find.text('TASA DE USO'), findsOneWidget);
      expect(find.text('Pasos Totales'), findsOneWidget);
      expect(find.text('3400'), findsOneWidget);
      expect(find.text('FC Media Global'), findsOneWidget);
      expect(find.text('72 BPM'), findsOneWidget);
      expect(find.text('Horas de Sueño'), findsOneWidget);
      expect(find.text('7.5h'), findsOneWidget);
    });

    testWidgets('2. Pantalla de Movimiento renderiza métricas inerciales y de actividad', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(
        const MovimientoScreen(participantId: 'HN', username: 'alberto'),
      ));
      await tester.pumpAndSettle();

      // Verificar título académico y KPIs de la pantalla de Movimiento
      expect(find.textContaining('Análisis de la Dinámica del Movimiento'), findsOneWidget);
      expect(find.text('Pasos Totales'), findsOneWidget);
      expect(find.text('Intensidad Media'), findsOneWidget);
    });

    testWidgets('3. Pantalla de Cardiaco renderiza FC, variabilidad (PRV) y respiración', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(
        const CardiacoScreen(participantId: 'HN', username: 'alberto'),
      ));
      await tester.pumpAndSettle();

      // Verificar título académico y KPIs cardíacos
      expect(find.textContaining('Monitorización Cardiopulmonar'), findsOneWidget);
      expect(find.text('Frecuencia Cardíaca (HR)'), findsOneWidget);
      expect(find.text('Frecuencia Ventilatoria (RR)'), findsOneWidget);
      expect(find.text('Índice de Acoplamiento'), findsOneWidget);
    });

    testWidgets('4. Pantalla de Estrés renderiza EDA y Temperatura cutánea', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(
        const EstresScreen(participantId: 'HN', username: 'alberto'),
      ));
      await tester.pumpAndSettle();

      // Verificar título académico y KPIs de estrés
      expect(find.textContaining('Balance y Reactividad Autonómica'), findsOneWidget);
      expect(find.text('Nivel de Estrés (EDA)'), findsOneWidget);
      expect(find.text('Capacidad de Recuperación'), findsOneWidget);
      expect(find.text('Estabilidad Térmica'), findsOneWidget);
    });

    testWidgets('5. Pantalla de Sueño renderiza hipnograma y posturas', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestableWidget(
        const SuenoScreen(participantId: 'HN', username: 'alberto'),
      ));
      await tester.pumpAndSettle();

      // Verificar título académico y KPIs de sueño
      expect(find.textContaining('Análisis de Arquitectura del Sueño y Ergonomía'), findsOneWidget);
      expect(find.text('Eficiencia del Sueño'), findsOneWidget);
      expect(find.text('Tiempo Total (TST)'), findsOneWidget);
    });
  });
}
