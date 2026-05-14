import 'package:flutter/material.dart';
import '../models/biomarker.dart';
import '../services/api_service.dart';

const List<String> kMovimientoSensores = [
  'activity_class',
  'activity_intensity',
  'acticounts_total',
  'actigraphy_vector',
  'accelerometer_std',
  'step_count',
  'wearing_detection',
  'acticounts_x',
  'acticounts_y',
  'acticounts_z',
];

const List<int> kHourOptions = [1, 3, 6, 12, 24];

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Biomarker> _metrics = [];
  List<Biomarker> _movimientoMetrics = [];
  bool _isLoading = false;
  bool _isMovimientoLoading = false;
  String? _error;

  DateTime? _movimientoStart;
  DateTime? _movimientoEnd;
  DateTime? _dataRangeStart;
  DateTime? _dataRangeEnd;
  int _selectedHours = 24;

  List<Biomarker> get metrics           => _metrics;
  List<Biomarker> get movimientoMetrics => _movimientoMetrics;
  bool get isLoading                    => _isLoading;
  bool get isMovimientoLoading          => _isMovimientoLoading;
  String? get error                     => _error;
  DateTime? get movimientoStart         => _movimientoStart;
  DateTime? get movimientoEnd           => _movimientoEnd;
  DateTime? get dataRangeStart          => _dataRangeStart;
  DateTime? get dataRangeEnd            => _dataRangeEnd;
  int get selectedHours                 => _selectedHours;

  static String _bucketForHours(int hours) {
    if (hours <= 1)  return '30 seconds';
    if (hours <= 3)  return '1 minute';
    if (hours <= 6)  return '2 minutes';
    if (hours <= 12) return '5 minutes';
    return '1 minute';
  }


  String get movimientoResolucion {
    if (_movimientoStart == null || _movimientoEnd == null) return '';
    final bucket = _bucketForHours(_selectedHours);
    return bucket.replaceAll(' seconds', ' seg').replaceAll(' minutes', ' min');
  }

  void _applyHourFilter() {
    if (_dataRangeEnd == null || _dataRangeStart == null) return;
    final end = _dataRangeEnd!;
    final start = end.subtract(Duration(hours: _selectedHours));
    _movimientoEnd   = end;
    _movimientoStart = start.isBefore(_dataRangeStart!) ? _dataRangeStart! : start;
  }

  Future<void> fetchMetrics(String participantId, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final metadata = await _apiService.getParticipantMetadata(participantId, username);

      if (metadata['start_time'] != null) {
        _dataRangeStart = DateTime.parse(metadata['start_time']);
        _dataRangeEnd   = DateTime.parse(metadata['end_time']);
        _applyHourFilter();
      }

      _metrics = await _apiService.getMetrics(participantId, username);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMovimientoMetrics(String participantId, String username) async {
    if (_movimientoStart == null || _movimientoEnd == null) return;
    _isMovimientoLoading = true;
    notifyListeners();
    try {
      final bucket = _bucketForHours(_selectedHours);
      final all = await _apiService.getMetrics(
        participantId,
        username,
        startTime: _movimientoStart!.toUtc().toIso8601String(),
        endTime:   _movimientoEnd!.toUtc().toIso8601String(),
        bucketSize: bucket,
      );
      _movimientoMetrics = all.where((m) => kMovimientoSensores.contains(m.sensorType)).toList();
    } catch (_) {
      _movimientoMetrics = [];
    } finally {
      _isMovimientoLoading = false;
      notifyListeners();
    }
  }

  Future<void> setHourFilter(int hours, String participantId, String username) async {
    _selectedHours = hours;
    _applyHourFilter();
    await fetchMovimientoMetrics(participantId, username);
  }

  Future<void> setMovimientoRango(
    DateTime start,
    DateTime end,
    String participantId,
    String username,
  ) async {
    _movimientoStart = start;
    _movimientoEnd   = end;
    _selectedHours   = _durationToNearestHours(end.difference(start));
    await fetchMovimientoMetrics(participantId, username);
  }

  static int _durationToNearestHours(Duration d) {
    final h = d.inHours;
    if (h <= 1)  return 1;
    if (h <= 3)  return 3;
    if (h <= 6)  return 6;
    if (h <= 12) return 12;
    return 24;
  }

  Map<String, List<Biomarker>> get metricsBySensor {
    final Map<String, List<Biomarker>> map = {};
    for (var m in _metrics) {
      map.putIfAbsent(m.sensorType, () => []).add(m);
    }
    return map;
  }

  int? get totalSteps {
    final steps = _metrics.where((m) => m.sensorType == 'step_count' && m.value != null);
    if (steps.isEmpty) return null;
    return steps.fold<double>(0.0, (sum, m) => sum + m.value!).toInt();
  }

  int? get avgBpm {
    final bpm = _metrics.where((m) => m.sensorType == 'pulse_rate' && m.value != null);
    if (bpm.isEmpty) return null;
    return (bpm.fold<double>(0.0, (sum, m) => sum + m.value!) / bpm.length).toInt();
  }

  double? get totalMets {
    final mets = _metrics.where((m) => m.sensorType == 'met' && m.value != null);
    if (mets.isEmpty) return null;
    return mets.fold<double>(0.0, (sum, m) => sum + m.value!);
  }

  double? get avgTemp {
    final temp = _metrics.where((m) => m.sensorType == 'temperature' && m.value != null);
    if (temp.isEmpty) return null;
    return temp.fold<double>(0.0, (sum, m) => sum + m.value!) / temp.length;
  }

  double? get compliancePercentage {
    final wearing = _metrics.where((m) => m.sensorType == 'wearing_detection');
    if (wearing.isEmpty) return null;
    int valid = 0;
    for (var m in wearing) {
      if (m.qualityFlag != 'device_not_worn_correctly' && m.qualityFlag != 'device_not_recording') {
        valid++;
      }
    }
    return (valid / wearing.length) * 100;
  }

  double? get sleepHours {
    final sleep = _metrics.where((m) => m.sensorType == 'sleep_detection' && m.value != null);
    if (sleep.isEmpty) return null;
    final sleepPoints = sleep.where((m) => m.value! > 0).length;
    return (sleepPoints * 30) / 3600;
  }

  double? get avgStress {
    final eda = _metrics.where((m) => m.sensorType == 'eda' && m.value != null);
    if (eda.isEmpty) return null;
    return eda.fold<double>(0.0, (sum, m) => sum + m.value!) / eda.length;
  }

  String get lastActivity {
    final act = _metrics.where((m) {
      final type = m.sensorType.toLowerCase().replaceAll('-', '_');
      return (type == 'activity_class' || type == 'activity_classification') && m.value != null;
    }).toList();
    if (act.isEmpty) return 'Desconocido';
    switch (act.last.value!.toInt()) {
      case 0: return 'Sedentario';
      case 1: return 'Caminando';
      case 2: return 'Corriendo';
      case 3: return 'Actividad Genérica';
      default: return 'Desconocido';
    }
  }

  String get lastPosition {
    final pos = _metrics.where((m) {
      final type = m.sensorType.toLowerCase().replaceAll('-', '_');
      return (type == 'body_position' || type == 'body_position_left') && m.value != null;
    }).toList();
    if (pos.isEmpty) return 'Desconocido';
    switch (pos.last.value!.toInt()) {
      case 0: return 'Sentado / Reclinado';
      case 1: return 'De pie';
      case 2: return 'Lateral Izquierdo';
      case 3: return 'Lateral Derecho';
      case 4: return 'Prono (Boca abajo)';
      case 5: return 'Supino (Boca arriba)';
      default: return 'Desconocido';
    }
  }
}
