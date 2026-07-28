import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/student_sidebar.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _session = SessionManager();
  String? _assessmentStatus; // null = no assessment, 'pending_review', 'approved', 'rejected'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAssessmentStatus();
  }

  Future<void> _checkAssessmentStatus() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getStudentStatus(_session.studentId!);
      if (data['status'] == 'success') {
        setState(() {
          _assessmentStatus = data['assessmentStatus'];
          _session.assessmentStatus = _assessmentStatus; // Save globally
          if (data['assessmentId'] != null) {
            _session.currentAssessmentId = int.tryParse(data['assessmentId'].toString());
          }
        });
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  String get _buttonLabel {
    switch (_assessmentStatus) {
      case 'in_progress':
        return 'Resume Assessment';
      case 'pending_review':
        return 'Awaiting Counselor Review...';
      case 'approved':
        return 'Assessment Completed';
      case 'rejected':
        return 'Retake Assessment';
      default:
        return 'Start Test';
    }
  }

  bool get _buttonEnabled {
    return _assessmentStatus == null || 
           _assessmentStatus == 'rejected' || 
           _assessmentStatus == 'in_progress';
  }

  IconData get _buttonIcon {
    switch (_assessmentStatus) {
      case 'in_progress':
        return Icons.play_circle_fill;
      case 'pending_review':
        return Icons.hourglass_empty;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.refresh;
      default:
        return Icons.quiz;
    }
  }

  Color get _buttonColor {
    switch (_assessmentStatus) {
      case 'in_progress':
        return AppTheme.primaryPurple;
      case 'pending_review':
        return Colors.grey;
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.warning;
      default:
        return AppTheme.primaryYellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: StudentSidebar(currentRoute: '/student/dashboard'),
      appBar: AppBar(
        title: const Text('Student Portal'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              _session.logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.backgroundLight,
                    AppTheme.primaryPurple.withOpacity(0.04),
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 650),
                    child: Card(
                      elevation: 6,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40.0, vertical: 48.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Header Icon representation
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _assessmentStatus == 'approved'
                                    ? Icons.military_tech_rounded
                                    : _assessmentStatus == 'pending_review'
                                        ? Icons.hourglass_top_rounded
                                        : Icons.explore_rounded,
                                size: 56,
                                color: _assessmentStatus == 'approved'
                                    ? AppTheme.success
                                    : AppTheme.primaryPurple,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              _assessmentStatus == 'approved'
                                  ? 'Assessment Complete!'
                                  : _assessmentStatus == 'pending_review'
                                      ? 'Assessment Under Review'
                                      : _assessmentStatus == 'rejected'
                                          ? 'Your assessment needs a retake'
                                          : 'Start your Course Assessment today!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryPurple,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _assessmentStatus == 'approved'
                                  ? 'Your results have been approved. Check your results in the sidebar or click below to view your Course recommendations.'
                                  : _assessmentStatus == 'pending_review'
                                      ? 'Your guidance counselor is currently reviewing your assessment. Please wait for authorization.'
                                      : _assessmentStatus == 'rejected'
                                          ? 'Your counselor has requested you to retake the assessment. Press start to proceed.'
                                          : 'Kickstart your journey by taking our Course Assessment to discover the best course path for you today!',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppTheme.textSecondary,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: 300,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _buttonEnabled
                                    ? () {
                                        if (_assessmentStatus == 'in_progress') {
                                          context.go('/student/assessment');
                                        } else {
                                          _showDisclaimerDialog(context);
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _buttonEnabled ? _buttonColor : Colors.grey.shade200,
                                  foregroundColor: _buttonEnabled 
                                      ? (_buttonColor == AppTheme.primaryYellow ? AppTheme.primaryPurple : Colors.white)
                                      : Colors.grey,
                                  elevation: _buttonEnabled ? 2 : 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _buttonIcon, 
                                      size: 22, 
                                      color: _buttonEnabled 
                                          ? (_buttonColor == AppTheme.primaryYellow ? AppTheme.primaryPurple : Colors.white)
                                          : Colors.grey
                                    ),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        _buttonLabel,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: _buttonEnabled 
                                              ? (_buttonColor == AppTheme.primaryYellow ? AppTheme.primaryPurple : Colors.white)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_assessmentStatus == 'approved') ...[
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: () => context.go('/student/results'),
                                icon: const Icon(Icons.assessment_rounded),
                                label: const Text('View My Results'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _showDisclaimerDialog(BuildContext context) {
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryPurple, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Assessment Acknowledgment',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Before proceeding with the assessment, please read the following:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      _disclaimerBullet(
                        'This assessment is designed to assist you in identifying college courses that best match your interests and assessment results.',
                      ),
                      _disclaimerBullet(
                        'Please answer all questions honestly to obtain more accurate recommendations.',
                      ),
                      _disclaimerBullet(
                        'Your responses will be securely stored and used only within the CourseAlign system.',
                      ),
                      _disclaimerBullet(
                        'The generated recommendations are intended to support your decision-making and should not replace professional guidance.',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'By clicking "I Agree", you acknowledge that you understand the purpose of this assessment and agree to proceed.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      
                      // Checkbox list tile
                      CheckboxListTile(
                        value: isChecked,
                        onChanged: (val) {
                          setDialogState(() {
                            isChecked = val ?? false;
                          });
                        },
                        title: const Text(
                          'I have read and understood the information above.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryPurple,
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: !isChecked
                      ? null
                      : () {
                          _session.hasAgreedToDisclaimer = true;
                          Navigator.pop(context); // Close dialog
                          context.go('/student/student-details');
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('I Agree', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _disclaimerBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5.0),
            child: Icon(Icons.lens, size: 6, color: AppTheme.primaryPurple),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}