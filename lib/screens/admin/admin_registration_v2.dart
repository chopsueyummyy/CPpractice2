import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class AdminRegistrationV2 extends StatefulWidget {
  const AdminRegistrationV2({super.key});

  @override
  State<AdminRegistrationV2> createState() => _AdminRegistrationV2State();
}

class _AdminRegistrationV2State extends State<AdminRegistrationV2> {
  final _formKey = GlobalKey<FormState>();
  final _session = SessionManager();
  
  String _targetType = 'student';
  bool _isSubmitting = false;

  // Form Fields
  final _fnController = TextEditingController();
  final _lnController = TextEditingController();
  final _idController = TextEditingController(); // Separate ID for students
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Student Specific
  String _selectedStrand = 'STEM';
  String _selectedGrade = 'Grade 11';
  String _selectedSex = 'Male';
  int _age = 16;

  final List<String> _strands = ['STEM', 'HUMSS', 'ABM', 'GAS', 'ICT', 'HE'];
  final List<String> _grades = ['Grade 11', 'Grade 12'];

  @override
  void dispose() {
    _fnController.dispose();
    _lnController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService.manageAdminUser({
        'action': 'create',
        'targetType': _targetType,
        'studentId': _idController.text.trim(), // Include the new ID field
        'firstName': _fnController.text.trim(),
        'lastName': _lnController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
        'strand': _selectedStrand,
        'gradeLevel': _selectedGrade,
        'sex': _selectedSex,
        'age': _age,
        'reqAdminId': _session.adminId,
        'reqRoleId': _session.roleId,
      });

      if (res['status'] == 'success') {
        _showSnackBar(res['message'], AppTheme.success);
        _resetForm();
      } else {
        _showSnackBar(res['message'], AppTheme.error);
      }
    } catch (e) {
      _showSnackBar('Creation failed. Check connection.', AppTheme.error);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _fnController.clear();
    _lnController.clear();
    _idController.clear();
    _emailController.clear();
    _passwordController.clear();
    setState(() {
      _selectedStrand = 'STEM';
      _selectedGrade = 'Grade 11';
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildRoleSelector(),
            const SizedBox(height: 24),
            _buildRegistrationForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Registration System',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryPurple,
          ),
        ),
        const Text('Onboard new users into the Citadel environment.'),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Center(
      child: SegmentedButton<String>(
        segments: [
          const ButtonSegment(value: 'student', label: Text('Student'), icon: Icon(Icons.school)),
          const ButtonSegment(value: 'counselor', label: Text('Counselor'), icon: Icon(Icons.psychology)),
          if (_session.roleId == 4)
            const ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings)),
        ],
        selected: {_targetType},
        onSelectionChanged: (v) => setState(() {
          _targetType = v.first;
          _resetForm();
        }),
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_targetType != 'student') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fnController,
                        decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.badge_outlined)),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lnController,
                        decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.badge_outlined)),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              
              if (_targetType == 'student') ...[
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID Number',
                    prefixIcon: Icon(Icons.numbers_outlined),
                  ),
                  validator: (v) => v!.isEmpty ? 'Student ID Required' : null,
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _targetType == 'student' ? 'Institutional Email' : 'Professional Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Temporary Password', prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
                validator: (v) => v!.length < 6 ? 'Too short' : null,
              ),
              
              if (_targetType == 'student') ...[
                const SizedBox(height: 24),
                Text(
                  'Note: Full profile details will be provided by the student during their first login.',
                  style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
              
              const SizedBox(height: 32),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.person_add_alt_1),
                  label: Text('Create ${_targetType.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
