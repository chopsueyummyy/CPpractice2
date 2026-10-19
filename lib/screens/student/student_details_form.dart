import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_manager.dart';
import '../../widgets/student_sidebar.dart';

class StudentDetailsForm extends StatefulWidget {
  const StudentDetailsForm({super.key});

  @override
  State<StudentDetailsForm> createState() => _StudentDetailsFormState();
}

class _StudentDetailsFormState extends State<StudentDetailsForm> {
  final _session = SessionManager();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController   = TextEditingController();
  final _lastNameController    = TextEditingController();
  final _middleNameController  = TextEditingController();
  final _suffixController      = TextEditingController();
  final _ageController         = TextEditingController();

  DateTime? _birthdate;
  String?   _gender;
  String?   _strand;
  String?   _gradeLevel;
  bool      _isSubmitting = false;
  bool      _isChecking   = true;

  final _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];
  final _strandOptions = [
    'STEM (Science, Technology, Engineering, Mathematics)',
    'ABM (Accountancy, Business, Management)',
    'HUMSS (Humanities and Social Sciences)',
    'GAS (General Academic Strand)',
    'TVL (Technical-Vocational-Livelihood)',
    'ICT (Information and Communications Technology)',
    'Arts and Design',
    'Not Applicable',
  ];
  final _gradeLevelOptions = ['Grade 11', 'Grade 12'];

  @override
  void initState() {
    super.initState();
    _checkIfAllowed();
  }

  Future<void> _checkIfAllowed() async {
    if (!_session.hasAgreedToDisclaimer && _session.assessmentStatus != 'in_progress') {
      if (mounted) {
        context.go('/student/dashboard');
      }
      return;
    }
    try {
      final data = await ApiService.getStudentStatus(_session.studentId!);
      if (data['status'] == 'success') {
        final asmStatus = data['assessmentStatus'] as String?;
        if (asmStatus == 'pending_review' || asmStatus == 'approved') {
          if (data['assessmentId'] != null) {
            _session.currentAssessmentId =
                int.tryParse(data['assessmentId'].toString());
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  asmStatus == 'pending_review'
                      ? 'Your assessment is awaiting counselor/facilitator review.'
                      : 'Your assessment has already been completed.',
                ),
                backgroundColor: AppTheme.primaryPurple,
              ),
            );
            context.go('/student/dashboard');
          }
        }
      }
    } catch (_) {
      // If check fails, allow through — better than blocking incorrectly
    }
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _suffixController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthdate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthdate = picked;
        final age = DateTime.now().difference(picked).inDays ~/ 365;
        _ageController.text = age.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthdate == null) {
      _snack('Please select your birthdate');
      return;
    }
    if (_gender == null) { _snack('Please select your gender'); return; }
    if (_strand == null) { _snack('Please select your strand'); return; }
    if (_gradeLevel == null) { _snack('Please select your grade level'); return; }

    setState(() => _isSubmitting = true);

    try {
      final piData = await ApiService.savePersonalInfo({
        'studentId':  _session.studentId,
        'firstName':  _firstNameController.text.trim(),
        'lastName':   _lastNameController.text.trim(),
        'middleName': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
        'suffix':     _suffixController.text.trim().isEmpty ? null : _suffixController.text.trim(),
        'birthdate':  '${_birthdate!.year}-${_birthdate!.month.toString().padLeft(2,'0')}-${_birthdate!.day.toString().padLeft(2,'0')}',
        'age':        int.parse(_ageController.text),
        'gender':     _gender,
        'strand':     _strand,
        'gradeLevel': _gradeLevel,
      });

      if (piData['status'] != 'success') throw Exception(piData['message']);
      _session.currentPiId = int.tryParse(piData['piId'].toString());

      if (mounted) context.go('/student/assessment-instructions');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final status = _session.assessmentStatus;
    if (status == 'pending_review' || status == 'approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/student/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isChecking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Information')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: StudentSidebar(currentRoute: '/student/assessment'),
      appBar: AppBar(
        title: const Text('Student Information'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/student/dashboard'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: FormBackgroundPainter(isDark: isDark),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -24,
                      left: -28,
                      child: CustomPaint(
                        size: const Size(60, 60),
                        painter: FormDotGridPainter(
                          color: AppTheme.primaryPurple.withOpacity(isDark ? 0.25 : 0.15),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -24,
                      right: -28,
                      child: CustomPaint(
                        size: const Size(60, 60),
                        painter: FormDotGridPainter(
                          color: AppTheme.primaryPurple.withOpacity(isDark ? 0.25 : 0.15),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1B2E) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                            blurRadius: 36,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.08) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 42),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Let's Get Started",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF1B0748),
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 32,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.04)
                                    : const Color(0xFFF6F0FE),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : const Color(0xFFE9D8FD),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      color: AppTheme.primaryPurple,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Personal Information Required',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: AppTheme.primaryPurple,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Please fill in all fields to proceed to your assessment.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark ? Colors.white70 : const Color(0xFF6B5B95),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput(
                                    controller: _firstNameController,
                                    label: 'First Name *',
                                    icon: Icons.person_outline,
                                    isDark: isDark,
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInput(
                                    controller: _lastNameController,
                                    label: 'Last Name *',
                                    icon: Icons.person_outline,
                                    isDark: isDark,
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInput(
                                    controller: _middleNameController,
                                    label: 'Middle Name (Optional)',
                                    icon: Icons.person_outline,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildInput(
                                    controller: _suffixController,
                                    label: 'Suffix (Optional)',
                                    icon: Icons.text_fields_rounded,
                                    isDark: isDark,
                                    hint: 'e.g., Jr., Sr., II',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: InkWell(
                                    onTap: _selectBirthdate,
                                    borderRadius: BorderRadius.circular(14),
                                    child: InputDecorator(
                                      decoration: _inputDecoration(
                                        label: 'Birthdate *',
                                        icon: Icons.calendar_today_outlined,
                                        isDark: isDark,
                                        suffixIcon: _birthdate != null
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () => setState(() {
                                                  _birthdate = null;
                                                  _ageController.clear();
                                                }),
                                              )
                                            : null,
                                      ),
                                      child: Text(
                                        _birthdate != null
                                            ? '${_birthdate!.day}/${_birthdate!.month}/${_birthdate!.year}'
                                            : 'Select birthdate',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _birthdate != null
                                              ? (isDark ? Colors.white : AppTheme.textPrimary)
                                              : (isDark ? Colors.white54 : AppTheme.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _buildInput(
                                    controller: _ageController,
                                    label: 'Age *',
                                    icon: Icons.cake_outlined,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      final a = int.tryParse(v ?? '');
                                      if (a == null || a < 10 || a > 100) return 'Invalid';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _buildDropdown(
                              label: 'Gender *',
                              icon: Icons.person_outline,
                              value: _gender,
                              options: _genderOptions,
                              isDark: isDark,
                              onChanged: (v) => setState(() => _gender = v),
                            ),
                            const SizedBox(height: 18),
                            _buildDropdown(
                              label: 'Strand *',
                              icon: Icons.school_outlined,
                              value: _strand,
                              options: _strandOptions,
                              isDark: isDark,
                              onChanged: (v) => setState(() => _strand = v),
                            ),
                            const SizedBox(height: 18),
                            _buildDropdown(
                              label: 'Grade Level *',
                              icon: Icons.star_outline_rounded,
                              value: _gradeLevel,
                              options: _gradeLevelOptions,
                              isDark: isDark,
                              onChanged: (v) => setState(() => _gradeLevel = v),
                            ),
                            const SizedBox(height: 36),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: _isSubmitting
                                  ? const Center(child: CircularProgressIndicator())
                                  : Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.primaryPurple,
                                            const Color(0xFF3B1BA5),
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
                                      child: ElevatedButton(
                                        onPressed: _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Continue to Assessment',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => context.go('/student/dashboard'),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: AppTheme.primaryPurple.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.arrow_back_rounded, color: AppTheme.primaryPurple, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Return to Dashboard',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryPurple,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: isDark ? Colors.white54 : const Color(0xFF6B5B95), size: 20),
      suffixIcon: suffixIcon,
      labelStyle: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.white60 : const Color(0xFF6B5B95),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFFAF8FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2D9F3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2D9F3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.primaryPurple, width: 1.8),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
      decoration: _inputDecoration(label: label, icon: icon, isDark: isDark, hint: hint),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> options,
    required bool isDark,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : AppTheme.textPrimary),
      dropdownColor: isDark ? const Color(0xFF262238) : Colors.white,
      decoration: _inputDecoration(label: label, icon: icon, isDark: isDark),
      hint: Text('Select $label', style: TextStyle(fontSize: 14, color: isDark ? Colors.white54 : AppTheme.textSecondary)),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Please select $label' : null,
    );
  }
}

class FormBackgroundPainter extends CustomPainter {
  final bool isDark;

  FormBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF13101E), const Color(0xFF1B162C), const Color(0xFF161224)]
          : [const Color(0xFFF9F6FF), const Color(0xFFF3EDFF), const Color(0xFFEBE2FF)],
    );

    final bgPaint = Paint()..shader = bgGradient.createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final wave1Path = Path();
    wave1Path.moveTo(size.width * 0.35, 0);
    wave1Path.quadraticBezierTo(
      size.width * 0.7, size.height * 0.25,
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
  bool shouldRepaint(covariant FormBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class FormDotGridPainter extends CustomPainter {
  final Color color;

  FormDotGridPainter({required this.color});

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
  bool shouldRepaint(covariant FormDotGridPainter oldDelegate) => oldDelegate.color != color;
}