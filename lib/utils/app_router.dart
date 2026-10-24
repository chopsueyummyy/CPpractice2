import 'package:go_router/go_router.dart';

import '../models/riasec_models.dart';
import '../screens/guidance_counselor/counselor_dashboard.dart';
import '../screens/guidance_counselor/monitoring_screen.dart';
import '../screens/guidance_counselor/pending_approvals_screen.dart';
import '../screens/guidance_counselor/student_feedback_screen.dart';
import '../screens/guidance_counselor/student_records_screen.dart';
import '../screens/shared/login_screen.dart';
import '../screens/student/assessment_instructions.dart';
import '../screens/student/assessment_screen.dart';
import '../screens/student/history_screen.dart';
import '../screens/student/results_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/student/student_details_form.dart';
import '../screens/student/student_registration_screen.dart';
import '../screens/admin/admin_dashboard_v2.dart';
import '../screens/shared/otp_screen.dart';
import '../services/session_manager.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = SessionManager();
    final path = state.uri.path.replaceAll('_', '-');

    final bool isStudentLoggedIn = session.studentId != null && session.studentId!.isNotEmpty && session.role == 'student';
    final bool isCounselorLoggedIn = session.counselorId != null && session.role == 'guidance_counselor';
    final bool isPsychometricianLoggedIn = session.counselorId != null && session.role == 'psychometrician';
    final bool isAdminLoggedIn = session.adminId != null && (session.role == 'admin' || session.role == 'super_admin');
    final bool isAuthenticated = isStudentLoggedIn || isCounselorLoggedIn || isPsychometricianLoggedIn || isAdminLoggedIn;

    final bool isPublicRoute = path == '/login' ||
        path == '/staff/login' ||
        path == '/staff' ||
        path == '/admin/login' ||
        path == '/admin' ||
        path == '/register' ||
        path == '/verify-otp';

    // 1. Unauthenticated users trying to access protected routes -> redirect to appropriate portal
    if (!isAuthenticated && !isPublicRoute) {
      if (path.startsWith('/admin')) {
        return '/admin/login';
      }
      if (path.startsWith('/guidance-counselor') ||
          path.startsWith('/psychometrician') ||
          path.startsWith('/staff')) {
        return '/staff/login';
      }
      return '/login';
    }

    // 2. Authenticated users trying to access login or register -> redirect to respective dashboard
    final bool isAuthLandingRoute = path == '/login' ||
        path == '/staff/login' ||
        path == '/staff' ||
        path == '/admin/login' ||
        path == '/admin' ||
        path == '/register';

    if (isAuthenticated && isAuthLandingRoute) {
      if (isStudentLoggedIn) return '/student/dashboard';
      if (isPsychometricianLoggedIn) return '/psychometrician/dashboard';
      if (isCounselorLoggedIn) return '/guidance-counselor/dashboard';
      if (isAdminLoggedIn) return '/admin/dashboard';
    }

    // 3. Student Route Protections
    if (path.startsWith('/student/')) {
      if (!isStudentLoggedIn) {
        if (isPsychometricianLoggedIn) return '/psychometrician/dashboard';
        if (isCounselorLoggedIn) return '/guidance-counselor/dashboard';
        if (isAdminLoggedIn) return '/admin/dashboard';
        return '/login';
      }

      // Assessment lockdown logic: check LocalStorage status immediately
      final status = session.assessmentStatus;
      final isAssessmentRoute = path.startsWith('/student/assessment') ||
                                path.contains('student-details') ||
                                path == '/student/assessment-instructions';
      
      if (isAssessmentRoute && (status == 'pending_review' || status == 'approved')) {
        return '/student/dashboard';
      }
    }

    // 4. Psychometrician Route Protections
    if (path.startsWith('/psychometrician/')) {
      if (!isPsychometricianLoggedIn) {
        if (isStudentLoggedIn) return '/student/dashboard';
        if (isCounselorLoggedIn) return '/guidance-counselor/dashboard';
        if (isAdminLoggedIn) return '/admin/dashboard';
        return '/staff/login';
      }
    }

    // 5. Guidance Counselor Route Protections
    if (path.startsWith('/guidance-counselor/')) {
      if (!isCounselorLoggedIn) {
        if (isStudentLoggedIn) return '/student/dashboard';
        if (isPsychometricianLoggedIn) return '/psychometrician/dashboard';
        if (isAdminLoggedIn) return '/admin/dashboard';
        return '/staff/login';
      }
    }

    // 6. Admin Route Protections
    if (path.startsWith('/admin/') && path != '/admin/login') {
      if (!isAdminLoggedIn) {
        if (isStudentLoggedIn) return '/student/dashboard';
        if (isPsychometricianLoggedIn) return '/psychometrician/dashboard';
        if (isCounselorLoggedIn) return '/guidance-counselor/dashboard';
        return '/admin/login';
      }
    }

    return null; // No redirection needed
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(portalType: 'student'),
    ),
    GoRoute(
      path: '/staff/login',
      builder: (context, state) => const LoginScreen(portalType: 'staff'),
    ),
    GoRoute(
      path: '/staff',
      builder: (context, state) => const LoginScreen(portalType: 'staff'),
    ),
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const LoginScreen(portalType: 'admin'),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const LoginScreen(portalType: 'admin'),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const StudentRegistrationScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final extraData = state.extra as Map<String, dynamic>?;
        return OtpScreen(extraData: extraData);
      },
    ),
    // Student Routes
    GoRoute(
      path: '/student/dashboard',
      builder: (context, state) => const StudentDashboard(),
    ),
    GoRoute(
      path: '/student/student-details',
      builder: (context, state) => const StudentDetailsForm(),
    ),
    GoRoute(
      path: '/student/assessment-instructions',
      builder: (context, state) {
        final studentDetails = state.extra as StudentDetails?;
        return AssessmentInstructionsScreen(studentDetails: studentDetails);
      },
    ),
    GoRoute(
      path: '/student/assessment',
      builder: (context, state) => const AssessmentScreen(),
    ),
    GoRoute(
      path: '/student/results',
      builder: (context, state) => const ResultsScreen(),
    ),
    GoRoute(
      path: '/student/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    // Guidance Counselor Routes
    GoRoute(
      path: '/guidance-counselor/dashboard',
      builder: (context, state) => const CounselorDashboard(),
    ),
    GoRoute(
      path: '/guidance-counselor/monitoring',
      builder: (context, state) => const MonitoringScreen(),
    ),
    GoRoute(
      path: '/guidance-counselor/pending-approvals',
      builder: (context, state) => const PendingApprovalsScreen(),
    ),
    GoRoute(
      path: '/guidance-counselor/student-records',
      builder: (context, state) => const StudentRecordsScreen(),
    ),
    GoRoute(
      path: '/guidance-counselor/ai-feedback',
      builder: (context, state) {
        final extraData = state.extra as Map<String, dynamic>?;
        return StudentFeedbackScreen(extraData: extraData);
      },
    ),
    // Psychometrician Routes
    GoRoute(
      path: '/psychometrician/dashboard',
      builder: (context, state) => const CounselorDashboard(),
    ),
    GoRoute(
      path: '/psychometrician/monitoring',
      builder: (context, state) => const MonitoringScreen(),
    ),
    GoRoute(
      path: '/psychometrician/pending-approvals',
      builder: (context, state) => const PendingApprovalsScreen(),
    ),
    GoRoute(
      path: '/psychometrician/student-records',
      builder: (context, state) => const StudentRecordsScreen(),
    ),
    GoRoute(
      path: '/psychometrician/ai-feedback',
      builder: (context, state) {
        final extraData = state.extra as Map<String, dynamic>?;
        return StudentFeedbackScreen(extraData: extraData);
      },
    ),
    // Admin Routes
    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) => const AdminDashboardV2(),
    ),
  ],
);