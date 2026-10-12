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

  List<Map<String, dynamic>> _pendingList = [];
  List<Map<String, dynamic>> _catalogCourses = [];
  bool _isLoadingPending = true;
  Map<String, dynamic>? _selectedStudent;
  List<Map<String, dynamic>> _editableClusterRecs = [];

  String _action = 'approved';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchPendingList();
    _fetchCatalog();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchCatalog() async {
    try {
      final res = await ApiService.getCourseCatalog();
      if (res['status'] == 'success' && mounted) {
        final list = List<Map<String, dynamic>>.from(res['courses'] ?? []);
        setState(() => _catalogCourses = list);
      }
    } catch (_) {}
  }

  Future<void> _fetchPendingList() async {
    if (!mounted) return;
    setState(() => _isLoadingPending = true);

    try {
      final res = await ApiService.getPendingApprovals();
      if (res['status'] == 'success' && mounted) {
        final rawList = res['pending'] as List? ?? [];
        final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        setState(() {
          _pendingList = list;
          _isLoadingPending = false;
        });

        if (widget.extraData != null) {
          _action = widget.extraData!['action'] ?? 'approved';
          final reason = widget.extraData!['reason'] as String?;
          if (reason != null && reason.isNotEmpty) {
            _notesController.text = reason;
          }

          final passedId = widget.extraData!['assessmentId']?.toString();
          final match = list.firstWhere(
            (item) => item['assessmentId']?.toString() == passedId,
            orElse: () => widget.extraData!,
          );
          _selectStudent(match);
        } else if (list.isNotEmpty) {
          _selectStudent(list.first);
        }
      } else {
        if (mounted) setState(() => _isLoadingPending = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPending = false);
    }
  }

  void _selectStudent(Map<String, dynamic> studentData) {
    final rawRecs = studentData['clusterRecommendations'] as List? ?? [];
    final clonedRecs = rawRecs.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    setState(() {
      _selectedStudent = studentData;
      _editableClusterRecs = clonedRecs;
    });
  }

  Future<void> _submit() async {
    if (_selectedStudent == null || _selectedStudent!['assessmentId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student from the list first.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
      return;
    }

    final rawId = _selectedStudent!['assessmentId'];
    final assessmentId = int.tryParse(rawId.toString()) ?? 0;
    final studentName = _selectedStudent!['studentName'] ?? 'the student';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_action == 'approved' ? 'Approve Assessment' : 'Reject Assessment'),
        content: Text(
          _action == 'approved'
              ? 'This will approve $studentName\'s assessment and make results visible to them.'
              : 'This will reject $studentName\'s assessment and ask them to retake it.',
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
      final submitAction = _action == 'rejected' ? 'declined' : _action;
      final data = await ApiService.submitFeedback(
        assessmentId: assessmentId,
        action: submitAction,
        counselorId: _session.counselorId ?? 1,
        feedbackNotes: _notesController.text.trim(),
        curatedRecommendations: _editableClusterRecs,
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

        _notesController.clear();
        _selectedStudent = null;
        _editableClusterRecs = [];
        await _fetchPendingList();
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

  void _showSwapDialog({
    required int clusterIndex,
    required int courseIndex,
    required String currentCourse,
    required String clusterName,
  }) {
    if (_catalogCourses.isEmpty) {
      _fetchCatalog();
    }

    String searchQuery = '';
    Map<String, dynamic>? selectedCatalogCourse;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCatalog = _catalogCourses.where((c) {
              final cName = (c['courseName'] ?? '').toString().toLowerCase();
              final cCode = (c['courseCode'] ?? '').toString().toLowerCase();
              final cClust = (c['clusterName'] ?? '').toString().toLowerCase();
              final isMatchingCluster = cClust == clusterName.toLowerCase();
              if (!isMatchingCluster) return false;

              final q = searchQuery.toLowerCase();
              return q.isEmpty || cName.contains(q) || cCode.contains(q);
            }).toList();

            filteredCatalog.sort((a, b) =>
                (a['courseName'] ?? '').toString().compareTo((b['courseName'] ?? '').toString()));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryPurple),
                  const SizedBox(width: 8),
                  Text(
                    courseIndex < 0 ? 'Add Course to Cluster' : 'Swap Course Recommendation',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cluster: $clusterName',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                    ),
                    if (currentCourse.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Currently Selected: $currentCourse',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search course in $clusterName...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setDialogState(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: filteredCatalog.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: _catalogCourses.isEmpty
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 12),
                                          const Text('Loading course catalog...', style: TextStyle(fontSize: 12)),
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () async {
                                              await _fetchCatalog();
                                              setDialogState(() {});
                                            },
                                            child: const Text('Retry Fetch Catalog'),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'No matching courses found under "$clusterName".',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredCatalog.length,
                              itemBuilder: (context, i) {
                                final item = filteredCatalog[i];
                                final name = (item['courseName'] ?? '').toString();
                                final code = (item['courseCode'] ?? '').toString();
                                final isSelected = selectedCatalogCourse == item || name == currentCourse;

                                final displayText = code.isNotEmpty ? '$code - $name' : name;

                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  tileColor: isSelected ? AppTheme.primaryPurple.withOpacity(0.08) : null,
                                  title: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text(clusterName, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: AppTheme.primaryPurple, size: 18)
                                      : null,
                                  onTap: () {
                                    setDialogState(() => selectedCatalogCourse = item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                  onPressed: selectedCatalogCourse == null
                      ? null
                      : () {
                          final selectedName = (selectedCatalogCourse!['courseName'] ?? '').toString();
                          setState(() {
                            if (clusterIndex >= 0 && clusterIndex < _editableClusterRecs.length) {
                              final currentList = List<String>.from(_editableClusterRecs[clusterIndex]['explore_courses'] ?? []);
                              if (courseIndex >= 0 && courseIndex < currentList.length) {
                                currentList[courseIndex] = selectedName;
                              } else {
                                currentList.add(selectedName);
                              }
                              _editableClusterRecs[clusterIndex]['explore_courses'] = currentList;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                  child: Text(courseIndex < 0 ? 'Add to Cluster' : 'Confirm Swap'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedIdStr = _selectedStudent?['assessmentId']?.toString();

    final bool isValueInItems = _pendingList.any((st) => st['assessmentId']?.toString() == selectedIdStr);
    final String? dropdownValue = isValueInItems ? selectedIdStr : (_pendingList.isNotEmpty ? _pendingList.first['assessmentId']?.toString() : null);

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
                  ? 'Reviewing assessment results & providing guidance'
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Pending List',
            onPressed: _fetchPendingList,
          ),
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
            // ── 1. STUDENT SELECTION DROPDOWN BAR ───────────────────────────
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.how_to_reg_rounded, color: AppTheme.primaryPurple),
                        const SizedBox(width: 8),
                        Text(
                          'Select Student to Review',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple,
                              ),
                        ),
                        const Spacer(),
                        if (_pendingList.isNotEmpty)
                          Chip(
                            label: Text(
                              '${_pendingList.length} Pending Review',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                            ),
                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _isLoadingPending
                        ? const LinearProgressIndicator()
                        : _pendingList.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: AppTheme.success),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'All assessments have been reviewed! No pending students at this time.',
                                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: dropdownValue,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  prefixIcon: const Icon(Icons.person_search_outlined),
                                ),
                                items: _pendingList.map((st) {
                                  final stIdStr = st['assessmentId']?.toString() ?? '';
                                  return DropdownMenuItem<String>(
                                    value: stIdStr,
                                    child: Text(
                                      '${st['studentName'] ?? "Unknown"} (ID: ${st['studentId'] ?? "-"} • ${st['strand'] ?? "N/A"})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (selectedIdStr) {
                                  if (selectedIdStr != null) {
                                    final found = _pendingList.firstWhere(
                                      (element) => element['assessmentId']?.toString() == selectedIdStr,
                                      orElse: () => _pendingList.first,
                                    );
                                    _selectStudent(found);
                                  }
                                },
                              ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 2. FULL STUDENT INSIGHTS CARD ──────────────────────────────
            if (_selectedStudent != null) ...[
              _buildStudentInsightsCard(context, _selectedStudent!),
              const SizedBox(height: 24),
            ],

            // ── 3. DECISION & COUNSELOR NOTES SECTION ──────────────────────
            Text(
              'Your Decision',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
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
              child: Row(
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notes Section
            Text(
              'Counselor\'s Note',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _action == 'approved'
                  ? 'Optional: Add personalized advice or recommendations for the student.'
                  : 'Recommended: Explain why you are rejecting and what the student should review.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: _action == 'approved'
                    ? 'e.g. Great results! Your RIASEC profile clearly aligns with STEM/ICT fields...'
                    : 'e.g. Please retake the assessment carefully. Your answer choices showed inconsistency...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.notes),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Submit Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting || _selectedStudent == null ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
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
                  backgroundColor: _action == 'approved' ? AppTheme.primaryPurple : const Color(0xFFE53E3E),
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

  // ── HELPER WIDGET FOR COMPREHENSIVE STUDENT INSIGHTS ──────────────────────
  Widget _buildStudentInsightsCard(BuildContext context, Map<String, dynamic> st) {
    final scoresRaw = st['scores'];
    final scores = scoresRaw is Map ? Map<String, dynamic>.from(scoresRaw) : <String, dynamic>{};

    final rseRaw = st['rse'];
    final rse = rseRaw is Map ? Map<String, dynamic>.from(rseRaw) : null;

    final cdsesRaw = st['cdses'];
    final cdses = cdsesRaw is Map ? Map<String, dynamic>.from(cdsesRaw) : null;

    final clusterRecsRaw = _editableClusterRecs.isNotEmpty
        ? _editableClusterRecs
        : (st['clusterRecommendations'] as List? ?? []);
    final recsRaw = st['recommendations'] as List? ?? [];
    final recs = recsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                  radius: 28,
                  child: const Icon(Icons.person, color: AppTheme.primaryPurple, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st['studentName']?.toString() ?? 'Student',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Student ID: ${st['studentId'] ?? "-"} • ${st['gradeLevel'] ?? "Grade N/A"} • ${st['strand'] ?? "Strand N/A"}',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      if (st['submittedAt'] != null)
                        Text(
                          'Submitted: ${st['submittedAt']}',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Top Holland Codes Badges
            Text(
              'Holland Code Profile',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (st['primaryType'] != null) _typeChip('Primary: ${st['primaryType']}', st['primaryType'].toString()),
                if (st['secondaryType'] != null) _typeChip('Secondary: ${st['secondaryType']}', st['secondaryType'].toString()),
                if (st['tertiaryType'] != null) _typeChip('Tertiary: ${st['tertiaryType']}', st['tertiaryType'].toString()),
              ],
            ),

            const SizedBox(height: 16),

            // RIASEC Mini Scores Progress Bars
            Text(
              'RIASEC Trait Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
            ),
            const SizedBox(height: 8),
            ...['R', 'I', 'A', 'S', 'E', 'C'].map((trait) {
              final val = double.tryParse((scores[trait] ?? "0").toString()) ?? 0.0;
              final traitColor = AppTheme.riasecColor(trait);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        '$trait - ${AppTheme.riasecName(trait)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (val / 100).clamp(0.0, 1.0),
                          backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(traitColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${val.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: traitColor),
                    ),
                  ],
                ),
              );
            }).toList(),

            // Self-Esteem (RSE) & Career Self-Efficacy (CDSES) Badges
            if (rse != null || cdses != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Psychometric Assessment Badges',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (rse != null)
                    Chip(
                      avatar: Icon(
                        rse['level'].toString().toLowerCase().contains('low')
                            ? Icons.sentiment_dissatisfied
                            : Icons.sentiment_satisfied_alt,
                        color: rse['level'].toString().toLowerCase().contains('low')
                            ? const Color(0xFFE53E3E)
                            : AppTheme.success,
                        size: 16,
                      ),
                      label: Text(
                        'RSE: ${rse['score']}/30 (${rse['level']})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: rse['level'].toString().toLowerCase().contains('low')
                          ? const Color(0xFFE53E3E).withOpacity(0.1)
                          : AppTheme.success.withOpacity(0.1),
                    ),
                  if (cdses != null)
                    Chip(
                      avatar: const Icon(Icons.psychology_outlined, color: AppTheme.primaryPurple, size: 16),
                      label: Text(
                        'CDSES: ${cdses['selfEfficacyLevel'] ?? "N/A"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                    ),
                ],
              ),
            ],

            // ── TOP RECOMMENDED COURSE CLUSTERS (XGBoost + SHAP) ────────────────
            if (clusterRecsRaw.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Top Recommended Course Clusters',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...clusterRecsRaw.map((clusterItem) {
                final cluster = Map<String, dynamic>.from(clusterItem as Map);
                final rank = cluster['rank'] as int? ?? 1;
                final clusterName = (cluster['cluster_name'] ?? 'General Cluster').toString();
                final matchPct = (cluster['match_percentage'] as num?)?.toDouble() ?? 0.0;
                final shapExps = List<Map<String, dynamic>>.from(cluster['shap_explanations'] ?? []);
                final exploreCourses = List<String>.from(cluster['explore_courses'] ?? []);

                Color rankColor;
                if (rank == 1) {
                  rankColor = const Color(0xFFD97706);
                } else if (rank == 2) {
                  rankColor = const Color(0xFF7C3AED);
                } else {
                  rankColor = const Color(0xFF059669);
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: rankColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Chip(
                              label: Text(
                                rank == 1
                                    ? '🥇 Primary Recommendation'
                                    : rank == 2
                                        ? '🥈 Alternative Recommendation'
                                        : '🥉 Additional Recommendation',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: rankColor.withOpacity(0.12),
                              labelStyle: TextStyle(color: rankColor),
                            ),
                            Text(
                              '${matchPct.toStringAsFixed(1)}% Predicted Probability',
                              style: TextStyle(fontWeight: FontWeight.bold, color: rankColor, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          clusterName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        if (shapExps.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 14, color: Colors.purple.shade700),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Why this cluster was recommended:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...shapExps.map((exp) {
                                  final feat = (exp['feature'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            feat,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        const Text(
                                          '+% Impact',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (exploreCourses.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '📌 Recommended Courses under this Cluster:',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add_circle_outline, size: 14, color: AppTheme.primaryPurple),
                                label: const Text('Add Course', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _showSwapDialog(
                                  clusterIndex: clusterRecsRaw.indexOf(clusterItem),
                                  courseIndex: -1, // Add new
                                  currentCourse: '',
                                  clusterName: clusterName,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ...exploreCourses.asMap().entries.map((entry) {
                            final cIdx = entry.key;
                            final crs = entry.value;
                            final cRecIdx = clusterRecsRaw.indexOf(clusterItem);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.dividerColor.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.arrow_right_rounded, size: 16, color: AppTheme.primaryPurple),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        crs,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () => _showSwapDialog(
                                        clusterIndex: cRecIdx,
                                        courseIndex: cIdx,
                                        currentCourse: crs,
                                        clusterName: clusterName,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryPurple.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.swap_horiz_rounded, size: 14, color: AppTheme.primaryPurple),
                                            SizedBox(width: 4),
                                            Text(
                                              'Swap',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE53E3E)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Remove Course',
                                      onPressed: () {
                                        setState(() {
                                          if (cRecIdx >= 0 && cRecIdx < _editableClusterRecs.length) {
                                            final currentList = List<String>.from(_editableClusterRecs[cRecIdx]['explore_courses'] ?? []);
                                            currentList.removeAt(cIdx);
                                            _editableClusterRecs[cRecIdx]['explore_courses'] = currentList;
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ] else if (recs.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Top AI-Recommended Courses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
              ),
              const SizedBox(height: 8),
              Column(
                children: recs.take(3).map((r) {
                  final scoreVal = double.tryParse((r['MatchScore'] ?? '0').toString()) ?? 0.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Rank ${r['Rank'] ?? 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r['CourseName']?.toString() ?? '',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${scoreVal.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String label, String code) {
    final color = AppTheme.riasecColor(code);
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}