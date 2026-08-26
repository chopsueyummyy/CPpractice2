import 'dart:html' as html;

/// Stores the current user session in LocalStorage.
/// Survives browser refreshes.
class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;

  SessionManager._internal() {
    _loadFromStorage();
  }

  // Student details
  String? studentId;
  String? studentFirstName;
  String? studentLastName;

  // Counselor details
  int? counselorId;
  String? counselorFirstName;
  String? counselorLastName;

  // Admin details
  int? adminId;
  int? roleId; // 3 for Admin, 4 for SuperAdmin

  // Global state
  String? role;
  int? currentPiId;
  int? currentAssessmentId;
  int? currentResultId;
  String? assessmentStatus; // 'pending_review', 'approved', 'rejected', 'in_progress'
  bool hasAgreedToDisclaimer = false;

  void _loadFromStorage() {
    final storage = html.window.localStorage;
    studentId           = storage['riasec_studentId'];
    studentFirstName    = storage['riasec_studentFirstName'];
    studentLastName     = storage['riasec_studentLastName'];
    
    counselorId         = int.tryParse(storage['riasec_counselorId'] ?? '');
    counselorFirstName  = storage['riasec_counselorFirstName'];
    counselorLastName   = storage['riasec_counselorLastName'];
    
    adminId             = int.tryParse(storage['riasec_adminId'] ?? '');
    roleId              = int.tryParse(storage['riasec_roleId'] ?? '');
    
    role                = storage['riasec_role'];
    currentPiId         = int.tryParse(storage['riasec_currentPiId'] ?? '');
    currentAssessmentId = int.tryParse(storage['riasec_currentAssessmentId'] ?? '');
    currentResultId     = int.tryParse(storage['riasec_currentResultId'] ?? '');
    assessmentStatus    = storage['riasec_assessmentStatus'];
  }

  void _saveToStorage() {
    final storage = html.window.localStorage;
    storage['riasec_studentId']           = studentId ?? '';
    storage['riasec_studentFirstName']    = studentFirstName ?? '';
    storage['riasec_studentLastName']     = studentLastName ?? '';
    
    storage['riasec_counselorId']         = counselorId?.toString() ?? '';
    storage['riasec_counselorFirstName']  = counselorFirstName ?? '';
    storage['riasec_counselorLastName']   = counselorLastName ?? '';
    
    storage['riasec_adminId']             = adminId?.toString() ?? '';
    storage['riasec_roleId']              = roleId?.toString() ?? '';
    
    storage['riasec_role']                = role ?? '';
    storage['riasec_currentPiId']         = currentPiId?.toString() ?? '';
    storage['riasec_currentAssessmentId'] = currentAssessmentId?.toString() ?? '';
    storage['riasec_currentResultId']     = currentResultId?.toString() ?? '';
    storage['riasec_assessmentStatus']    = assessmentStatus ?? '';
  }

  String get fullName {
    if (role == 'student') {
      return '${studentFirstName ?? ''} ${studentLastName ?? ''}'.trim();
    } else {
      return '${counselorFirstName ?? ''} ${counselorLastName ?? ''}'.trim();
    }
  }

  void setStudent(Map<String, dynamic> data) {
    role                = 'student';
    studentId           = data['studentId'].toString();
    studentFirstName    = data['firstName'];
    studentLastName     = data['lastName'];
    assessmentStatus    = data['assessmentStatus'];
    _saveToStorage();
  }

  void setCounselor(Map<String, dynamic> data) {
    role                 = 'guidance_counselor';
    counselorId          = data['counselorId'];
    counselorFirstName   = data['firstName'];
    counselorLastName    = data['lastName'];
    _saveToStorage();
  }

  void setAdmin(Map<String, dynamic> data) {
    role                = data['role']; // 'admin' or 'super_admin'
    adminId             = data['adminId'];
    roleId              = (role == 'super_admin') ? 4 : 3;
    counselorFirstName  = data['firstName']; // Re-using counselor fields for display
    counselorLastName   = data['lastName'];
    _saveToStorage();
  }

  void setAssessmentId(int id) {
    currentAssessmentId = id;
    _saveToStorage();
  }

  void setPiId(int id) {
    currentPiId = id;
    _saveToStorage();
  }

  void clearAssessmentFlow() {
    currentPiId          = null;
    currentAssessmentId  = null;
    currentResultId      = null;
    assessmentStatus     = null;
    _saveToStorage();
  }

  void logout() {
    final storage = html.window.localStorage;
    storage.clear(); // Wipe everything
    studentId            = null;
    studentFirstName     = null;
    studentLastName      = null;
    counselorId          = null;
    counselorFirstName   = null;
    counselorLastName    = null;
    adminId              = null;
    roleId               = null;
    role                 = null;
    clearAssessmentFlow();
  }
}