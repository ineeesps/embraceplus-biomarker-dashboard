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

const List<String> kCardiacoSensores = [
  'pulse_rate',
  'respiratory_rate',
];

const List<String> kEstresSensores = [
  'eda',
  'temperature',
  'prv',
  'met',
];

const List<String> kSuenoSensores = [
  'sleep_detection',
  'body_position',
  'activity_class',
  'pulse_rate',
];

const List<String> kSuenoExportSensores = [
  'sleep_detection',
  'body_position',
];

const List<int> kHourOptions = [1, 3, 6, 12, 24];

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  Map<String, dynamic>? _globalKpis;
  List<Biomarker> _metrics = [];
  List<Biomarker> _movimientoMetrics = [];
  List<Biomarker> _cardiacoMetrics = [];
  List<Biomarker> _estresMetrics = [];
  List<Biomarker> _suenoMetrics = [];
  bool _isLoading = false;
  bool _isMovimientoLoading = false;
  bool _isCardiacoLoading = false;
  bool _isEstresLoading = false;
  bool _isSuenoLoading = false;
  String? _error;
 
  DateTime? _movimientoStart;
  DateTime? _movimientoEnd;
  DateTime? _cardiacoStart;
  DateTime? _cardiacoEnd;
  DateTime? _estresStart;
  DateTime? _estresEnd;
  DateTime? _suenoStart;
  DateTime? _suenoEnd;
  DateTime? _dataRangeStart;
  DateTime? _dataRangeEnd;
  int _selectedHours = 24;
  int _selectedCardiacoHours = 24;
  int _selectedEstresHours = 24;
  int _selectedSuenoHours = 24;

  Map<String, dynamic>? get globalKpis          => _globalKpis;
  List<Biomarker> get metrics           => _metrics;
  List<Biomarker> get movimientoMetrics => _movimientoMetrics;
  List<Biomarker> get cardiacoMetrics   => _cardiacoMetrics;
  List<Biomarker> get estresMetrics     => _estresMetrics;
  bool get isLoading                    => _isLoading;
  bool get isMovimientoLoading          => _isMovimientoLoading;
  bool get isCardiacoLoading            => _isCardiacoLoading;
  bool get isEstresLoading              => _isEstresLoading;
  String? get error                     => _error;
  DateTime? get movimientoStart         => _movimientoStart;
  DateTime? get movimientoEnd           => _movimientoEnd;
  DateTime? get cardiacoStart           => _cardiacoStart;
  DateTime? get cardiacoEnd             => _cardiacoEnd;
  DateTime? get estresStart             => _estresStart;
  DateTime? get estresEnd               => _estresEnd;
  DateTime? get suenoStart                => _suenoStart;
  DateTime? get suenoEnd                  => _suenoEnd;
  DateTime? get dataRangeStart          => _dataRangeStart;
  DateTime? get dataRangeEnd            => _dataRangeEnd;
  int get selectedHours                 => _selectedHours;
  int get selectedCardiacoHours         => _selectedCardiacoHours;
  int get selectedEstresHours           => _selectedEstresHours;
  int get selectedSuenoHours            => _selectedSuenoHours;
  List<Biomarker> get suenoMetrics      => _suenoMetrics;
  bool get isSuenoLoading               => _isSuenoLoading;

  static String _bucketForHours(int hours) {
    if (hours <= 1)  return '30 seconds';
    if (hours <= 3)  return '1 minute';
    if (hours <= 6)  return '2 minutes';
    if (hours <= 12) return '5 minutes';
    return '10 minutes';
  }
  static String _resolucionLabel(String bucket) {
    return bucket
        .replaceAll(' seconds', ' seg')
        .replaceAll(' minutes', ' min')
        .replaceAll(' minute', ' min');
  }

  String get movimientoResolucion {
    if (_movimientoStart == null || _movimientoEnd == null) return '';
    return _resolucionLabel(_bucketForHours(_selectedHours));
  }

  String get cardiacoResolucion {
    if (_cardiacoStart == null || _cardiacoEnd == null) return '';
    return _resolucionLabel(_bucketForHours(_selectedCardiacoHours));
  }

  String get estresResolucion {
    if (_estresStart == null || _estresEnd == null) return '';
    return _resolucionLabel(_bucketForHours(_selectedEstresHours));
  }

  String get suenoResolucion {
    if (_suenoStart == null || _suenoEnd == null) return '';
    return _resolucionLabel(_bucketForHours(_selectedSuenoHours));
  }

  int get suenoMinutosPorPunto {
    final bucket = _bucketForHours(_selectedSuenoHours);
    if (bucket.contains('30 seconds')) return 1;
    if (bucket.contains('1 minute'))   return 1;
    if (bucket.contains('2 minutes'))  return 2;
    if (bucket.contains('5 minutes'))  return 5;
    return 10;
  }

  void _applyHourFilter() {
    if (_dataRangeEnd == null || _dataRangeStart == null) return;
    final end = _dataRangeEnd!;
    final startMov = end.subtract(Duration(hours: _selectedHours));
    _movimientoEnd   = end;
    _movimientoStart = startMov.isBefore(_dataRangeStart!) ? _dataRangeStart! : startMov;

    final startCar = end.subtract(Duration(hours: _selectedCardiacoHours));
    _cardiacoEnd   = end;
    _cardiacoStart = startCar.isBefore(_dataRangeStart!) ? _dataRangeStart! : startCar;

    final startEst = end.subtract(Duration(hours: _selectedEstresHours));
    _estresEnd   = end;
    _estresStart = startEst.isBefore(_dataRangeStart!) ? _dataRangeStart! : startEst;

    final startSue = end.subtract(Duration(hours: _selectedSuenoHours));
    _suenoEnd   = end;
    _suenoStart = startSue.isBefore(_dataRangeStart!) ? _dataRangeStart! : startSue;
  }

  Future<void> fetchMetrics(String participantId, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final metadata = await _apiService.getParticipantMetadata(participantId, username);

      if (metadata['start_time'] != null && metadata['end_time'] != null) {
        _dataRangeStart = DateTime.parse(metadata['start_time']).toLocal();
        _dataRangeEnd   = DateTime.parse(metadata['end_time']).toLocal();
        _applyHourFilter();
      }

      _globalKpis = await _apiService.getGlobalKpis(participantId, username);

      await Future.wait([
        fetchMovimientoMetrics(participantId, username),
        fetchCardiacoMetrics(participantId, username),
        fetchEstresMetrics(participantId, username),
        fetchSuenoMetrics(participantId, username),
      ]);

      // _metrics consolidado: unión de todos los módulos para backward compat
      _metrics = [
        ..._movimientoMetrics,
        ..._cardiacoMetrics,
        ..._estresMetrics,
        ..._suenoMetrics,
      ];
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
      _movimientoMetrics = all.where((m) {
        final norm = m.sensorType.toLowerCase().replaceAll('-', '_');
        return kMovimientoSensores.contains(norm);
      }).toList();
    } catch (e) {
      debugPrint('[DashboardProvider] fetchMovimientoMetrics error: $e');
      _movimientoMetrics = [];
    } finally {
      _isMovimientoLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCardiacoMetrics(String participantId, String username) async {
    if (_cardiacoStart == null || _cardiacoEnd == null) return;
    _isCardiacoLoading = true;
    notifyListeners();
    try {
      final bucket = _bucketForHours(_selectedCardiacoHours);
      final all = await _apiService.getMetrics(
        participantId,
        username,
        startTime: _cardiacoStart!.toUtc().toIso8601String(),
        endTime:   _cardiacoEnd!.toUtc().toIso8601String(),
        bucketSize: bucket,
      );
      _cardiacoMetrics = all.where((m) {
        final norm = m.sensorType.toLowerCase().replaceAll('-', '_');
        return kCardiacoSensores.contains(norm);
      }).toList();
    } catch (e) {
      debugPrint('[DashboardProvider] fetchCardiacoMetrics error: $e');
      _cardiacoMetrics = [];
    } finally {
      _isCardiacoLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchEstresMetrics(String participantId, String username) async {
    if (_estresStart == null || _estresEnd == null) return;
    _isEstresLoading = true;
    notifyListeners();
    try {
      final bucket = _bucketForHours(_selectedEstresHours);
      final all = await _apiService.getMetrics(
        participantId,
        username,
        startTime: _estresStart!.toUtc().toIso8601String(),
        endTime:   _estresEnd!.toUtc().toIso8601String(),
        bucketSize: bucket,
      );
      _estresMetrics = all.where((m) {
        final norm = m.sensorType.toLowerCase().replaceAll('-', '_');
        return kEstresSensores.contains(norm);
      }).toList();
    } catch (e) {
      debugPrint('[DashboardProvider] fetchEstresMetrics error: $e');
      _estresMetrics = [];
    } finally {
      _isEstresLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSuenoMetrics(String participantId, String username) async {
    if (_suenoStart == null || _suenoEnd == null) return;
    _isSuenoLoading = true;
    notifyListeners();
    try {
      final bucket = _bucketForHours(_selectedSuenoHours);
      final all = await _apiService.getMetrics(
        participantId,
        username,
        startTime: _suenoStart!.toUtc().toIso8601String(),
        endTime:   _suenoEnd!.toUtc().toIso8601String(),
        bucketSize: bucket,
      );
      _suenoMetrics = all.where((m) {
        final norm = m.sensorType.toLowerCase().replaceAll('-', '_');
        return kSuenoSensores.contains(norm);
      }).toList();
    } catch (e) {
      debugPrint('[DashboardProvider] fetchSuenoMetrics error: $e');
      _suenoMetrics = [];
    } finally {
      _isSuenoLoading = false;
      notifyListeners();
    }
  }

  Future<void> setHourFilter(int hours, String participantId, String username) async {
    _selectedHours = hours;
    _selectedCardiacoHours = hours;
    _selectedEstresHours = hours;
    _selectedSuenoHours = hours;
    _applyHourFilter();
    await Future.wait([
      fetchMovimientoMetrics(participantId, username),
      fetchCardiacoMetrics(participantId, username),
      fetchEstresMetrics(participantId, username),
      fetchSuenoMetrics(participantId, username),
    ]);
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

  Future<void> setCardiacoRango(
    DateTime start,
    DateTime end,
    String participantId,
    String username,
  ) async {
    _cardiacoStart = start;
    _cardiacoEnd   = end;
    _selectedCardiacoHours = _durationToNearestHours(end.difference(start));
    await fetchCardiacoMetrics(participantId, username);
  }

  Future<void> setEstresRango(
    DateTime start,
    DateTime end,
    String participantId,
    String username,
  ) async {
    _estresStart = start;
    _estresEnd   = end;
    _selectedEstresHours = _durationToNearestHours(end.difference(start));
    await fetchEstresMetrics(participantId, username);
  }

  Future<void> setSuenoRango(
    DateTime start,
    DateTime end,
    String participantId,
    String username,
  ) async {
    _suenoStart = start;
    _suenoEnd   = end;
    _selectedSuenoHours = _durationToNearestHours(end.difference(start));
    await fetchSuenoMetrics(participantId, username);
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
    final val = _globalKpis?['total_steps'];
    if (val == null) return null;
    if (val is num) return val.toInt();
    return double.tryParse(val.toString())?.toInt();
  }

  int? get avgBpm {
    final val = _globalKpis?['avg_bpm'];
    if (val == null) return null;
    if (val is num) return val.toInt();
    return double.tryParse(val.toString())?.toInt();
  }

  double? get totalMets {
    final mets = _estresMetrics.where((m) => m.sensorType == 'met' && m.value != null);
    if (mets.isEmpty) return null;
    return mets.fold<double>(0.0, (sum, m) => sum + m.value!);
  }

  double? get avgTemp {
    final temp = _estresMetrics.where((m) => m.sensorType == 'temperature' && m.value != null);
    if (temp.isEmpty) return null;
    return temp.fold<double>(0.0, (sum, m) => sum + m.value!) / temp.length;
  }

  double? get compliancePercentage {
    final val = _globalKpis?['compliance_percentage'];
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  double? get sleepHours {
    final val = _globalKpis?['sleep_hours'];
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  double? get avgStress {
    final val = _globalKpis?['avg_stress'];
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }

  String get lastActivity {
    final actRaw = _globalKpis?['last_activity'];
    if (actRaw == null) return 'Desconocido';
    final intVal = actRaw is num ? actRaw.toInt() : (double.tryParse(actRaw.toString())?.toInt() ?? -1);
    switch (intVal) {
      case 0: return 'Sedentario';
      case 1: return 'Caminando';
      case 2: return 'Corriendo';
      case 3: return 'Actividad Genérica';
      default: return 'Desconocido';
    }
  }

  String get lastPosition {
    final posRaw = _globalKpis?['last_position'];
    if (posRaw == null) return 'Desconocido';
    final intVal = posRaw is num ? posRaw.toInt() : (double.tryParse(posRaw.toString())?.toInt() ?? -1);
    switch (intVal) {
      case 0: return 'Sentado / Reclinado';
      case 1: return 'De pie';
      case 2: return 'Izquierda';
      case 3: return 'Derecha';
      case 4: return 'Arriba';
      case 5: return 'Abajo';
      case 6: return 'Transición';
      default: return 'Desconocido';
    }
  }
}
