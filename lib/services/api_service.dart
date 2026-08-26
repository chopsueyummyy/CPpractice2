import 'dart:convert';

import 'package:http/http.dart' as http;
import '../utils/api_config.dart';

class ApiService {
  static final String baseUrl = ApiConfig.baseUrl;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  // ── AUTH ──────────────────────────────────────────────
  static Future<Map<String, dynamic>> loginStudent(
      String studentId, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login.php'),
      headers: _headers,
      body: jsonEncode({
        'role': 'student',
        'student_id': studentId,
        'password': password,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> loginCounselor(
      String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login.php'),
      headers: _headers,
      body: jsonEncode({
        'role': 'guidance_counselor',
        'email': email,
        'password': password,
      }),
    );
    return jsonDecode(response.body);
  }

  // ── STUDENT FLOW ──────────────────────────────────────
  static Future<Map<String, dynamic>> savePersonalInfo(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/save_personal_info.php'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> startAssessment(
      String studentId, int piId, {bool agreed = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/start_assessment.php'),
      headers: _headers,
      body: jsonEncode({'studentId': studentId, 'piId': piId, 'agreed': agreed}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getQuestions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_questions.php'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<void> updateLiveSession(
      int assessmentId, int currentQuestion, int duration) async {
    await http.post(
      Uri.parse('$baseUrl/update_live_session.php'),
      headers: _headers,
      body: jsonEncode({
        'assessmentId': assessmentId,
        'currentQuestion': currentQuestion,
        'duration': duration,
      }),
    );
  }

  static Future<Map<String, dynamic>> submitAssessment({
    required int assessmentId,
    required List<Map<String, dynamic>> answers,
    required List<Map<String, dynamic>> rseAnswers,
    required List<Map<String, dynamic>> cdsesAnswers,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/submit_assessment.php'),
      headers: _headers,
      body: jsonEncode({
        'assessmentId': assessmentId,
        'answers': answers,
        'rseAnswers': rseAnswers,
        'cdsesAnswers': cdsesAnswers,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> cancelAssessment(int assessmentId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cancel_assessment.php'),
      headers: _headers,
      body: jsonEncode({'assessmentId': assessmentId}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getResults(int assessmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_results.php?assessmentId=$assessmentId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getResultsByStudentId(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_results.php?studentId=$studentId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getStudentStatus(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_student_status.php?studentId=$studentId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getHistory(String studentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_history.php?studentId=$studentId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> approveRejectAssessment({
    required int assessmentId,
    required String action,
    required int counselorId,
    required String notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/approve_reject_assessment.php'),
      headers: _headers,
      body: jsonEncode({
        'assessmentId': assessmentId,
        'action': action,
        'counselorId': counselorId,
        'notes': notes,
      }),
    );
    return jsonDecode(response.body);
  }

  // ── COUNSELOR ─────────────────────────────────────────
  static Future<Map<String, dynamic>> getLiveSessions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_live_sessions.php'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPendingApprovals() async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_pending_approvals.php'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> submitFeedback({
    required int assessmentId,
    required int counselorId,
    required String action,
    String? feedbackNotes,
    int? modifiedCourseId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/submit_feedback.php'),
      headers: _headers,
      body: jsonEncode({
        'assessmentId': assessmentId,
        'counselorId': counselorId,
        'action': action,
        'feedbackNotes': feedbackNotes,
        'modifiedCourseId': modifiedCourseId,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getStudentRecords({
    String status = 'all',
    String gradeLevel = 'all',
    String strand = 'all',
    String dominantType = 'all',
    String rseLevel = 'all',
    String cdsesLevel = 'all',
    String dateFrom = '',
    String dateTo = '',
    String search = '',
  }) async {
    final uri = Uri.parse('$baseUrl/get_student_records.php').replace(
      queryParameters: {
        'status': status,
        'gradeLevel': gradeLevel,
        'strand': strand,
        'dominantType': dominantType,
        'rseLevel': rseLevel,
        'cdsesLevel': cdsesLevel,
        'dateFrom': dateFrom,
        'dateTo': dateTo,
        'search': search,
      },
    );
    final response = await http.get(uri, headers: _headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getDashboardStats(String filter) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_dashboard_stats.php?filter=$filter'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  // ── CITADEL V2 ADMIN ──────────────────────────────────
  static Future<Map<String, dynamic>> getAdminStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_admin_stats.php'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAdminUsers(int adminId, int roleId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin_users_v2.php?adminId=$adminId&roleId=$roleId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> manageAdminUser(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin_users_v2.php'),
      headers: _headers,
      body: jsonEncode(data),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getAdminLogs(int adminId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/get_admin_logs.php?adminId=$adminId'),
      headers: _headers,
    );
    return jsonDecode(response.body);
  }

  static String getExportUrl(int adminId) {
    return '$baseUrl/admin_archive.php?exportCsv=true&adminId=$adminId';
  }

  static String getExportPdfUrl(String adminId, {String roleId = '2'}) {
    return '$baseUrl/export_pdf_summary.php?adminId=$adminId&roleId=$roleId';
  }
}