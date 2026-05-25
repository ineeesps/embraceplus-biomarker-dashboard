/// Represents a single time-stamped biomarker reading from a wearable sensor.
///
/// [sensorType] is normalized to snake_case on construction so that upstream
/// hyphenated names (e.g. 'pulse-rate') are unified with stored names ('pulse_rate').
/// [value] is null when the sensor produced no valid reading for the given bucket.
/// [qualityFlag] encodes signal reliability: 'good' | 'low_signal_quality' |
/// 'worn_during_motion' | 'device_not_recording' | 'device_not_worn_correctly'.
class Biomarker {
  final DateTime time;
  final String sensorType;
  final double? value;
  final String qualityFlag;

  Biomarker({
    required this.time,
    required this.sensorType,
    this.value,
    required this.qualityFlag,
  });

  /// Deserializes a JSON map returned by [/participante/{id}/metricas].
  /// Parses timestamps to local time and normalises sensor type to snake_case.
  factory Biomarker.fromJson(Map<String, dynamic> json) {
    final typeStr = json['sensor_type']?.toString() ?? 'unknown';
    return Biomarker(
      time: DateTime.parse(json['time'].toString()).toLocal(),
      sensorType: typeStr.toLowerCase().replaceAll('-', '_'),
      value: json['value'] == null ? null : double.tryParse(json['value'].toString()),
      qualityFlag: json['quality_flag']?.toString() ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'sensor_type': sensorType,
        'value': value,
        'quality_flag': qualityFlag,
      };
}
