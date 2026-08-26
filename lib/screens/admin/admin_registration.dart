import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/admin_api.dart';

class AdminRegistration extends StatefulWidget {
  const AdminRegistration({super.key});
  @override
  State<AdminRegistration> createState() => _AdminRegistrationState();
}

class _AdminRegistrationState extends State<AdminRegistration> {
  final _formKey = GlobalKey<FormState>();
  String _role = 'student';
  final _idCtrl = TextEditingController();
  final _fnCtrl = TextEditingController();
  final _lnCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confPassCtrl = TextEditingController();
  bool _isLoading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confPassCtrl.text) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match!'), backgroundColor: AppTheme.error));
       return;
    }
    
    setState(() => _isLoading = true);
    final data = <String, dynamic>{
      'role': _role,
      'firstName': _fnCtrl.text,
      'lastName': _lnCtrl.text,
      'email': _emailCtrl.text,
      'password': _passCtrl.text.isNotEmpty ? _passCtrl.text : 'password123',
    };
    if (_role == 'student' && _idCtrl.text.isNotEmpty) {
      data['id'] = _idCtrl.text;
    }

    final res = await AdminApiService.registerUser(data);
    setState(() => _isLoading = false);
    
    if (!mounted) return;
    if (res['status'] == 'success') {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: AppTheme.success));
       _formKey.currentState!.reset();
       _idCtrl.clear();
       _passCtrl.clear();
       _confPassCtrl.clear();
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Create New Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(labelText: 'User Role', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('Student')),
                    DropdownMenuItem(value: 'counselor', child: Text('Guidance Counselor')),
                  ],
                  onChanged: (v) => setState(() => _role = v!),
                ),
                const SizedBox(height: 16),
                
                if (_role == 'student') ...[
                  TextFormField(
                    controller: _idCtrl,
                    decoration: const InputDecoration(labelText: 'Student ID (e.g. 2024001)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Student ID represents how they login.' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fnCtrl,
                        decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lnCtrl,
                        decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passCtrl,
                        decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _confPassCtrl,
                        decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
                        obscureText: true,
                        validator: (v) => _passCtrl.text.isNotEmpty && v != _passCtrl.text ? 'Passwords must match' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _isLoading 
                   ? const Center(child: CircularProgressIndicator())
                   : ElevatedButton.icon(
                       style: ElevatedButton.styleFrom(
                         minimumSize: const Size(double.infinity, 56),
                         backgroundColor: AppTheme.primaryPurple,
                         foregroundColor: Colors.white,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                       onPressed: _submit,
                       icon: const Icon(Icons.app_registration),
                       label: const Text('Register User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
