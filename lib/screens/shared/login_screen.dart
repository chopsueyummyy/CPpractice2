import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_manager.dart';
import '../../utils/api_config.dart';

class LoginScreen extends StatefulWidget {
  final String portalType;

  const LoginScreen({
    super.key,
    this.portalType = 'student',
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _primaryController = TextEditingController();
  final _passwordController = TextEditingController();
  late String _userType;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';
  Timer? _cooldownTimer;
  int _cooldownRemaining = 0;

  final String apiUrl = ApiConfig.login;

  @override
  void initState() {
    super.initState();
    _userType = widget.portalType;
    // Auto-login logic: If a session exists, teleport to the dashboard!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = SessionManager();
      if (session.studentId != null && session.role == 'student') {
        context.go('/student/dashboard');
      } else if (session.counselorId != null) {
        if (session.role == 'psychometrician') {
          context.go('/psychometrician/dashboard');
        } else if (session.role == 'guidance_counselor') {
          context.go('/guidance-counselor/dashboard');
        }
      } else if (session.adminId != null && (session.role == 'super_admin' || session.role == 'admin')) {
        context.go('/admin/dashboard');
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _primaryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldownRemaining = seconds;
      _errorMessage = 'Too many failed login attempts. Please wait $_cooldownRemaining seconds.';
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _cooldownRemaining = 0;
            _errorMessage = '';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cooldownRemaining--;
            _errorMessage = 'Too many failed login attempts. Please wait $_cooldownRemaining seconds.';
          });
        }
      }
    });
  }

  Future<void> _handleLogin() async {
    if (_cooldownRemaining > 0) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final Map<String, String> body = {
        "role":     _userType,
        "password": _passwordController.text.trim(),
      };

      if (_userType == 'student') {
        body['student_id'] = _primaryController.text.trim();
      } else {
        body['email'] = _primaryController.text.trim();
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 429 || data['remainingSeconds'] != null) {
        final remaining = (data['remainingSeconds'] as num?)?.toInt() ?? 60;
        _startCooldownTimer(remaining);
      } else if (data['status'] == 'success') {
        if (!mounted) return;

        final session = SessionManager();

        if (_userType == 'student') {
          session.setStudent({
            'studentId':        data['studentId']?.toString(),
            'firstName':        data['firstName'],
            'lastName':         data['lastName'],
            'assessmentStatus': data['assessmentStatus'],
          });
          context.go('/student/dashboard');
        } else {
          session.setCounselor({
            'counselorId': data['counselorId'],
            'firstName':   data['firstName'],
            'lastName':    data['lastName'],
            'role':        data['role'],
          });
          final returnedRole = (data['role'] ?? '').toString();
          if (returnedRole == 'super_admin' || returnedRole == 'admin') {
            context.go('/admin/dashboard');
          } else if (returnedRole == 'psychometrician') {
            context.go('/psychometrician/dashboard');
          } else {
            context.go('/guidance-counselor/dashboard');
          }
        }
      } else if (data['status'] == 'otp_pending') {
          if (!mounted) return;
          context.go('/verify-otp', extra: {
              'email': data['email'],
              'counselorId': data['counselorId'],
              'portalType': _userType,
          });
      } else {
        setState(() => _errorMessage = data['message'] ?? 'Login failed');
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
          // ── Background Image ──────────────────────────────
          Image.asset(
            'assets/images/JMC_Background.jpg',
            fit: BoxFit.cover,
          ),

          // ── Dark overlay for readability ──────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.45),
                  AppTheme.primaryPurple.withOpacity(0.75),
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

          // ── Login Card ────────────────────────────────────
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
                            : Colors.white.withOpacity(0.55), // More translucent for real glass effect
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32.0, vertical: 36.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // College Logo
                              Center(
                                child: Image.asset(
                                  'assets/images/Jose_Maria_College_logo.png',
                                  height: 100, // Adjust size as needed
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ── Title with Montserrat ──
                              Text(
                                _userType == 'admin' 
                                    ? 'Admin Portal' 
                                    : (_userType == 'staff' ? 'Staff Portal' : 'CourseAlign'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 28, // Slightly larger and bold
                                  fontWeight: FontWeight.w900,
                                  color: _userType == 'admin' ? AppTheme.error : AppTheme.primaryPurple,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Subtitle keeps the default theme font
                              Text(
                                _userType == 'admin' 
                                    ? 'Secure Administration Access' 
                                    : (_userType == 'staff' 
                                        ? 'Guidance Counselor & Facilitator Access' 
                                        : 'Career Assessment and Course Recommendation System'),
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userType == 'admin' 
                                    ? 'Administrators Only!' 
                                    : (_userType == 'staff' 
                                        ? 'Career Counseling & Testing Suite' 
                                        : 'v3.0 - Student Portal'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _userType == 'admin' ? AppTheme.error.withOpacity(0.5) : AppTheme.primaryPurple.withOpacity(0.5),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 28),

                          // ── ID / Email field ──────────────────────────────────
                          TextFormField(
                            controller: _primaryController,
                            decoration: InputDecoration(
                              labelText: _userType == 'student'
                                  ? 'Student ID'
                                  : 'Email',
                              prefixIcon: Icon(
                                _userType == 'student'
                                    ? Icons.badge
                                    : Icons.email,
                              ),
                            ),
                            keyboardType: _userType == 'student'
                                ? TextInputType.number
                                : TextInputType.emailAddress,
                            inputFormatters: _userType == 'student'
                                ? [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ]
                                : null,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _userType == 'student'
                                    ? 'Please enter your Student ID'
                                    : 'Please enter your email';
                              }
                              if (_userType == 'student') {
                                if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                                  return 'Student ID must contain digits only';
                                }
                                if (value.trim().length > 6) {
                                  return 'Student ID cannot exceed 6 digits';
                                }
                              } else if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Password field ────────────────────────────────────
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppTheme.textSecondary,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          // ── Error message ─────────────────────────────────────
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppTheme.error.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppTheme.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage,
                                      style: const TextStyle(
                                          color: AppTheme.error, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ── Login Button ──────────────────────────────────────
                          _isLoading
                              ? const Center(
                                  child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _cooldownRemaining > 0 ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _userType == 'admin' ? AppTheme.error : AppTheme.primaryPurple,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: Text(
                                    _cooldownRemaining > 0
                                        ? 'Locked (Wait ${_cooldownRemaining}s)'
                                        : 'Login',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),

                          // ── Register Button (Student only) ────────────────────
                          if (_userType == 'student') ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text(
                                "Don't have an account? Register",
                                style: TextStyle(
                                  color: AppTheme.primaryPurple.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
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
        ),
      ),
    ],
      ),
    );
  }
}