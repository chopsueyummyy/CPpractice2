import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/counselor_sidebar.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  List<Map<String, dynamic>> _pending = [];
  bool _isLoading = true;
  String _sortBy = 'date';
  bool _sortAscending = false;
  String _filterStatus = 'all';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getPendingApprovals();
      if (data['status'] == 'success') {
        setState(() => _pending = List<Map<String, dynamic>>.from(data['pending']));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _pending.where((a) {
      if (_searchController.text.isNotEmpty) {
        final s = _searchController.text.toLowerCase();
        final name = (a['studentName'] ?? '').toString().toLowerCase();
        final id   = (a['studentId'] ?? '').toString().toLowerCase();
        if (!name.contains(s) && !id.contains(s)) return false;
      }
      if (_filterStatus == 'recent') {
        final submitted = DateTime.tryParse(a['submittedAt'] ?? '');
        if (submitted == null) return false;
        return DateTime.now().difference(submitted).inHours <= 24;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      int cmp = 0;
      if (_sortBy == 'name') {
        cmp = (a['studentName'] ?? '').compareTo(b['studentName'] ?? '');
      } else {
        final aDate = DateTime.tryParse(a['submittedAt'] ?? '') ?? DateTime(2000);
        final bDate = DateTime.tryParse(b['submittedAt'] ?? '') ?? DateTime(2000);
        cmp = aDate.compareTo(bDate);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  // Navigate to student_feedback_screen with all needed data
  void _goToFeedback(Map<String, dynamic> approval, String action) {
    context.go('/guidance-counselor/ai-feedback', extra: {
      'action':       action,
      'assessmentId': int.tryParse(approval['assessmentId'].toString()) ?? 0,
      'studentName':  approval['studentName'],
      'studentId':    approval['studentId'],
      'primaryType':  approval['primaryType'],
      'secondaryType': approval['secondaryType'],
      'tertiaryType':  approval['tertiaryType'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '/guidance-counselor/pending-approvals'),
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPending),
          IconButton(icon: const Icon(Icons.home),
            onPressed: () => context.go('/guidance-counselor/dashboard')),
        ],
      ),
      body: Column(
        children: [
          // Search & filters
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.backgroundWhite,
            child: Column(children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by student name or ID...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchController.clear()))
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Sort By',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'date', child: Text('Date')),
                      DropdownMenuItem(value: 'name', child: Text('Student Name')),
                    ],
                    onChanged: (v) => setState(() => _sortBy = v ?? 'date'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                  onPressed: () => setState(() => _sortAscending = !_sortAscending),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Filter',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'recent', child: Text('Recent (24h)')),
                    ],
                    onChanged: (v) => setState(() => _filterStatus = v ?? 'all'),
                  ),
                ),
              ]),
            ]),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_circle_outline, size: 64, color: AppTheme.primaryPurple),
                          const SizedBox(height: 16),
                          Text('No Pending Approvals',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          Text('All assessments have been reviewed.',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        ]),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPending,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final a = filtered[index];
                            final submittedAt = a['submittedAt'] != null
                                ? DateFormat('MMM dd, yyyy • hh:mm a')
                                    .format(DateTime.parse(a['submittedAt']))
                                : '';
                            final scores = a['scores'] as Map<String, dynamic>? ?? {};
                            final recs = List<Map<String, dynamic>>.from(
                                a['recommendations'] ?? []);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.warning.withOpacity(0.1),
                                  child: Icon(Icons.pending, color: AppTheme.warning),
                                ),
                                title: Text(a['studentName'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID: ${a['studentId']}'),
                                    Text('Submitted: $submittedAt',
                                      style: TextStyle(
                                          fontSize: 12, color: AppTheme.textSecondary)),
                                  ]),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Student info
                                        _infoRow('Grade Level', a['gradeLevel'] ?? '-'),
                                        _infoRow('Strand',      a['strand']     ?? '-'),
                                        _infoRow('Gender',      a['gender']     ?? '-'),
                                        const Divider(height: 24),

                                        // RIASEC types
                                        if (a['primaryType'] != null) ...[
                                          Text('RIASEC Profile',
                                            style: Theme.of(context).textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Wrap(spacing: 8, children: [
                                            Chip(
                                              label: Text(
                                                'Primary: ${a['primaryType']}',
                                                style: const TextStyle(fontSize: 11)),
                                              backgroundColor:
                                                  AppTheme.primaryPurple.withOpacity(0.12),
                                              labelStyle:
                                                  TextStyle(color: AppTheme.primaryPurple),
                                            ),
                                            if (a['secondaryType'] != null)
                                              Chip(
                                                label: Text(
                                                  'Secondary: ${a['secondaryType']}',
                                                  style: const TextStyle(fontSize: 11)),
                                                backgroundColor:
                                                    AppTheme.primaryPurple.withOpacity(0.07),
                                                labelStyle:
                                                    TextStyle(color: AppTheme.primaryPurple),
                                              ),
                                            if (a['tertiaryType'] != null)
                                              Chip(
                                                label: Text(
                                                  'Tertiary: ${a['tertiaryType']}',
                                                  style: const TextStyle(fontSize: 11)),
                                                backgroundColor:
                                                    AppTheme.primaryPurple.withOpacity(0.04),
                                                labelStyle:
                                                    TextStyle(color: AppTheme.primaryPurple),
                                              ),
                                          ]),
                                          const SizedBox(height: 16),
                                        ],

                                        // RIASEC scores bar chart
                                        Text('RIASEC Scores',
                                          style: Theme.of(context).textTheme.titleSmall
                                              ?.copyWith(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        ...['R','I','A','S','E','C'].map((t) {
                                          final pct = double.tryParse(
                                              (scores[t] ?? '0').toString()) ?? 0.0;
                                          final color = AppTheme.riasecColor(t);
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Row(children: [
                                              SizedBox(
                                                width: 100,
                                                child: Text(
                                                  '$t - ${AppTheme.riasecName(t)}',
                                                  style: const TextStyle(fontSize: 12))),
                                              Expanded(child: LinearProgressIndicator(
                                                value: pct / 100,
                                                backgroundColor: AppTheme.dividerColor,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(color),
                                                minHeight: 6,
                                              )),
                                              const SizedBox(width: 8),
                                              Text('${pct.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: color)),
                                            ]),
                                          );
                                        }),

                                        // Rosenberg Self-Esteem
                                        if (a['rse'] != null) ...[
                                          const Divider(height: 24),
                                          Text('Self-Esteem Profile (RSE)',
                                            style: Theme.of(context).textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                a['rse']['level'].toString().toLowerCase().contains('low')
                                                    ? Icons.sentiment_very_dissatisfied
                                                    : Icons.sentiment_satisfied_alt,
                                                color: a['rse']['level'].toString().toLowerCase().contains('low')
                                                    ? const Color(0xFFE53E3E)
                                                    : AppTheme.success,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Score: ${a['rse']['score']} / 30 (${a['rse']['level']})',
                                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ],

                                        // MBI-SS Burnout
                                        if (a['mbi'] != null) ...[
                                          const Divider(height: 24),
                                          Text('Academic Burnout Profile (MBI-SS)',
                                            style: Theme.of(context).textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Burnout Status: ${a['mbi']['burnoutStatus']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: a['mbi']['burnoutStatus'].toString().toLowerCase().contains('high')
                                                  ? const Color(0xFFE53E3E)
                                                  : a['mbi']['burnoutStatus'].toString().toLowerCase().contains('mod')
                                                      ? AppTheme.warning
                                                      : AppTheme.success,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '• Emotional Exhaustion: ${a['mbi']['exScore']} (${a['mbi']['exLevel']})\n'
                                            '• Cynicism: ${a['mbi']['cyScore']} (${a['mbi']['cyLevel']})\n'
                                            '• Professional Efficacy: ${a['mbi']['efScore']} (${a['mbi']['efLevel']})',
                                            style: const TextStyle(fontSize: 12, height: 1.4),
                                          ),
                                        ],

                                        // Recommendations
                                        if (recs.isNotEmpty) ...[
                                          const Divider(height: 24),
                                          Text('Recommended Courses & AI Explanations',
                                            style: Theme.of(context).textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          ...recs.map((rec) {
                                            final explanation = rec['Explanation'] ?? '';
                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.5)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ListTile(
                                                    leading: CircleAvatar(
                                                      backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                                      child: const Icon(Icons.school, color: AppTheme.primaryPurple, size: 20),
                                                    ),
                                                    title: Text(
                                                      rec['CourseName'] ?? '',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                    ),
                                                    subtitle: Text(
                                                      '${rec['CourseCode']} • ${AppTheme.riasecName(rec['RIASECCategory'] ?? '')}',
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                    trailing: Text(
                                                      'Rank ${rec['Rank']}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: AppTheme.primaryPurple,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  if (explanation.isNotEmpty)
                                                    Container(
                                                      width: double.infinity,
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryPurple.withOpacity(0.04),
                                                        borderRadius: const BorderRadius.only(
                                                          bottomLeft: Radius.circular(12),
                                                          bottomRight: Radius.circular(12),
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(Icons.lightbulb_outline, size: 16, color: Colors.purple.shade700),
                                                              const SizedBox(width: 8),
                                                              Text(
                                                                'Why Recommended (AI Analysis):',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.purple.shade900,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 6),
                                                          Text(
                                                            explanation,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              height: 1.4,
                                                              color: Colors.purple.shade900,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],

                                        const SizedBox(height: 16),

                                        // Action buttons → go to feedback screen
                                        Row(children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () => _goToFeedback(a, 'rejected'),
                                              icon: const Icon(Icons.close),
                                              label: const Text('Reject'),
                                              style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFFE53E3E)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _goToFeedback(a, 'approved'),
                                              icon: const Icon(Icons.check),
                                              label: const Text('Approve'),
                                            ),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}