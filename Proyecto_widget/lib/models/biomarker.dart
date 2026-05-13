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

  factory Biomarker.fromJson(Map<String, dynamic> json) {
    return Biomarker(
      time: DateTime.parse(json['time'].toString()),
      sensorType: json['sensor_type']?.toString() ?? 'unknown',
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
