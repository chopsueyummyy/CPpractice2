import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
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
  bool      _isChecking   = true; // blocks form until status check done

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

  // Block access if student already has a pending or approved assessment.
  // Only rejected students (or first-timers) are allowed through.
  Future<void> _checkIfAllowed() async {
    try {
      final data = await ApiService.getStudentStatus(_session.studentId!);
      if (data['status'] == 'success') {
        final asmStatus = data['assessmentStatus'] as String?;
        if (asmStatus == 'pending_review' || asmStatus == 'approved') {
          // Store assessmentId in session if available
          if (data['assessmentId'] != null) {
            _session.currentAssessmentId =
                int.tryParse(data['assessmentId'].toString());
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  asmStatus == 'pending_review'
                      ? 'Your assessment is awaiting counselor review.'
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
      // Step 1: Save personal info
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
    // Synchronous Security Check: Immediately block if SessionManager says locked
    final status = _session.assessmentStatus;
    if (status == 'pending_review' || status == 'approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/student/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Block form entirely until server status check is done
    if (_isChecking) {
      return Scaffold(
        appBar: AppBar(title: const Text('Personal Information')),
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
      body: Container(
        color: AppTheme.backgroundLight,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Card(
                elevation: 6,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Notification
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: AppTheme.primaryPurple, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Personal Information Required',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Please fill in all fields to proceed to your assessment.',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // First Name & Last Name side-by-side
                        Row(
                          children: [
                            Expanded(
                              child: _field(_firstNameController, 'First Name *', Icons.person,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _field(_lastNameController, 'Last Name *', Icons.person,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Middle Name & Suffix side-by-side
                        Row(
                          children: [
                            Expanded(
                              child: _field(_middleNameController, 'Middle Name (Optional)', Icons.person_outline),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _field(_suffixController, 'Suffix (Optional)', Icons.text_fields,
                                  hint: 'e.g., Jr., Sr., II'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Birthdate & Age side-by-side
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: _selectBirthdate,
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Birthdate *',
                                    prefixIcon: const Icon(Icons.calendar_today),
                                    suffixIcon: _birthdate != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
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
                                      color: _birthdate != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: _field(_ageController, 'Age *', Icons.cake,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final a = int.tryParse(v ?? '');
                                    if (a == null || a < 10 || a > 100) return 'Invalid';
                                    return null;
                                  }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Gender full width
                        _dropdown('Gender *', Icons.person_outline, _gender, _genderOptions,
                            (v) => setState(() => _gender = v)),
                        const SizedBox(height: 16),

                        // Strand full width
                        _dropdown('Strand *', Icons.school, _strand, _strandOptions,
                            (v) => setState(() => _strand = v)),
                        const SizedBox(height: 16),

                        // Grade Level full width
                        _dropdown('Grade Level *', Icons.grade, _gradeLevel, _gradeLevelOptions,
                            (v) => setState(() => _gradeLevel = v)),
                        const SizedBox(height: 36),

                        // Submission Actions
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _isSubmitting
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: _submit,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Continue to Assessment'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryPurple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/student/dashboard'),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Return to Dashboard'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator,
    );
  }

  Widget _dropdown(
    String label,
    IconData icon,
    String? value,
    List<String> options,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      hint: Text('Select $label'),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
      validator: (v) => v == null || v.isEmpty ? 'Please select $label' : null,
    );
  }
}