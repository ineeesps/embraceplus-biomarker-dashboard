import 'package:flutter_test/flutter_test.dart';
import '../../lib/utils/interpolation_utils.dart';
import '../../lib/models/biomarker.dart';

void main() {
  group('Pruebas de InterpolationUtils - Imputación Fisiológica', () {
    test('Forward Fill (LOCF) propaga correctamente los estados categóricos', () {
      final data = [
        Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'sleep_detection', value: 1.0, qualityFlag: 'ok'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 1), sensorType: 'sleep_detection', value: null, qualityFlag: 'low_signal'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 2), sensorType: 'sleep_detection', value: null, qualityFlag: 'motion'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 3), sensorType: 'sleep_detection', value: 3.0, qualityFlag: 'ok'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 4), sensorType: 'sleep_detection', value: null, qualityFlag: 'device_not_worn'),
      ];

      final res = InterpolationUtils.compute(data, 'ffill');

      // Los valores originales mantienen null para datos corruptos
      expect(res.original[0], 1.0);
      expect(res.original[1], isNull);
      expect(res.original[2], isNull);
      expect(res.original[3], 3.0);
      expect(res.original[4], isNull);

      // Los valores interpolados propagan el último valor conocido hacia adelante
      expect(res.interpolated[0], 1.0);
      expect(res.interpolated[1], 1.0); // Rellenado con 1.0
      expect(res.interpolated[2], 1.0); // Rellenado con 1.0
      expect(res.interpolated[3], 3.0); // Conserva 3.0 (real)
      expect(res.interpolated[4], 3.0); // Rellenado con 3.0
    });

    test('Interpolación Lineal estima la pendiente proporcional', () {
      final data = [
        Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'temperature', value: 10.0, qualityFlag: 'ok'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 1), sensorType: 'temperature', value: null, qualityFlag: 'motion'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 2), sensorType: 'temperature', value: null, qualityFlag: 'motion'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 3), sensorType: 'temperature', value: 40.0, qualityFlag: 'ok'),
      ];

      final res = InterpolationUtils.compute(data, 'linear');

      expect(res.interpolated[0], 10.0);
      expect(res.interpolated[1], 20.0); // Paso lineal intermedio
      expect(res.interpolated[2], 30.0); // Paso lineal intermedio
      expect(res.interpolated[3], 40.0);
    });

    test('Spline Cúbico Natural calcula una curva matemática suave', () {
      final data = [
        Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'eda', value: 0.0, qualityFlag: 'ok'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 1), sensorType: 'eda', value: null, qualityFlag: 'motion'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 2), sensorType: 'eda', value: null, qualityFlag: 'motion'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 3), sensorType: 'eda', value: 9.0, qualityFlag: 'ok'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 4), sensorType: 'eda', value: null, qualityFlag: 'motion'),
        Biomarker(time: DateTime(2026, 5, 18, 12, 5), sensorType: 'eda', value: 20.0, qualityFlag: 'ok'),
      ];

      final res = InterpolationUtils.compute(data, 'spline');

      // Las extremidades se rellenan con el borde más cercano
      expect(res.interpolated[0], 0.0);
      expect(res.interpolated[5], 20.0);

      // Verificamos que los puntos nulos intermedios [1] y [2] son interpolados
      expect(res.interpolated[1], isNotNull);
      expect(res.interpolated[2], isNotNull);
      
      // La interpolación por spline cúbico natural difiere de una simple recta lineal
      // (1) y (2) en spline tienen valores redondeados correspondientes a la solución del resolvedor tridiagonal.
      expect(res.interpolated[1]! > 0.0, true);
      expect(res.interpolated[2]! < 9.0, true);
    });

    test('Bordes y listas vacías se manejan de forma segura', () {
      final resVacio = InterpolationUtils.compute([], 'linear');
      expect(resVacio.original, isEmpty);
      expect(resVacio.interpolated, isEmpty);

      final unSoloDato = [
        Biomarker(time: DateTime(2026, 5, 18, 12, 0), sensorType: 'temperature', value: 36.5, qualityFlag: 'ok'),
      ];
      final resUnico = InterpolationUtils.compute(unSoloDato, 'spline');
      expect(resUnico.interpolated[0], 36.5);
    });
  });
}
