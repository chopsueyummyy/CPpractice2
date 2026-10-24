import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/glass_card.dart';
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
        return 'Awaiting Counselor/Facilitator Review';
      case 'approved':
        return 'Assessment Completed';
      case 'rejected':
      case 'declined':
        return 'Retake Assessment';
      default:
        return 'Start Test';
    }
  }

  bool get _buttonEnabled {
    return _assessmentStatus == null || 
           _assessmentStatus == 'rejected' || 
           _assessmentStatus == 'declined' || 
           _assessmentStatus == 'in_progress';
  }

  IconData get _buttonIcon {
    switch (_assessmentStatus) {
      case 'in_progress':
        return Icons.play_circle_fill;
      case 'pending_review':
        return Icons.hourglass_top_rounded;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
      case 'declined':
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
      case 'declined':
        return AppTheme.warning;
      default:
        return AppTheme.primaryYellow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      drawer: StudentSidebar(currentRoute: '/student/dashboard'),
      appBar: AppBar(
        title: const Text('Student Portal'),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeManager.themeModeNotifier,
              builder: (context, mode, child) {
                return Icon(mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode);
              },
            ),
            tooltip: 'Toggle Theme',
            onPressed: ThemeManager.toggleTheme,
          ),
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
          : Stack(
              children: [
                // 1. Ambient Fluid Wave Background
                Positioned.fill(
                  child: CustomPaint(
                    painter: DashboardBackgroundPainter(isDark: isDark),
                  ),
                ),

                // 2. Main Center Content
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Decorative Dot Grid - Left Side
                        Positioned(
                          left: -30,
                          top: 40,
                          child: CustomPaint(
                            size: const Size(60, 60),
                            painter: DotGridPainter(color: AppTheme.primaryPurple.withOpacity(isDark ? 0.2 : 0.15)),
                          ),
                        ),
                        // Decorative Dot Grid - Right Side
                        Positioned(
                          right: -30,
                          bottom: 40,
                          child: CustomPaint(
                            size: const Size(60, 60),
                            painter: DotGridPainter(color: AppTheme.primaryPurple.withOpacity(isDark ? 0.2 : 0.15)),
                          ),
                        ),

                        // Main Floating Elevation Card
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPurple.withOpacity(isDark ? 0.3 : 0.08),
                                  blurRadius: 36,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                              border: Border.all(
                                color: isDark 
                                    ? Colors.white.withOpacity(0.08) 
                                    : AppTheme.primaryPurple.withOpacity(0.06),
                                width: 1.5,
                              ),
                            ),
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 20.0 : 40.0,
                                vertical: isMobile ? 32.0 : 48.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Main Title
                                  if (_assessmentStatus != null && _assessmentStatus != 'not_started')
                                    Text(
                                      _assessmentStatus == 'approved'
                                          ? 'Assessment Complete!'
                                          : _assessmentStatus == 'pending_review'
                                              ? 'Assessment Under Review'
                                              : 'Your assessment needs a retake',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: isMobile ? 32 : 44,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : const Color(0xFF1B0748),
                                        letterSpacing: -1.2,
                                        height: 1.1,
                                      ),
                                    )
                                  else
                                    RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: isMobile ? 32 : 44,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1.2,
                                          height: 1.1,
                                        ),
                                      children: [
                                        TextSpan(
                                          text: 'Start your Course\n',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF1B0748),
                                          ),
                                        ),
                                        TextSpan(
                                          text: 'Assessment today!',
                                          style: TextStyle(
                                            color: isDark ? AppTheme.lilac : AppTheme.primaryPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 16),

                                // Accent Divider Line
                                Container(
                                  width: 36,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Subtitle Description
                                Text(
                                  _assessmentStatus == 'approved'
                                      ? 'Your results have been approved. Check your results in the sidebar or click below to view your Course recommendations.'
                                      : _assessmentStatus == 'pending_review'
                                          ? 'Your guidance counselor/facilitator is currently reviewing your assessment. Please wait for authorization.'
                                          : (_assessmentStatus == 'rejected' || _assessmentStatus == 'declined')
                                              ? 'Your counselor/facilitator has requested you to retake the assessment. Press start to proceed.'
                                              : 'Kickstart your journey by taking our Course Assessment to discover the best course path for you today!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: isDark ? Colors.white70 : const Color(0xFF6B5B95),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // ── Action Button Area ──
                                if (_assessmentStatus == 'approved')
                                  Container(
                                    constraints: const BoxConstraints(maxWidth: 320),
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.primaryPurple,
                                          Color(0xFF3B1BA5),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primaryPurple.withOpacity(0.35),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: () => context.go('/student/results'),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 24),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Icon(
                                                Icons.assessment_rounded,
                                                size: 22,
                                                color: Colors.white,
                                              ),
                                              Text(
                                                'View My Results',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    constraints: BoxConstraints(
                                      maxWidth: _assessmentStatus == 'pending_review' ? 440 : 320,
                                    ),
                                    height: 54,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      gradient: _buttonEnabled
                                          ? const LinearGradient(
                                              colors: [
                                                AppTheme.primaryPurple,
                                                Color(0xFF3B1BA5),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            )
                                          : null,
                                      color: !_buttonEnabled
                                          ? (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200)
                                          : null,
                                      border: !_buttonEnabled
                                          ? Border.all(
                                              color: isDark ? Colors.white.withOpacity(0.12) : Colors.grey.shade300,
                                              width: 1,
                                            )
                                          : null,
                                      boxShadow: _buttonEnabled
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.primaryPurple.withOpacity(0.35),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(30),
                                        onTap: _buttonEnabled
                                            ? () {
                                                if (_assessmentStatus == 'in_progress') {
                                                  context.go('/student/assessment');
                                                } else {
                                                  _showDisclaimerDialog(context);
                                                }
                                              }
                                            : null,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Icon(
                                                _buttonIcon,
                                                size: 22,
                                                color: _buttonEnabled
                                                    ? Colors.white
                                                    : (isDark ? Colors.white70 : const Color(0xFF6B5B95)),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      _buttonLabel == 'Start Test' ? 'Start Assessment' : _buttonLabel,
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w700,
                                                        color: _buttonEnabled
                                                            ? Colors.white
                                                            : (isDark ? Colors.white70 : const Color(0xFF6B5B95)),
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (_buttonEnabled)
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                  color: Colors.white,
                                                )
                                              else
                                                const SizedBox(width: 22),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── CUSTOM BACKGROUND PAINTER ────────────────────────────────────────────────
class DashboardBackgroundPainter extends CustomPainter {
  final bool isDark;

  DashboardBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base background gradient
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF100E19), const Color(0xFF191528), const Color(0xFF12101F)]
          : [const Color(0xFFF9F6FF), const Color(0xFFF3EDFF), const Color(0xFFEBE2FF)],
    );

    final bgPaint = Paint()..shader = bgGradient.createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Top Right Soft Purple Wave/Bubble
    final wave1Path = Path();
    wave1Path.moveTo(size.width * 0.4, 0);
    wave1Path.quadraticBezierTo(
      size.width * 0.75, size.height * 0.25,
      size.width, size.height * 0.15,
    );
    wave1Path.lineTo(size.width, 0);
    wave1Path.close();

    final wave1Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryPurple.withOpacity(isDark ? 0.12 : 0.09),
          AppTheme.primaryPurple.withOpacity(isDark ? 0.03 : 0.02),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(rect);

    canvas.drawPath(wave1Path, wave1Paint);

    // Bottom Ambient Fluid Wave
    final wave2Path = Path();
    wave2Path.moveTo(0, size.height * 0.75);
    wave2Path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.65,
      size.width * 0.7, size.height * 0.85,
    );
    wave2Path.quadraticBezierTo(
      size.width * 0.85, size.height * 0.95,
      size.width, size.height * 0.88,
    );
    wave2Path.lineTo(size.width, size.height);
    wave2Path.lineTo(0, size.height);
    wave2Path.close();

    final wave2Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryPurple.withOpacity(isDark ? 0.18 : 0.12),
          AppTheme.primaryPurple.withOpacity(isDark ? 0.04 : 0.03),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(rect);

    canvas.drawPath(wave2Path, wave2Paint);
  }

  @override
  bool shouldRepaint(covariant DashboardBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

// ── DECORATIVE DOT GRID PAINTER ──────────────────────────────────────────────
class DotGridPainter extends CustomPainter {
  final Color color;

  DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const double radius = 2.5;
    const double spacing = 12.0;

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 5; col++) {
        final offset = Offset(col * spacing, row * spacing);
        canvas.drawCircle(offset, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) => oldDelegate.color != color;
}