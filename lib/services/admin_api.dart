import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AdminApiService {
  static const String _adminPin = '1234567';

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Admin-Pin': _adminPin,
      };

  static Future<Map<String, dynamic>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin_users.php'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> registerUser(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/admin_users.php'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateUser(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin_users.php'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> deleteUser(String role, int id) async {
    final response = await http.delete(
      Uri.parse('${ApiService.baseUrl}/admin_users.php'),
      headers: _headers,
      body: jsonEncode({'role': role, 'id': id}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getArchives() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin_data.php'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> invalidateRecord(int assessmentId) async {
    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/admin_data.php'),
      headers: _headers,
      body: jsonEncode({'assessmentId': assessmentId, 'status': 'invalid'}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getArchiveDetails(int assessmentId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin_data.php?assessmentId=$assessmentId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }
}
