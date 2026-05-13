import 'package:flutter/material.dart';
import '../models/biomarker.dart';
import '../services/api_service.dart';

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Biomarker> _metrics = [];
  bool _isLoading = false;
  String? _error;

  TimeOfDay? _startHour;
  TimeOfDay? _endHour;
  DateTime? _sessionDate;
  DateTime? _endDate;

  List<Biomarker> get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TimeOfDay? get startHour => _startHour;
  TimeOfDay? get endHour => _endHour;
  DateTime? get sessionDate => _sessionDate;
  DateTime? get endDate => _endDate;

  void setTimeRange(TimeOfDay? start, TimeOfDay? end, String participantId, String username, {DateTime? date}) {
    _startHour = start;
    _endHour = end;
    if (date != null) {
      _sessionDate = date;
    }
    fetchMetrics(participantId, username);
  }

  void setDateRange(DateTime? start, DateTime? end, String participantId, String username) {
    _sessionDate = start;
    _endDate = end;
    _startHour = start != null ? TimeOfDay(hour: start.hour, minute: start.minute) : null;
    _endHour = end != null ? TimeOfDay(hour: end.hour, minute: end.minute) : null;
    fetchMetrics(participantId, username);
  }

  Future<void> fetchMetrics(String participantId, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String? startStr;
      String? endStr;

      if (_startHour != null && _sessionDate != null) {
        final dateStart = DateTime.utc(_sessionDate!.year, _sessionDate!.month, _sessionDate!.day, _startHour!.hour, _startHour!.minute);
        startStr = dateStart.toIso8601String();
      }
      if (_endHour != null) {
        final targetDate = _endDate ?? _sessionDate;
        if (targetDate != null) {
          final dateEnd = DateTime.utc(targetDate.year, targetDate.month, targetDate.day, _endHour!.hour, _endHour!.minute);
          endStr = dateEnd.toIso8601String();
        }
      }

      _metrics = await _apiService.getMetrics(participantId, username, startTime: startStr, endTime: endStr);
      
      if (_metrics.isNotEmpty && _startHour == null && _endHour == null) {
        _sessionDate = _metrics.first.time.toUtc();
      }
      
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    final avg = bpm.fold<double>(0.0, (sum, m) => sum + m.value!) / bpm.length;
    return avg.toInt();
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
    
    int validPoints = 0;
    for (var m in wearing) {
      if (m.qualityFlag != 'device_not_worn_correctly' && m.qualityFlag != 'device_not_recording') {
        validPoints++;
      }
    }
    return (validPoints / wearing.length) * 100;
  }
}
