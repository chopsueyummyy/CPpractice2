import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/counselor_sidebar.dart';
import '../../widgets/jmcfi_badge.dart';

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

                                        // Career Decision Self-Efficacy
                                        if (a['cdses'] != null) ...[
                                          const Divider(height: 24),
                                          Text('Career Decision Self-Efficacy Profile (CDSES-SF)',
                                            style: Theme.of(context).textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Self-Efficacy Level: ${a['cdses']['selfEfficacyLevel']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: a['cdses']['selfEfficacyLevel'].toString().toLowerCase().contains('high')
                                                  ? AppTheme.success
                                                  : a['cdses']['selfEfficacyLevel'].toString().toLowerCase().contains('mod')
                                                      ? AppTheme.warning
                                                      : const Color(0xFFE53E3E),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '• Total Score: ${a['cdses']['totalScore'].toInt()} / 125\n'
                                            '• SA: ${a['cdses']['saScore']} | OI: ${a['cdses']['oiScore']} | '
                                            'GS: ${a['cdses']['gsScore']} | PL: ${a['cdses']['plScore']} | '
                                            'PS: ${a['cdses']['psScore']}',
                                            style: const TextStyle(fontSize: 12, height: 1.4),
                                          ),
                                        ],

                                        // Recommendations
                                        if ((a['clusterRecommendations'] as List?)?.isNotEmpty ?? false) ...[
                                          const Divider(height: 24),
                                          Text('Top Recommended Course Clusters',
                                            style: Theme.of(context).textTheme.titleSmall
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 8),
                                          ...(a['clusterRecommendations'] as List).map((clusterItem) {
                                            final cluster = clusterItem as Map<String, dynamic>;
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
                                                            rank == 1 ? '🥇 Primary Recommendation' : rank == 2 ? '🥈 Alternative Recommendation' : '🥉 Additional Recommendation',
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
                                                              final impact = (exp['impact_score'] as num?)?.toDouble() ?? 0.0;
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
                                                                    Text(
                                                                      '+% Impact',
                                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
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
                                                      Text(
                                                        '📌 Recommended Courses under this Cluster:',
                                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      ...exploreCourses.map((crs) {
                                                        final raw = crs.toString();
                                                        final isJmcfi = JmcfiBadge.isJmcfiCourse(raw);
                                                        final cleanName = JmcfiBadge.cleanCourseTitle(raw);

                                                        return Container(
                                                          margin: const EdgeInsets.only(bottom: 6),
                                                          height: 48,
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(8),
                                                            border: Border.all(
                                                              color: const Color(0xFFE2E8F0),
                                                              width: 1.0,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.arrow_right_rounded,
                                                                size: 15,
                                                                color: AppTheme.primaryPurple,
                                                              ),
                                                              const SizedBox(width: 6),
                                                              Expanded(
                                                                child: Tooltip(
                                                                  message: cleanName,
                                                                  child: Text(
                                                                    cleanName,
                                                                    maxLines: 2,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: const TextStyle(
                                                                      fontSize: 11.5,
                                                                      fontWeight: FontWeight.w500,
                                                                      height: 1.25,
                                                                      color: Color(0xFF1E293B),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              if (isJmcfi) ...[
                                                                const SizedBox(width: 6),
                                                                const JmcfiBadge(),
                                                              ],
                                                            ],
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
                                                    title: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            JmcfiBadge.cleanCourseTitle(rec['CourseName'] ?? ''),
                                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                          ),
                                                        ),
                                                        if (JmcfiBadge.isJmcfiCourse(rec['CourseName'] ?? '')) ...[
                                                          const SizedBox(width: 8),
                                                          const JmcfiBadge(),
                                                        ],
                                                      ],
                                                    ),
                                                    subtitle: Text(
                                                      '${rec['CourseCode']} • ${AppTheme.riasecName(rec['RIASECCategory'] ?? '')}',
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                    trailing: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.end,
                                                      children: [
                                                        Text(
                                                          'Rank ${rec['Rank']}',
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: AppTheme.primaryPurple,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          '✦ Match: ${(double.tryParse((rec['MatchScore'] ?? '0').toString()) ?? 0.0).toStringAsFixed(1)}%',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w600,
                                                            color: AppTheme.textSecondary,
                                                          ),
                                                        ),
                                                      ],
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
                                                          _buildShapChart(rec['shapWeights'] as Map<String, dynamic>?, Colors.purple.shade700),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],

                                        const SizedBox(height: 16),

                                        // General Insights Box based on RIASEC, RSE, and CDSES
                                        _buildGeneralInsightsBox(a),

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

  Widget _buildShapChart(Map<String, dynamic>? weights, Color color) {
    if (weights == null || weights.isEmpty) return const SizedBox.shrink();
    
    final featureOrder = ['Strand', 'R', 'I', 'A', 'S', 'E', 'C', 'RSES', 'MBI'];
    final labels = {
      'Strand': 'Strand Compatibility',
      'R': 'Realistic (R)',
      'I': 'Investigative (I)',
      'A': 'Artistic (A)',
      'S': 'Social (S)',
      'E': 'Enterprising (E)',
      'C': 'Conventional (C)',
      'RSES': 'Rosenberg Self-Esteem',
      'MBI': 'Career Self-Efficacy',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                '✦ AI Diagnostics (SHAP Feature Attribution):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...featureOrder.map((feat) {
            final weightVal = (feat == 'MBI' && weights[feat] == null) ? weights['CDSES'] : weights[feat];
            final weight = double.tryParse(weightVal?.toString() ?? '0.0') ?? 0.0;
            if (weight == 0.0) return const SizedBox.shrink();
            
            const double maxRef = 3.0;
            final double absoluteVal = weight.abs();
            final double barWidthRatio = (absoluteVal / maxRef).clamp(0.02, 1.0);
            
            final bool isPositive = weight > 0;
            final Color barColor = isPositive ? AppTheme.success : const Color(0xFFE53E3E);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      labels[feat] ?? feat,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: barWidthRatio,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '${isPositive ? "+" : ""}${weight.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: barColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // GENERAL ASSESSMENT INSIGHTS & SUMMARY CONTAINER
  // -------------------------------------------------------------
  Widget _buildGeneralInsightsBox(Map<String, dynamic> a) {
    final primary = (a['primaryType'] ?? '').toString().toUpperCase();
    final secondary = (a['secondaryType'] ?? '').toString().toUpperCase();
    final tertiary = (a['tertiaryType'] ?? '').toString().toUpperCase();
    final scores = (a['scores'] as Map<String, dynamic>?) ?? {};
    final rse = a['rse'] as Map<String, dynamic>?;
    final cdses = a['cdses'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Container Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: AppTheme.primaryPurple, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'General Assessment Insights & Summary',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Holistic synthesis across RIASEC Interests, Self-Esteem (RSE), and Decision Self-Efficacy (CDSES)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 1. RIASEC Interest Profile Insights
            _buildRiasecInsightSection(primary, secondary, tertiary, scores),

            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 2. Self-Esteem Profile (RSE) Insights
            _buildRseInsightSection(rse),

            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 3. Career Decision Self-Efficacy (CDSES) Insights
            _buildCdsesInsightSection(cdses),
          ],
        ),
      ),
    );
  }

  // 1. RIASEC Section
  Widget _buildRiasecInsightSection(
    String primary,
    String secondary,
    String tertiary,
    Map<String, dynamic> scores,
  ) {
    final codeList = [primary, secondary, tertiary].where((t) => t.isNotEmpty).toList();
    final hollandCode = codeList.join();

    final pName = AppTheme.riasecName(primary);
    final sName = secondary.isNotEmpty ? AppTheme.riasecName(secondary) : '';
    final tName = tertiary.isNotEmpty ? AppTheme.riasecName(tertiary) : '';

    final pScoreVal = scores[primary] != null ? (double.tryParse(scores[primary].toString()) ?? 0.0) : null;
    final sScoreVal = secondary.isNotEmpty && scores[secondary] != null ? (double.tryParse(scores[secondary].toString()) ?? 0.0) : null;
    final tScoreVal = tertiary.isNotEmpty && scores[tertiary] != null ? (double.tryParse(scores[tertiary].toString()) ?? 0.0) : null;

    final pScoreStr = pScoreVal != null ? '${pScoreVal.toStringAsFixed(1)}%' : '';
    final sScoreStr = sScoreVal != null ? '${sScoreVal.toStringAsFixed(1)}%' : '';
    final tScoreStr = tScoreVal != null ? '${tScoreVal.toStringAsFixed(1)}%' : '';

    final traitMap = {
      'R': 'hands-on, practical execution and concrete problem-solving',
      'I': 'intellectual curiosity, scientific research, and deep analytical inquiry',
      'A': 'creative expression, intuitive exploration, and original conceptualization',
      'S': 'empathetic interpersonal communication, service, and collaborative teamwork',
      'E': 'persuasion, organizational leadership, initiative, and goal achievement',
      'C': 'structured processes, data precision, systematic organization, and high attention to detail',
    };

    final pTrait = traitMap[primary] ?? 'vocational interest';
    final sTrait = traitMap[secondary] ?? '';

    String narrative = '';
    if (primary.isNotEmpty && secondary.isNotEmpty) {
      narrative =
          'The student demonstrates a dominant preference for $pTrait ($pName${pScoreStr.isNotEmpty ? " $pScoreStr" : ""}), complemented by $sTrait ($sName${sScoreStr.isNotEmpty ? " $sScoreStr" : ""}). They thrive in learning environments that combine structured procedures with meaningful analytical inquiry and cooperative goals.';
    } else if (primary.isNotEmpty) {
      narrative =
          'The student shows an orientation centered on $pTrait ($pName${pScoreStr.isNotEmpty ? " $pScoreStr" : ""}), suggesting highest motivation in tasks requiring focused application of this domain.';
    } else {
      narrative = 'RIASEC interest profile is currently being finalized.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 16, color: AppTheme.primaryPurple),
            const SizedBox(width: 6),
            const Text(
              '1. RIASEC Interest Profile Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
              ),
              child: Text(
                'Dominant Code: $hollandCode ($pName • $sName • $tName)',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
              ),
            ),
            if (pScoreStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.riasecColor(primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$primary: $pScoreStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.riasecColor(primary)),
                ),
              ),
            if (sScoreStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.riasecColor(secondary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$secondary: $sScoreStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.riasecColor(secondary)),
                ),
              ),
            if (tScoreStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.riasecColor(tertiary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$tertiary: $tScoreStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.riasecColor(tertiary)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          narrative,
          style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF334155)),
        ),
      ],
    );
  }

  // 2. RSE Section
  Widget _buildRseInsightSection(Map<String, dynamic>? rse) {
    if (rse == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 16, color: Colors.pink.shade400),
              const SizedBox(width: 6),
              const Text(
                '2. Self-Esteem Profile (RSE) Insights',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Self-Esteem assessment data is not yet recorded for this student.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    final score = (rse['score'] as num?)?.toInt() ?? 0;
    final level = (rse['level'] ?? '').toString();
    final isLow = level.toLowerCase().contains('low') || (score > 0 && score < 15);
    final isHigh = level.toLowerCase().contains('high') || score >= 25;

    final badgeColor = isLow
        ? const Color(0xFFE53E3E)
        : isHigh
            ? AppTheme.success
            : const Color(0xFF10B981);

    String rseNarrative;
    if (isLow) {
      rseNarrative =
          'The student exhibits low self-esteem ($score / 30), which can indicate susceptibility to academic anxiety, impostor feelings, or hesitance in challenging programs. The counselor is advised to offer positive affirmation and confidence-building support alongside academic guidance.';
    } else if (isHigh) {
      rseNarrative =
          'The student reflects high self-esteem ($score / 30), representing strong self-assurance, personal optimism, and emotional resilience. They are well-equipped to manage academic setbacks and actively advocate for their goals.';
    } else {
      rseNarrative =
          'The student displays a healthy, balanced self-esteem profile ($score / 30 - Normal). This indicates sound emotional stability and realistic self-regard, providing a reliable emotional foundation for post-secondary transitions.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite_rounded, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            const Text(
              '2. Self-Esteem Profile (RSE) Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLow ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                size: 14,
                color: badgeColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Score: $score / 30 ($level)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rseNarrative,
          style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF334155)),
        ),
      ],
    );
  }

  // 3. CDSES Section
  Widget _buildCdsesInsightSection(Map<String, dynamic>? cdses) {
    if (cdses == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_rounded, size: 16, color: AppTheme.primaryPurple),
              const SizedBox(width: 6),
              const Text(
                '3. Career Decision Self-Efficacy (CDSES) Insights',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Career Decision Self-Efficacy assessment data is not yet recorded for this student.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    final totalScore = (cdses['totalScore'] as num?)?.toDouble() ?? 0.0;
    final level = (cdses['selfEfficacyLevel'] ?? '').toString();
    final sa = (cdses['saScore'] as num?)?.toDouble() ?? 0.0;
    final oi = (cdses['oiScore'] as num?)?.toDouble() ?? 0.0;
    final gs = (cdses['gsScore'] as num?)?.toDouble() ?? 0.0;
    final pl = (cdses['plScore'] as num?)?.toDouble() ?? 0.0;
    final ps = (cdses['psScore'] as num?)?.toDouble() ?? 0.0;

    final isHigh = level.toLowerCase().contains('high') || totalScore >= 85;
    final isMod = level.toLowerCase().contains('mod') || (totalScore >= 60 && totalScore < 85);

    final badgeColor = isHigh
        ? AppTheme.success
        : isMod
            ? AppTheme.warning
            : const Color(0xFFE53E3E);

    final subscales = [
      {'name': 'Self-Appraisal', 'code': 'SA', 'score': sa},
      {'name': 'Occupational Information', 'code': 'OI', 'score': oi},
      {'name': 'Goal Selection', 'code': 'GS', 'score': gs},
      {'name': 'Planning', 'code': 'PL', 'score': pl},
      {'name': 'Problem Solving', 'code': 'PS', 'score': ps},
    ];
    subscales.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final highest = subscales.first;
    final lowest = subscales.last;

    String cdsesNarrative;
    if (isHigh) {
      cdsesNarrative =
          'The student demonstrates high career decision self-efficacy (${totalScore.toInt()} / 125), indicating strong confidence in making independent vocational decisions. They show exceptional strength in ${highest['name']} (${(highest['score'] as double).toStringAsFixed(2)}/5.0), demonstrating strong self-direction and ability to resolve educational dilemmas.';
    } else if (isMod) {
      cdsesNarrative =
          'The student displays moderate career decision self-efficacy (${totalScore.toInt()} / 125). While capable, lower relative confidence in ${lowest['name']} (${(lowest['score'] as double).toStringAsFixed(2)}/5.0) suggests they may feel hesitant about finalizing choices or gathering career requirements, presenting an optimal entry point for guidance.';
    } else {
      cdsesNarrative =
          'The student reflects low career decision self-efficacy (${totalScore.toInt()} / 125), signaling noticeable uncertainty or anxiety about post-secondary options. Priority counseling focused on ${lowest['name']} (${(lowest['score'] as double).toStringAsFixed(2)}/5.0) is recommended to build clarity and confidence.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.explore_rounded, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            const Text(
              '3. Career Decision Self-Efficacy (CDSES) Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withOpacity(0.3)),
              ),
              child: Text(
                'Total: ${totalScore.toInt()} / 125 ($level)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Highest: ${highest['code']} (${(highest['score'] as double).toStringAsFixed(2)})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Lowest: ${lowest['code']} (${(lowest['score'] as double).toStringAsFixed(2)})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          cdsesNarrative,
          style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}