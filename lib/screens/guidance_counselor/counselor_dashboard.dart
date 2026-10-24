import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_manager.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/counselor_sidebar.dart';
import '../../widgets/glass_card.dart';

class CounselorDashboard extends StatefulWidget {
  const CounselorDashboard({super.key});

  @override
  State<CounselorDashboard> createState() => _CounselorDashboardState();
}

class _CounselorDashboardState extends State<CounselorDashboard> {
  final _session = SessionManager();
  bool get isPsych => _session.isPsychometrician;
  String get prefix => isPsych ? '/psychometrician' : '/guidance-counselor';
  String _timeFilter = 'all';
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getDashboardStats(_timeFilter);
      if (data['status'] == 'success') {
        setState(() => _stats = data);
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPsych = _session.isPsychometrician;
    final prefix = isPsych ? '/psychometrician' : '/guidance-counselor';

    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '$prefix/dashboard'),
      appBar: AppBar(
        title: Text(isPsych ? 'Psychometrician Dashboard' : 'Counselor/Facilitator Dashboard'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeManager.themeModeNotifier,
              builder: (context, mode, child) {
                return Icon(mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode);
              },
            ),
            tooltip: 'Toggle Theme',
            onPressed: ThemeManager.toggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _session.logout();
              context.go('/staff/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Banner Card
              GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.primaryPurple.withOpacity(0.15),
                      child: Icon(
                        isPsych ? Icons.analytics_outlined : Icons.psychology,
                        size: 28,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${_session.counselorFirstName ?? (isPsych ? 'Psychometrician' : 'Counselor/Facilitator')}!',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPsych
                                ? 'Monitor live testing sessions, calibrate AI models, and endorse evaluations.'
                                : 'Track student cumulative records, demographic trends, and counseling caseloads.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Time filter pills
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('Today')),
                  ButtonSegment(value: 'week', label: Text('This Week')),
                  ButtonSegment(value: 'month', label: Text('This Month')),
                  ButtonSegment(value: 'all', label: Text('All Time')),
                ],
                selected: {_timeFilter},
                onSelectionChanged: (s) {
                  setState(() => _timeFilter = s.first);
                  _loadStats();
                },
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                () {
                  if (!isPsych) {
                    return _buildCounselorDashboard(context);
                  }
                  final strandStats = List<Map<String, dynamic>>.from(_stats['strandStats'] ?? []);
                  final riasecStats = List<Map<String, dynamic>>.from(_stats['riasecStats'] ?? []);
                  final rseStats = List<Map<String, dynamic>>.from(_stats['rseStats'] ?? []);
                  final cdsesStats = List<Map<String, dynamic>>.from(_stats['cdsesStats'] ?? []);
                  final recentActivity = List<Map<String, dynamic>>.from(_stats['recentActivity'] ?? []);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      final pendingLabel = isPsych ? 'Pending Evaluations' : 'Endorsements Awaiting Action';
                      final pendingValue = '${isPsych ? (_stats['pendingPsychometricianCount'] ?? _stats['pendingCount'] ?? 0) : (_stats['pendingCounselorCount'] ?? _stats['pendingCount'] ?? 0)}';
                      final card3Label = isPsych ? 'Assessments Today' : 'Results Released';
                      final card3Value = '${isPsych ? (_stats['assessmentsToday'] ?? 0) : (_stats['approved'] ?? _stats['feedbackGiven'] ?? 0)}';
                      final card3Icon = isPsych ? Icons.insert_chart_outlined_rounded : Icons.verified_outlined;
                      final card3Route = isPsych ? '$prefix/monitoring' : '$prefix/student-records';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top 4 Stat Cards
                          if (isWide)
                            Row(
                              children: [
                                Expanded(child: _buildSparklineStatCard(
                                  context, pendingLabel, pendingValue,
                                  isPsych ? Icons.assignment_turned_in_outlined : Icons.mark_email_unread_outlined, const Color(0xFFFF9800),
                                  () => context.go('$prefix/pending-approvals'),
                                  sparklineType: 'wave',
                                )),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSparklineStatCard(
                                  context, 'Total Students', '${_stats['totalStudents'] ?? 0}',
                                  Icons.people_alt_outlined, const Color(0xFF2196F3),
                                  () => context.go('$prefix/student-records'),
                                  sparklineType: 'bars',
                                )),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSparklineStatCard(
                                  context, card3Label, card3Value,
                                  card3Icon, const Color(0xFF4CAF50),
                                  () => context.go(card3Route),
                                  sparklineType: 'bars',
                                )),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSparklineStatCard(
                                  context, isPsych ? 'Live Now' : 'Live Assessments', '${_stats['inProgress'] ?? 0}',
                                  Icons.sensors_rounded, AppTheme.primaryPurple,
                                  () => context.go('$prefix/monitoring'),
                                  sparklineType: 'wave',
                                )),
                              ],
                            )
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildSparklineStatCard(
                                      context, pendingLabel, pendingValue,
                                      isPsych ? Icons.assignment_turned_in_outlined : Icons.mark_email_unread_outlined, const Color(0xFFFF9800),
                                      () => context.go('$prefix/pending-approvals'),
                                      sparklineType: 'wave',
                                    )),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSparklineStatCard(
                                      context, 'Total Students', '${_stats['totalStudents'] ?? 0}',
                                      Icons.people_alt_outlined, const Color(0xFF2196F3),
                                      () => context.go('$prefix/student-records'),
                                      sparklineType: 'bars',
                                    )),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(child: _buildSparklineStatCard(
                                      context, card3Label, card3Value,
                                      card3Icon, const Color(0xFF4CAF50),
                                      () => context.go(card3Route),
                                      sparklineType: 'bars',
                                    )),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSparklineStatCard(
                                      context, isPsych ? 'Live Now' : 'Live Assessments', '${_stats['inProgress'] ?? 0}',
                                      Icons.sensors_rounded, AppTheme.primaryPurple,
                                      () => context.go('$prefix/monitoring'),
                                      sparklineType: 'wave',
                                    )),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 24),

                          // Row 1: Dominant Career Interests (RIASEC) & Strand Distribution - EQUAL HEIGHT
                          if (isWide)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _buildRiasecCard(riasecStats)),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildStrandCard(strandStats)),
                                ],
                              ),
                            )
                          else ...[
                            _buildRiasecCard(riasecStats),
                            const SizedBox(height: 20),
                            _buildStrandCard(strandStats),
                          ],
                          const SizedBox(height: 24),

                          // Row 2: RSE Profile & Career Self-Efficacy Profile - EQUAL HEIGHT
                          if (isWide)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _buildRseCard(rseStats)),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildCdsesCard(cdsesStats)),
                                ],
                              ),
                            )
                          else ...[
                            _buildRseCard(rseStats),
                            const SizedBox(height: 20),
                            _buildCdsesCard(cdsesStats),
                          ],
                          const SizedBox(height: 24),

                          // Row 3: Recent Student Activities Table - FULL WIDTH
                          _buildRecentActivityTable(recentActivity),
                          const SizedBox(height: 24),

                          // Row 4: Top Recommended Course Clusters & Quick Actions Grid
                          if (isWide)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: _buildTopClustersCard()),
                                  const SizedBox(width: 20),
                                  Expanded(child: _buildQuickActionsGrid()),
                                ],
                              ),
                            )
                          else ...[
                            _buildTopClustersCard(),
                            const SizedBox(height: 20),
                            _buildQuickActionsGrid(),
                          ],
                        ],
                      );
                    },
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GUIDANCE COUNSELOR DASHBOARD: STUDENT RECORDS, DEMOGRAPHICS & CASELOAD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCounselorDashboard(BuildContext context) {
    final strandStats = List<Map<String, dynamic>>.from(_stats['strandStats'] ?? []);
    final gradeStats = List<Map<String, dynamic>>.from(_stats['gradeStats'] ?? []);
    final genderStats = List<Map<String, dynamic>>.from(_stats['genderStats'] ?? []);
    final priorityEndorsements = List<Map<String, dynamic>>.from(_stats['priorityEndorsements'] ?? []);
    final recentReleased = List<Map<String, dynamic>>.from(_stats['recentReleased'] ?? []);

    final pendingCounselor = '${_stats['pendingCounselorCount'] ?? _stats['pendingCount'] ?? 0}';
    final totalStudents = '${_stats['totalStudents'] ?? 0}';
    final approvedCount = '${_stats['approved'] ?? 0}';
    final activeStrands = '${_stats['activeStrandsCount'] ?? strandStats.length}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top 4 Counselor Stat Cards
            if (isWide)
              Row(
                children: [
                  Expanded(child: _buildSparklineStatCard(
                    context, 'Total Registered Students', totalStudents,
                    Icons.people_alt_outlined, const Color(0xFF2196F3),
                    () => context.go('$prefix/student-records'),
                    sparklineType: 'bars',
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSparklineStatCard(
                    context, 'Endorsements Awaiting Action', pendingCounselor,
                    Icons.mark_email_unread_outlined, const Color(0xFFFF9800),
                    () => context.go('$prefix/pending-approvals'),
                    sparklineType: 'wave',
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSparklineStatCard(
                    context, 'Advisories Released', approvedCount,
                    Icons.verified_outlined, const Color(0xFF4CAF50),
                    () => context.go('$prefix/student-records'),
                    sparklineType: 'bars',
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSparklineStatCard(
                    context, 'Active Academic Strands', activeStrands,
                    Icons.school_outlined, AppTheme.primaryPurple,
                    () => context.go('$prefix/student-records'),
                    sparklineType: 'wave',
                  )),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSparklineStatCard(
                        context, 'Total Registered Students', totalStudents,
                        Icons.people_alt_outlined, const Color(0xFF2196F3),
                        () => context.go('$prefix/student-records'),
                        sparklineType: 'bars',
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSparklineStatCard(
                        context, 'Endorsements Awaiting Action', pendingCounselor,
                        Icons.mark_email_unread_outlined, const Color(0xFFFF9800),
                        () => context.go('$prefix/pending-approvals'),
                        sparklineType: 'wave',
                      )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSparklineStatCard(
                        context, 'Advisories Released', approvedCount,
                        Icons.verified_outlined, const Color(0xFF4CAF50),
                        () => context.go('$prefix/student-records'),
                        sparklineType: 'bars',
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSparklineStatCard(
                        context, 'Active Strands', activeStrands,
                        Icons.school_outlined, AppTheme.primaryPurple,
                        () => context.go('$prefix/student-records'),
                        sparklineType: 'wave',
                      )),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Row 1: Academic Strand Distribution & Student Demographics
            if (isWide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildCounselorStrandCard(strandStats)),
                    const SizedBox(width: 20),
                    Expanded(child: _buildCounselorCohortCard(gradeStats, genderStats)),
                  ],
                ),
              )
            else ...[
              _buildCounselorStrandCard(strandStats),
              const SizedBox(height: 20),
              _buildCounselorCohortCard(gradeStats, genderStats),
            ],
            const SizedBox(height: 24),

            // Row 2: Priority Endorsements Queue (Ready for Guidance Counseling)
            _buildCounselorPriorityEndorsementsCard(priorityEndorsements),
            const SizedBox(height: 24),

            // Row 3: Recent Released Advisories (Official Releases)
            _buildCounselorRecentReleasedTable(recentReleased),
            const SizedBox(height: 24),

            // Row 4: Counselor Quick Actions
            _buildCounselorQuickActionsGrid(),
          ],
        );
      },
    );
  }

  // Strand Distribution Card (Counselor view)
  // Strand Distribution Card (Counselor view)
  Widget _buildCounselorStrandCard(List<Map<String, dynamic>> rawStrandStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Normalize and aggregate strands (e.g. merge raw "STEM" into full title)
    final Map<String, int> merged = {};
    for (final item in rawStrandStats) {
      final canonical = AppTheme.normalizeStrand(item['strand']?.toString() ?? '');
      final count = (item['count'] is num) ? (item['count'] as num).toInt() : 0;
      merged[canonical] = (merged[canonical] ?? 0) + count;
    }
    final strandStats = merged.entries
        .map((e) => {'strand': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final total = strandStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_rounded, color: AppTheme.primaryPurple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Senior High Academic Strands',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('$prefix/student-records'),
                  child: const Row(
                    children: [
                      Text(
                        'View Directory',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Cumulative student distribution across academic tracks.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (strandStats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No student records found.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              Column(
                children: strandStats.map((item) {
                  final strand = item['strand']?.toString() ?? 'Unassigned';
                  final count = item['count'] as int? ?? 0;
                  final pct = total > 0 ? (count / total) : 0.0;
                  final color = AppTheme.strandColor(strand);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                strand,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$count student(s) (${(pct * 100).toStringAsFixed(1)}%)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: isDark ? Colors.white10 : color.withOpacity(0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Student Cohort Profile (Grade Level & Gender)
  Widget _buildCounselorCohortCard(List<Map<String, dynamic>> gradeStats, List<Map<String, dynamic>> genderStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Defensive client-side deduplication / merging by key in case of identical entries
    final Map<String, int> mergedGrades = {};
    for (final item in gradeStats) {
      final key = item['gradeLevel']?.toString().trim() ?? 'Grade 12';
      final count = (item['count'] is num) ? (item['count'] as num).toInt() : 0;
      mergedGrades[key] = (mergedGrades[key] ?? 0) + count;
    }
    final normalizedGradeStats = mergedGrades.entries
        .map((e) => {'gradeLevel': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final Map<String, int> mergedGenders = {};
    for (final item in genderStats) {
      final key = item['gender']?.toString().trim() ?? 'Not Specified';
      final count = (item['count'] is num) ? (item['count'] as num).toInt() : 0;
      mergedGenders[key] = (mergedGenders[key] ?? 0) + count;
    }
    final normalizedGenderStats = mergedGenders.entries
        .map((e) => {'gender': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final totalGrade = normalizedGradeStats.fold(0, (sum, item) => sum + (item['count'] as int));
    final totalGender = normalizedGenderStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.groups_rounded, color: Color(0xFF2196F3), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Student Demographics & Cohort Profile',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('$prefix/student-records'),
                  child: const Row(
                    children: [
                      Text(
                        'Cumulative Records',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2196F3)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Grade level and gender demographic distribution across registered cohorts.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 18),

            // Grade Level Section
            const Text(
              'GRADE LEVEL REPRESENTATION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF2196F3)),
            ),
            const SizedBox(height: 10),
            if (normalizedGradeStats.isEmpty)
              Text('No grade level data', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
            else
              Row(
                children: normalizedGradeStats.map((item) {
                  final grade = item['gradeLevel']?.toString() ?? 'Grade 12';
                  final count = item['count'] as int? ?? 0;
                  final pct = totalGrade > 0 ? (count / totalGrade * 100).toStringAsFixed(1) : '0';

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF0F7FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(grade, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('$count students', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF2196F3))),
                          Text('$pct% of cohort', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 20),

            // Gender Breakdown Section
            const Text(
              'GENDER DISTRIBUTION',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: Color(0xFF9C27B0)),
            ),
            const SizedBox(height: 10),
            if (normalizedGenderStats.isEmpty)
              Text('No gender data', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
            else
              Row(
                children: normalizedGenderStats.map((item) {
                  final gender = item['gender']?.toString() ?? 'Other';
                  final count = item['count'] as int? ?? 0;
                  final pct = totalGender > 0 ? (count / totalGender * 100).toStringAsFixed(1) : '0';
                  final isMale = gender.toLowerCase() == 'male';
                  final icon = isMale ? Icons.male_rounded : (gender.toLowerCase() == 'female' ? Icons.female_rounded : Icons.person_outline_rounded);
                  final color = isMale ? const Color(0xFF0284C7) : const Color(0xFFE91E63);

                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.04) : color.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(icon, color: color, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(gender, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                                Text('$count ($pct%)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Priority Endorsement Queue (Actionable for Counselor)
  Widget _buildCounselorPriorityEndorsementsCard(List<Map<String, dynamic>> priorityEndorsements) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mark_email_unread_rounded, color: Color(0xFFFF9800), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Priority Endorsement Queue',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9800).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${priorityEndorsements.length} Awaiting Counseling',
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('$prefix/pending-approvals'),
                  child: const Row(
                    children: [
                      Text(
                        'Open Full Queue',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFFF9800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Students screened & endorsed by Psychometrician awaiting Guidance Counselor/Facilitator interview and advisory release.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            if (priorityEndorsements.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.dividerColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 36, color: AppTheme.success.withOpacity(0.8)),
                    const SizedBox(height: 8),
                    const Text(
                      'All Endorsements Completed',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'There are no students currently awaiting counseling action. You are completely caught up!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go('$prefix/pending-approvals'),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Check Endorsed Queue'),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: priorityEndorsements.map((student) {
                  final name = student['studentName']?.toString() ?? 'Student';
                  final studentId = student['studentId']?.toString() ?? '';
                  final strand = student['strand']?.toString() ?? 'N/A';
                  final grade = student['gradeLevel']?.toString() ?? 'Grade 12';
                  final psychNotes = student['psychometricianNotes']?.toString() ?? '';
                  final endorsedAt = student['endorsedAt']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFFF9800).withOpacity(0.15),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('ID: $studentId', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$grade • $strand • Endorsed: $endorsedAt',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => context.go('$prefix/pending-approvals'),
                              icon: const Icon(Icons.rate_review_outlined, size: 16),
                              label: const Text('Review & Counsel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                        if (psychNotes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.dividerColor.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.primaryPurple),
                                const SizedBox(width: 6),
                                const Text(
                                  'Psychometrician Briefing: ',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                ),
                                Expanded(
                                  child: Text(
                                    psychNotes,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // Recent Released Advisories (Counselor view)
  Widget _buildCounselorRecentReleasedTable(List<Map<String, dynamic>> recentReleased) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_edu_rounded, color: Color(0xFF4CAF50), size: 20),
                    SizedBox(width: 8),
                    Text('Recent Official Advisories Released', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('$prefix/student-records'),
                  child: const Row(
                    children: [
                      Text(
                        'View Records Directory',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF4CAF50)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Historical ledger of completed student career guidance consultations and official result releases.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (recentReleased.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No advisories released yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 80),
                    child: DataTable(
                      horizontalMargin: 12,
                      columnSpacing: 24,
                      headingRowHeight: 42,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 54,
                      columns: [
                        DataColumn(label: Text('STUDENT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('STUDENT ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('STRAND & GRADE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('RELEASED DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('COUNSELING ADVICE NOTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                      ],
                      rows: recentReleased.map((item) {
                        final name = item['studentName']?.toString() ?? 'Student';
                        final studentId = item['studentId']?.toString() ?? '';
                        final strand = item['strand']?.toString() ?? 'N/A';
                        final grade = item['gradeLevel']?.toString() ?? 'Grade 12';
                        final date = item['releasedAt']?.toString() ?? '';
                        final notes = item['counselorNotes']?.toString() ?? 'Advice provided';

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: const Color(0xFF4CAF50).withOpacity(0.15),
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2E7D32)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            DataCell(Text(studentId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                            DataCell(Text('$strand ($grade)', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                            DataCell(Text(date, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 240),
                                child: Text(
                                  notes.isNotEmpty ? notes : 'Official Guidance Counseling Released',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  'Released',
                                  style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 2x2 Counselor Quick Actions Grid
  Widget _buildCounselorQuickActionsGrid() {
    return Card(
      elevation: 0,
      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppTheme.primaryPurple, size: 20),
                SizedBox(width: 8),
                Text('Guidance & Records Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _quickActionButton(
                        'Endorsed Student Queue',
                        Icons.mark_email_unread_outlined,
                        const Color(0xFFFEF3C7),
                        const Color(0xFFD97706),
                        () => context.go('$prefix/pending-approvals'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickActionButton(
                        'Student Cumulative Records',
                        Icons.badge_outlined,
                        const Color(0xFFE0F2FE),
                        const Color(0xFF0284C7),
                        () => context.go('$prefix/student-records'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _quickActionButton(
                        'Student Status Monitoring',
                        Icons.monitor_heart_outlined,
                        const Color(0xFFF3E8FF),
                        AppTheme.primaryPurple,
                        () => context.go('$prefix/monitoring'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickActionButton(
                        'Released Advisories Ledger',
                        Icons.verified_outlined,
                        const Color(0xFFDCFCE7),
                        const Color(0xFF16A34A),
                        () => context.go('$prefix/student-records'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Sparkline Top Stat Card
  Widget _buildSparklineStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    required String sparklineType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : AppTheme.dividerColor.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: 0.18,
                    child: SizedBox(
                      width: 70,
                      height: 36,
                      child: sparklineType == 'bars'
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _miniBar(12, color),
                                _miniBar(20, color),
                                _miniBar(16, color),
                                _miniBar(28, color),
                                _miniBar(24, color),
                              ],
                            )
                          : CustomPaint(painter: WavePainter(color: color)),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: AppTheme.textSecondary.withOpacity(0.3),
                          size: 12,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      value,
                      style: GoogleFonts.montserrat(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBar(double height, Color color) {
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // Dominant Career Interests (RIASEC)
  Widget _buildRiasecCard(List<Map<String, dynamic>> riasecStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final map = {for (var s in riasecStats) s['type'].toString(): s['count'] as int};
    final total = map.values.fold(0, (sum, val) => sum + val);

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, color: AppTheme.primaryPurple, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Dominant Career Interests (Primary Types)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showRiasecDetailsDialog(riasecStats, total),
                  child: const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No approved assessment results yet.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['R', 'I', 'A', 'S', 'E', 'C'].map((t) {
                    final count = map[t] ?? 0;
                    final pct = total > 0 ? (count / total * 100) : 0.0;
                    final color = AppTheme.riasecColor(t);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: color.withOpacity(0.15),
                            child: Text(
                              t,
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 90,
                            child: Text(
                              AppTheme.riasecName(t),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: total > 0 ? count / total : 0.0,
                                backgroundColor: isDark ? Colors.white10 : AppTheme.dividerColor.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 50,
                            child: Text(
                              '${pct.toStringAsFixed(1)}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              Icon(Icons.person_outline, size: 13, color: AppTheme.textSecondary),
                              const SizedBox(width: 2),
                              Text(
                                '$count student(s)',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Strand Distribution Card
  Widget _buildStrandCard(List<Map<String, dynamic>> rawStrandStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Normalize and aggregate strands (e.g. merge raw "STEM" into full title)
    final Map<String, int> merged = {};
    for (final item in rawStrandStats) {
      final canonical = AppTheme.normalizeStrand(item['strand']?.toString() ?? '');
      final count = (item['count'] is num) ? (item['count'] as num).toInt() : 0;
      merged[canonical] = (merged[canonical] ?? 0) + count;
    }
    final strandStats = merged.entries
        .map((e) => {'strand': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    final total = strandStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.school_rounded, color: AppTheme.primaryPurple, size: 20),
                    SizedBox(width: 8),
                    Text('Strand Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                InkWell(
                  onTap: () => _showStrandDetailsDialog(strandStats),
                  child: const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No strand data available.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: strandStats.map((item) {
                            final strandName = item['strand'].toString();
                            final count = item['count'] as int;
                            final pct = total > 0 ? count / total : 0.0;
                            final color = AppTheme.strandColor(strandName);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(strandName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text('$count student(s) (${(pct * 100).toStringAsFixed(1)}%)', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor: isDark ? Colors.white10 : color.withOpacity(0.12),
                                      valueColor: AlwaysStoppedAnimation<Color>(color),
                                      minHeight: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Callout Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppTheme.primaryPurple, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'About Strand Distribution',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryPurple),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'This shows student distribution per academic strand based on assessment results.',
                                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Self-Esteem (RSE) Card
  Widget _buildRseCard(List<Map<String, dynamic>> rseStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = rseStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.favorite_rounded, color: Color(0xFFE53E3E), size: 20),
                    SizedBox(width: 8),
                    Text('Self-Esteem (RSE)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                InkWell(
                  onTap: () => _showRseDetailsDialog(rseStats),
                  child: const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No self-esteem data available.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: rseStats.map((item) {
                        final level = item['level'].toString();
                        final count = item['count'] as int;
                        final isLow = level.toLowerCase().contains('low');
                        final color = isLow ? const Color(0xFFE53E3E) : AppTheme.success;

                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  isLow ? Icons.sentiment_very_dissatisfied : Icons.sentiment_satisfied_alt,
                                  color: color,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  level,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$count student(s)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Identifies students with low self-esteem levels who may benefit from academic self-worth enrichment programs.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Career Self-Efficacy Card
  Widget _buildCdsesCard(List<Map<String, dynamic>> cdsesStats) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = cdsesStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: AppTheme.primaryPurple, size: 20),
                    SizedBox(width: 8),
                    Text('Career Self-Efficacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                InkWell(
                  onTap: () => _showCdsesDetailsDialog(cdsesStats),
                  child: const Row(
                    children: [
                      Text(
                        'View Details',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No self-efficacy data available.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...cdsesStats.map((item) {
                      final levelName = item['level'].toString();
                      final count = item['count'] as int;
                      final isHigh = levelName.toLowerCase().contains('high');
                      final isMod = levelName.toLowerCase().contains('mod');
                      final color = isHigh ? AppTheme.success : isMod ? AppTheme.warning : const Color(0xFFE53E3E);
                      final pct = total > 0 ? count / total : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  levelName.replaceAll(' Career Decision Self-Efficacy', ''),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                ),
                                Text('$count student(s)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: isDark ? Colors.white10 : AppTheme.dividerColor.withOpacity(0.3),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 10,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 6),
                    Text(
                      'Tracks confidence in self-appraisal, occupational info gathering, goal selecting, planning, and problem-solving.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 5-Column Table for Recent Student Activities - FULL WIDTH EXPANSION
  Widget _buildRecentActivityTable(List<Map<String, dynamic>> recentActivity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppTheme.primaryPurple, size: 20),
                    SizedBox(width: 8),
                    Text('Recent Student Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('$prefix/monitoring'),
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentActivity.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No student activity logged yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 80),
                    child: DataTable(
                      horizontalMargin: 12,
                      columnSpacing: 28,
                      headingRowHeight: 42,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 54,
                      columns: [
                        DataColumn(label: Text('STUDENT NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('ACTIVITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('DATE & TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                        DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple))),
                      ],
                      rows: recentActivity.map((act) {
                        final isApproved = act['status'].toString() == 'approved';
                        final color = isApproved ? AppTheme.success : AppTheme.warning;
                        final name = act['studentName']?.toString() ?? 'Anonymous';
                        final firstChar = name.isNotEmpty ? name[0].toUpperCase() : 'S';

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppTheme.primaryPurple.withOpacity(0.12),
                                    child: Text(
                                      firstChar,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryPurple),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppTheme.success.withOpacity(0.15),
                                    child: const Icon(Icons.check, size: 10, color: AppTheme.success),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Assessment Submitted', style: TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                'Strand: ${act['strand'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ),
                            DataCell(
                              Text(
                                act['submittedAt']?.toString() ?? '',
                                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: color.withOpacity(0.3)),
                                ),
                                child: Text(
                                  isApproved ? 'Approved' : 'Pending',
                                  style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Top Recommended Course Clusters Leaderboard Widget
  Widget _buildTopClustersCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final topClusters = [
      {'rank': 1, 'name': 'Technology & Engineering Cluster', 'count': 4, 'pct': 0.60},
      {'rank': 2, 'name': 'Business & Accountancy Cluster', 'count': 2, 'pct': 0.30},
      {'rank': 3, 'name': 'Humanities & Social Sciences Cluster', 'count': 1, 'pct': 0.15},
    ];

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.collections_bookmark_rounded, color: AppTheme.primaryPurple, size: 20),
                    SizedBox(width: 8),
                    Text('Top Recommended Course Clusters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                InkWell(
                  onTap: _showTopClustersDialog,
                  child: const Row(
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppTheme.primaryPurple),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...topClusters.map((item) {
              final rank = item['rank'] as int;
              final name = item['name'].toString();
              final count = item['count'] as int;
              final pct = item['pct'] as double;
              final color = AppTheme.clusterColor(name);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: color,
                      child: Text(
                        '$rank',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: isDark ? Colors.white10 : color.withOpacity(0.12),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$count student(s)',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 16, color: AppTheme.textSecondary),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // 2x2 Quick Actions Grid
  Widget _buildQuickActionsGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppTheme.primaryPurple, size: 20),
                SizedBox(width: 8),
                Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _quickActionButton(
                        'View All Assessments',
                        Icons.assignment_outlined,
                        const Color(0xFFF3E8FF),
                        AppTheme.primaryPurple,
                        () => context.go('$prefix/monitoring'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickActionButton(
                        isPsych ? 'Test Records Archive' : 'Manage Students',
                        Icons.people_outline_rounded,
                        const Color(0xFFE0F2FE),
                        const Color(0xFF0284C7),
                        () => context.go('$prefix/student-records'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _quickActionButton(
                        isPsych ? 'Pending Evaluations' : 'Endorsed Student Queue',
                        Icons.assignment_turned_in_outlined,
                        const Color(0xFFDCFCE7),
                        const Color(0xFF16A34A),
                        () => context.go('$prefix/pending-approvals'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _quickActionButton(
                        isPsych ? 'Psychometric Evaluation & Review' : 'Student Result',
                        isPsych ? Icons.psychology_outlined : Icons.rate_review_outlined,
                        const Color(0xFFFFEDD5),
                        const Color(0xFFEA580C),
                        () => context.go('$prefix/ai-feedback'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionButton(String label, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: iconColor),
          ],
        ),
      ),
    );
  }

  // --- POPUP DIALOGS ---

  void _showRiasecDetailsDialog(List<Map<String, dynamic>> riasecStats, int total) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.pie_chart_rounded, color: AppTheme.primaryPurple),
            const SizedBox(width: 8),
            const Text('RIASEC Interest Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Assessed Students: $total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              ...['R', 'I', 'A', 'S', 'E', 'C'].map((t) {
                final item = riasecStats.firstWhere((s) => s['type'] == t, orElse: () => {'count': 0});
                final count = item['count'] as int;
                final color = AppTheme.riasecColor(t);

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(t, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  title: Text(AppTheme.riasecName(t), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  trailing: Text('$count Student(s)', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(SessionManager().isPsychometrician ? '/psychometrician/student-records' : '/guidance-counselor/student-records');
            },
            child: const Text('View All Student Records'),
          ),
        ],
      ),
    );
  }

  void _showStrandDetailsDialog(List<Map<String, dynamic>> rawStrandStats) {
    // Normalize and aggregate strands
    final Map<String, int> merged = {};
    for (final item in rawStrandStats) {
      final canonical = AppTheme.normalizeStrand(item['strand']?.toString() ?? '');
      final count = (item['count'] is num) ? (item['count'] as num).toInt() : 0;
      merged[canonical] = (merged[canonical] ?? 0) + count;
    }
    final strandStats = merged.entries
        .map((e) => {'strand': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: AppTheme.primaryPurple),
            SizedBox(width: 8),
            Text('Strand Distribution Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: strandStats.map((item) {
              final sName = item['strand'].toString();
              final sColor = AppTheme.strandColor(sName);
              return ListTile(
                dense: true,
                leading: Icon(Icons.bookmark_outline, color: sColor),
                title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                trailing: Text('${item['count']} Student(s)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: sColor)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showRseDetailsDialog(List<Map<String, dynamic>> rseStats) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.favorite_rounded, color: Color(0xFFE53E3E)),
            SizedBox(width: 8),
            Text('Self-Esteem (RSE) Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Students flagged with Low Self-Esteem may benefit from academic & personal self-worth counseling.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ...rseStats.map((item) {
                final level = item['level'].toString();
                final count = item['count'] as int;
                final isLow = level.toLowerCase().contains('low');
                final color = isLow ? const Color(0xFFE53E3E) : AppTheme.success;

                return ListTile(
                  dense: true,
                  leading: Icon(isLow ? Icons.error_outline : Icons.check_circle_outline, color: color),
                  title: Text(level, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                  trailing: Text('$count Student(s)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            onPressed: () {
              Navigator.pop(ctx);
              context.go(SessionManager().isPsychometrician ? '/psychometrician/student-records' : '/guidance-counselor/student-records');
            },
            child: const Text('Review Student Records'),
          ),
        ],
      ),
    );
  }

  void _showCdsesDetailsDialog(List<Map<String, dynamic>> cdsesStats) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppTheme.primaryPurple),
            const SizedBox(width: 8),
            const Text('Career Self-Efficacy Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: cdsesStats.map((item) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.trending_up, color: AppTheme.primaryPurple),
                title: Text(item['level'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                trailing: Text('${item['count']} Student(s)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showTopClustersDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.collections_bookmark_rounded, color: AppTheme.primaryPurple),
            SizedBox(width: 8),
            Text('Top Recommended Course Clusters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.clusterColor('Technology & Engineering Cluster'),
                  child: const Text('1', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                title: const Text('Technology & Engineering Cluster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('BS CS, BS IT, BS Mechanical Engg'),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.clusterColor('Business & Accountancy Cluster'),
                  child: const Text('2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                title: const Text('Business & Accountancy Cluster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('BS Accountancy, BSBA Marketing'),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.clusterColor('Humanities & Social Sciences Cluster'),
                  child: const Text('3', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                title: const Text('Humanities & Social Sciences Cluster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: const Text('BA Psychology, BS Criminology'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

// Custom Painter for Sparkline Wave Background
class WavePainter extends CustomPainter {
  final Color color;
  WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.9, size.width, size.height * 0.3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}