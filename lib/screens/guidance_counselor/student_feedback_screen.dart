import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/counselor_sidebar.dart';

class StudentFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;

  const StudentFeedbackScreen({super.key, this.extraData});

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  final _session = SessionManager();
  final _notesController = TextEditingController();
  String _action = 'approved';
  bool _isSubmitting = false;

  // These come from pending_approvals_screen via extra data
  int?    _assessmentId;
  String? _studentName;
  String? _studentId;
  String? _primaryType;
  String? _secondaryType;
  String? _tertiaryType;

  @override
  void initState() {
    super.initState();
    if (widget.extraData != null) {
      _action       = widget.extraData!['action'] ?? 'approved';
      _assessmentId = widget.extraData!['assessmentId'];
      _studentName  = widget.extraData!['studentName'];
      _studentId    = widget.extraData!['studentId'];
      _primaryType   = widget.extraData!['primaryType'];
      _secondaryType = widget.extraData!['secondaryType'];
      _tertiaryType  = widget.extraData!['tertiaryType'];

      // Pre-fill rejection reason if passed
      final reason = widget.extraData!['reason'] as String?;
      if (reason != null && reason.isNotEmpty) {
        _notesController.text = reason;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_assessmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assessment selected. Please go back and select one.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_action == 'approved' ? 'Approve Assessment' : 'Reject Assessment'),
        content: Text(
          _action == 'approved'
              ? 'This will approve ${_studentName ?? "the student"}\'s assessment and make results visible to them.'
              : 'This will reject ${_studentName ?? "the student"}\'s assessment and ask them to retake it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: _action == 'rejected'
                ? ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53E3E))
                : null,
            child: Text(_action == 'approved' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final data = await ApiService.approveRejectAssessment(
        assessmentId: _assessmentId!,
        action: _action,
        counselorId: _session.counselorId!,
        notes: _notesController.text.trim(),
      );

      if (!mounted) return;

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _action == 'approved'
                  ? 'Assessment approved! The student can now view their results.'
                  : 'Assessment rejected. The student will be asked to retake.',
            ),
            backgroundColor: _action == 'approved' ? AppTheme.success : const Color(0xFFE53E3E),
          ),
        );
        context.go('/guidance-counselor/pending-approvals');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Something went wrong.'),
            backgroundColor: const Color(0xFFE53E3E),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit. Check your connection.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
    }
    
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '/guidance-counselor/ai-feedback'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Student Feedback'),
            Text(
              _action == 'approved'
                  ? 'Approving assessment results'
                  : 'Rejecting assessment — student will retake',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Dashboard',
            onPressed: () => context.go('/guidance-counselor/dashboard'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Student info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                      radius: 28,
                      child: Icon(Icons.person, color: AppTheme.primaryPurple, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _studentName ?? 'Student',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold),
                          ),
                          if (_studentId != null)
                            Text('Student ID: $_studentId',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          if (_primaryType != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(spacing: 8, children: [
                                Chip(
                                  label: Text('Primary: $_primaryType',
                                    style: const TextStyle(fontSize: 11)),
                                  backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                  labelStyle: TextStyle(color: AppTheme.primaryPurple),
                                ),
                                if (_secondaryType != null)
                                  Chip(
                                    label: Text('Secondary: $_secondaryType',
                                      style: const TextStyle(fontSize: 11)),
                                    backgroundColor: AppTheme.primaryPurple.withOpacity(0.05),
                                    labelStyle: TextStyle(color: AppTheme.primaryPurple),
                                  ),
                                if (_tertiaryType != null)
                                  Chip(
                                    label: Text('Tertiary: $_tertiaryType',
                                      style: const TextStyle(fontSize: 11)),
                                    backgroundColor: AppTheme.primaryPurple.withOpacity(0.02),
                                    labelStyle: TextStyle(color: AppTheme.primaryPurple),
                                  ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Decision
            Text('Your Decision',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'approved',
                  label: Text('Approve'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: 'rejected',
                  label: Text('Reject'),
                  icon: Icon(Icons.cancel_outlined),
                ),
              ],
              selected: {_action},
              onSelectionChanged: (v) => setState(() => _action = v.first),
            ),
            const SizedBox(height: 8),

            // Decision explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _action == 'approved'
                    ? AppTheme.success.withOpacity(0.08)
                    : const Color(0xFFE53E3E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(
                  _action == 'approved' ? Icons.check_circle : Icons.info_outline,
                  color: _action == 'approved' ? AppTheme.success : const Color(0xFFE53E3E),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _action == 'approved'
                        ? 'The student will be able to view their career assessment results and course recommendations.'
                        : 'The student will be asked to retake the assessment. Your notes below will help them understand why.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _action == 'approved' ? AppTheme.success : const Color(0xFFE53E3E),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // Notes
            Text('Counselor Notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _action == 'approved'
                  ? 'Optional: Add any notes or guidance for the student.'
                  : 'Recommended: Explain why you are rejecting and what the student should do.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: _action == 'approved'
                    ? 'e.g. Great results! Your career and self-efficacy profile clearly shows a strength in...'
                    : 'e.g. Please retake the assessment more carefully. Some answers seemed inconsistent...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_action == 'approved' ? Icons.check : Icons.close),
                label: Text(
                  _isSubmitting
                      ? 'Submitting...'
                      : _action == 'approved'
                          ? 'Approve & Notify Student'
                          : 'Reject & Notify Student',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _action == 'approved'
                      ? AppTheme.primaryPurple
                      : const Color(0xFFE53E3E),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/guidance-counselor/pending-approvals'),
                child: const Text('Back to Pending Approvals'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}