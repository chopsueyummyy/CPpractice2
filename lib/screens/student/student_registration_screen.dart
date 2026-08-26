import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../theme/theme_manager.dart';
import '../../utils/api_config.dart';

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  final String registerUrl = ApiConfig.register;

  @override
  void dispose() {
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "Passwords do not match!");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse(registerUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": _idController.text.trim(),
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      } else {
        setState(() => _errorMessage = data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/images/JMC_Background.jpg',
            fit: BoxFit.cover,
          ),
          
          // Tinted Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  AppTheme.primaryPurple.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // ── Theme toggle switch ───────────────────────────
          Positioned(
            top: 24,
            right: 24,
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeManager.themeModeNotifier,
              builder: (context, mode, child) {
                final isDark = mode == ThemeMode.dark;
                return Container(
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    onPressed: ThemeManager.toggleTheme,
                  ),
                );
              },
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withOpacity(0.4)
                            : Colors.white.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withOpacity(0.12)
                              : Colors.white.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 36.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back, color: AppTheme.primaryPurple),
                                      onPressed: () => context.go('/login'),
                                    ),
                                  ),
                                  Image.asset(
                                    'assets/images/Jose_Maria_College_logo.png',
                                    height: 80,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Student Registration',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Create your account to start the assessment',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 24),

                              // ID Number Field
                              TextFormField(
                                controller: _idController,
                                decoration: const InputDecoration(
                                  labelText: 'ID Number',
                                  hintText: '[123456]',
                                  prefixIcon: Icon(Icons.badge),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) => (value == null || value.isEmpty) ? 'Please enter your ID Number' : null,
                              ),
                              const SizedBox(height: 16),

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: '[student.name@jmc.edu.ph]',
                                  prefixIcon: Icon(Icons.email),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter your email';
                                  if (!value.contains('@')) return 'Please enter a valid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (value) => (value == null || value.length < 6) ? 'Password must be at least 6 characters' : null,
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscurePassword,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (value) => (value == null || value.isEmpty) ? 'Please confirm your password' : null,
                              ),

                              if (_errorMessage.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage,
                                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ],

                              const SizedBox(height: 32),

                              _isLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed: _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          ),
        ],
      ),
    );
  }
}
