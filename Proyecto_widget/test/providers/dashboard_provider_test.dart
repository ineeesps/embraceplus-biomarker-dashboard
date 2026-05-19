import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_widget/providers/dashboard_provider.dart';

void main() {
  group('Pruebas de DashboardProvider - Gestión de Estado', () {
    test('Estado inicial se inicializa con los valores por defecto correctos', () {
      final provider = DashboardProvider();

      // Las horas iniciales por defecto son 24 horas para todas las pantallas
      expect(provider.selectedHours, 24);
      expect(provider.selectedCardiacoHours, 24);
      expect(provider.selectedEstresHours, 24);
      expect(provider.selectedSuenoHours, 24);

      // Los estados de carga iniciales deben ser falsos
      expect(provider.isLoading, false);
      expect(provider.isMovimientoLoading, false);
      expect(provider.isCardiacoLoading, false);
      expect(provider.isEstresLoading, false);
      expect(provider.isSuenoLoading, false);

      // Las métricas iniciales deben estar vacías
      expect(provider.movimientoMetrics, isEmpty);
      expect(provider.cardiacoMetrics, isEmpty);
      expect(provider.estresMetrics, isEmpty);
      expect(provider.suenoMetrics, isEmpty);
    });

    test('Las resoluciones adaptativas están vacías por defecto si no hay rango cargado', () {
      final provider = DashboardProvider();

      // Cuando no hay datos cargados, las resoluciones deben reportarse vacías
      expect(provider.movimientoResolucion, '');
      expect(provider.cardiacoResolucion, '');
      expect(provider.estresResolucion, '');
      expect(provider.suenoResolucion, '');
    });
  });
}
