import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';

class OtpScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;

  const OtpScreen({super.key, this.extraData});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  late String _email;

  @override
  void initState() {
    super.initState();
    _email = widget.extraData?['email'] ?? '';
    if (_email.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/verify_otp.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _email, "otp": otp}),
      );

      final data = jsonDecode(response.body);

      if (data['status'] == 'success') {
        final session = SessionManager();
        
        if (data['role'] == 'super_admin' || data['role'] == 'admin') {
          session.setAdmin({
            'adminId':   data['adminId'],
            'firstName': data['firstName'],
            'lastName':  data['lastName'],
            'role':      data['role'],
          });
          context.go('/admin/dashboard');
        } else {
          // Revert to Counselor (Legacy or fallback)
          session.setCounselor({
            'counselorId': data['counselorId'],
            'firstName':   data['firstName'],
            'lastName':    data['lastName'],
          });
          context.go('/guidance-counselor/dashboard');
        }
      } else {
        setState(() => _errorMessage = data['message'] ?? 'Invalid OTP code.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Security Verification'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryPurple,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.security, size: 64, color: AppTheme.primaryPurple),
                const SizedBox(height: 24),
                Text(
                  'Two-Step Verification',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Please enter the 6-digit security code sent to $_email',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: "",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 2),
                    )
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage, style: const TextStyle(color: AppTheme.error), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Verify Code', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('Cancel & Return to Login', style: TextStyle(color: AppTheme.textSecondary)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
