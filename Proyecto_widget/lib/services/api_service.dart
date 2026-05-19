import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/biomarker.dart';

class ApiService {
  final String baseUrl;

  ApiService({this.baseUrl = 'http://localhost:8000'});

  Future<Map<String, dynamic>> login(String username, String password) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception('El servidor no responde. Verifica que la API y la base de datos están activas.');
    } catch (e) {
      throw Exception('No se puede conectar al servidor. Verifica tu conexión.');
    }

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw Exception('Usuario o contraseña incorrectos');
    } else if (response.statusCode == 500) {
      throw Exception('Error interno del servidor. La base de datos puede no estar disponible.');
    } else {
      throw Exception('Error del servidor (${response.statusCode})');
    }
  }

  Future<List<Map<String, dynamic>>> getParticipantsSummary(String username) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/investigador/$username/resumen_participantes'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['participantes']);
      } else {
        throw Exception('Error al cargar el resumen de participantes (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('El servidor tardó demasiado. Verifica que la API está activa.');
    } catch (e) {
      if (e is Exception) rethrow;
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
      final encodedId = Uri.encodeComponent(participantId);
      final url = '$baseUrl/participante/$encodedId/metricas?${params.join('&')}';
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

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

  Future<Map<String, dynamic>> getGlobalKpis(String participantId, String username) async {
    try {
      final encodedId = Uri.encodeComponent(participantId);
      final response = await http.get(
        Uri.parse('$baseUrl/participante/$encodedId/kpis_globales?investigador=$username'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al cargar KPIs globales: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al conectar con el servidor: $e');
    }
  }

  Future<Map<String, dynamic>> uploadCsv(String participantId, String username, List<int> bytes, String fileName, {bool replace = false}) async {
    final encodedId = Uri.encodeComponent(participantId);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/participante/$encodedId/cargar?investigador=$username&reemplazar=$replace'),
    );
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final response = await request.send().timeout(const Duration(seconds: 60));
    final responseData = await response.stream.bytesToString();
    
    if (response.statusCode == 200) {
      return json.decode(responseData);
    } else {
      throw Exception('Error al subir CSV: $responseData');
    }
  }

  Future<bool> checkSensorDataExists(String participantId, String sensorType, String username) async {
    try {
      final encodedId = Uri.encodeComponent(participantId);
      final encodedSensor = Uri.encodeComponent(sensorType);
      final response = await http.get(
        Uri.parse('$baseUrl/participante/$encodedId/sensor/$encodedSensor/existe?investigador=$username'),
      ).timeout(const Duration(seconds: 10));
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
    final encodedId = Uri.encodeComponent(participantId);
    final response = await http.delete(
      Uri.parse('$baseUrl/participante/$encodedId?investigador=$username&confirmar=true'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar participante: ${response.body}');
    }
  }

  Future<void> renameParticipant(String oldId, String newId, String username) async {
    final encodedOldId = Uri.encodeComponent(oldId);
    final encodedNewId = Uri.encodeComponent(newId);
    final response = await http.put(
      Uri.parse('$baseUrl/participante/$encodedOldId/renombrar?nuevo_id=$encodedNewId&investigador=$username'),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al renombrar: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getParticipantMetadata(String participantId, String username) async {
    try {
      final encodedId = Uri.encodeComponent(participantId);
      final response = await http.get(
        Uri.parse('$baseUrl/participante/$encodedId/metadata?investigador=$username'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al cargar metadatos');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<int>> exportParticipantCsv(
    String participantId,
    String username, {
    String bucketSize = '1 minute',
    String method = 'linear',
    String? startTime,
    String? endTime,
  }) async {
    final encodedId = Uri.encodeComponent(participantId);
    final params = [
      'investigador=$username',
      'bucket_size=${Uri.encodeComponent(bucketSize)}',
      'method=$method',
      if (startTime != null) 'start=${Uri.encodeComponent(startTime)}',
      if (endTime != null)   'end=${Uri.encodeComponent(endTime)}',
    ];
    final url = '$baseUrl/participante/$encodedId/exportar?${params.join('&')}';
    try {
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Error al exportar datos (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error al exportar: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAdminInvestigators() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/investigadores'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Error al obtener investigadores (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> createAdminInvestigator(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/investigadores'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Error al crear investigador');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> toggleInvestigatorStatus(int id, bool isActive) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/investigadores/$id/estado'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'is_active': isActive}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Error al cambiar estado del investigador (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<List<String>> getAdminAllParticipants() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/participantes'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<String>.from(data);
      } else {
        throw Exception('Error al obtener participantes (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> updateInvestigatorDetails(int id, String nombreCompleto, String username) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/investigadores/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'nombre_completo': nombreCompleto,
          'username': username,
        }),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Error al actualizar investigador');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> deleteInvestigator(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/investigadores/$id'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Error al eliminar investigador');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}
