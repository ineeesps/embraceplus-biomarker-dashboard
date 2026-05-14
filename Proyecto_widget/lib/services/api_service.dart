import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/biomarker.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  Future<List<String>> login(String username, String password) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      throw Exception('Error al conectar con el servidor. Verifica tu conexión.');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['participantes_asignados']);
    } else if (response.statusCode == 401) {
      throw Exception('Usuario o contraseña incorrectos');
    } else {
      throw Exception('Error del servidor (${response.statusCode})');
    }
  }

  Future<List<Map<String, dynamic>>> getParticipantsSummary(String username) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/investigador/$username/resumen_participantes'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['participantes']);
      } else {
        throw Exception('Error al cargar el resumen de participantes');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<Biomarker>> getMetrics(
    String participantId,
    String username, {
    String? startTime,
    String? endTime,
    String bucketSize = '30 seconds',
  }) async {
    try {
      final params = [
        'investigador=$username',
        'bucket_size=${Uri.encodeComponent(bucketSize)}',
        if (startTime != null) 'start=${Uri.encodeComponent(startTime)}',
        if (endTime != null)   'end=${Uri.encodeComponent(endTime)}',
      ];
      final url = '$baseUrl/participante/$participantId/metricas?${params.join('&')}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> metricsJson = data['metricas'];
        return metricsJson.map((json) => Biomarker.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar métricas: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  Future<Map<String, dynamic>> uploadCsv(String participantId, String username, List<int> bytes, String fileName, {bool replace = false}) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/participante/$participantId/cargar?investigador=$username&reemplazar=$replace'),
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
      throw Exception('Error al subir CSV: $responseData');
    }
  }

  Future<bool> checkSensorDataExists(String participantId, String sensorType, String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/participante/$participantId/sensor/$sensorType/existe?investigador=$username'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['existe'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteParticipant(String participantId, String username) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/participante/$participantId?investigador=$username'),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar participante: ${response.body}');
    }
  }

  Future<void> renameParticipant(String oldId, String newId, String username) async {
    final response = await http.put(
      Uri.parse('$baseUrl/participante/$oldId/renombrar?nuevo_id=$newId&investigador=$username'),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al renombrar: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getParticipantMetadata(String participantId, String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/participante/$participantId/metadata?investigador=$username'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al cargar metadatos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<int>> exportParticipantCsv(String participantId, String username, {String bucketSize = '1 minute'}) async {
    final url = '$baseUrl/participante/$participantId/exportar?investigador=$username&bucket_size=${Uri.encodeComponent(bucketSize)}';
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Error al exportar datos (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error al exportar: $e');
    }
  }
}
