import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/biomarker.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  Future<List<String>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['participantes_asignados']);
      } else {
        throw Exception('Credenciales incorrectas');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor');
    }
  }

  Future<List<Map<String, dynamic>>> getParticipantsSummary(String username) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/investigador/$username/resumen_pacientes'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['pacientes']);
      } else {
        throw Exception('Error al cargar el resumen de pacientes');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Biomarker>> getMetrics(String participantId, {String? startTime, String? endTime}) async {
    try {
      String url = '$baseUrl/participante/$participantId/metricas';
      List<String> params = [];
      if (startTime != null) params.add('start=$startTime');
      if (endTime != null) params.add('end=$endTime');
      
      if (params.isNotEmpty) {
        url = '$url?${params.join('&')}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> metricsJson = data['metricas'];
        return metricsJson.map((json) => Biomarker.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load metrics: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to backend: $e');
    }
  }

  Future<Map<String, dynamic>> uploadCsv(String participantId, List<int> bytes, String fileName) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/participante/$participantId/cargar'),
    );
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final response = await request.send();
    final responseData = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return json.decode(responseData);
    } else {
      throw Exception('Upload failed: $responseData');
    }
  }
}
