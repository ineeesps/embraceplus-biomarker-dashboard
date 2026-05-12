import 'package:flutter/material.dart';
import '../models/biomarker.dart';
import '../services/api_service.dart';

/// [DashboardProvider] gestiona el estado de la visualización de biomarcadores.
/// Maneja la carga de datos y el filtrado por rango horario.
class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Biomarker> _metrics = [];
  bool _isLoading = false;
  String? _error;

  TimeOfDay? _startHour;
  TimeOfDay? _endHour;
  DateTime? _sessionDate;

  List<Biomarker> get metrics => _metrics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  TimeOfDay? get startHour => _startHour;
  TimeOfDay? get endHour => _endHour;
  DateTime? get sessionDate => _sessionDate;

  void setTimeRange(TimeOfDay? start, TimeOfDay? end, String participantId, String username) {
    _startHour = start;
    _endHour = end;
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
      if (_endHour != null && _sessionDate != null) {
        final dateEnd = DateTime.utc(_sessionDate!.year, _sessionDate!.month, _sessionDate!.day, _endHour!.hour, _endHour!.minute);
        endStr = dateEnd.toIso8601String();
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
}
