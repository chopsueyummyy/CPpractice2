class ApiConfig {
  // ── THE MASTER SWITCH ──────────────────────────────────────────────────────
  // Set this to 'true' to test locally with Docker (localhost:8000)
  // Set this to 'false' to test in the DigitalOcean cloud
  static const bool isLocal = false; 

  // ── THE ADDRESS BOOK ──────────────────────────────────────────────────────
  
  // Local Docker Base URL
  static const String _localBaseUrl = 'http://127.0.0.1:8000';
  
  // DigitalOcean Cloud Base URL (Now using relative proxy path)
  static const String _productionBaseUrl = '/api';

  // The active URL
  static String get baseUrl => isLocal ? _localBaseUrl : _productionBaseUrl;

  // ── READY-MADE ENDPOINTS ──────────────────────────────────────────────────
  static String get login       => '$baseUrl/login.php';
  static String get register    => '$baseUrl/register.php';
  static String get dashboard   => '$baseUrl/get_dashboard_stats.php'; // Example
  static String get questions   => '$baseUrl/get_questions.php';
  static String get submit      => '$baseUrl/submit_assessment.php';
}
