import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/student_sidebar.dart';
import '../../widgets/jmcfi_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _session = SessionManager();
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  String? _error;
  final Set<int> _expandedIndices = {0}; // Default expand first item

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getHistory(_session.studentId!);
      if (data['status'] == 'success') {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data['history']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load history.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      drawer: StudentSidebar(currentRoute: '/student/history'),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Assessment History',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: 'Return to Main Menu',
            onPressed: () => context.go('/student/dashboard'),
          ),
        ],
      ),
      body: CustomPaint(
        painter: HistoryBackgroundPainter(isDark: isDark),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: GoogleFonts.plusJakartaSans(color: AppTheme.textSecondary),
                    ),
                  )
                : _history.isEmpty
                    ? _buildEmptyState(context, isDark)
                    : _buildHistoryContent(context, isDark),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 64, color: AppTheme.primaryPurple),
            ),
            const SizedBox(height: 20),
            Text(
              'No Assessment History',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Approved or completed assessments will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => context.go('/student/dashboard'),
              icon: const Icon(Icons.quiz_outlined, size: 18),
              label: Text(
                'Go to Dashboard',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryContent(BuildContext context, bool isDark) {
    final approvedCount = _history.where((h) => (h['status'] ?? '').toString().toLowerCase() == 'approved').length;
    final rejectedCount = _history.where((h) => (h['status'] ?? '').toString().toLowerCase() == 'rejected').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Metric Cards Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Assessments',
                  value: _history.length.toString(),
                  icon: Icons.bar_chart_rounded,
                  accentColor: AppTheme.primaryPurple,
                  bgColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFF3E8FF),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Approved',
                  value: approvedCount.toString(),
                  icon: Icons.check_circle_rounded,
                  accentColor: const Color(0xFF10B981),
                  bgColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F5E9),
                  isDark: isDark,
                ),
              ),
              if (rejectedCount > 0) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Rejected',
                    value: rejectedCount.toString(),
                    icon: Icons.cancel_rounded,
                    accentColor: const Color(0xFFEF4444),
                    bgColor: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                    isDark: isDark,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // Assessment List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = _history[index];
              return _buildAssessmentCard(context, item, index, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentCard(BuildContext context, Map<String, dynamic> item, int index, bool isDark) {
    final isExpanded = _expandedIndices.contains(index);
    final rawStatus = (item['status'] ?? 'approved').toString().toLowerCase();
    final isApproved = rawStatus == 'approved';
    final isPending = rawStatus == 'pending';

    final statusColor = isApproved
        ? const Color(0xFF10B981)
        : isPending
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    final statusBgColor = isApproved
        ? const Color(0xFFE8F5E9)
        : isPending
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEF2F2);

    final statusText = rawStatus.toUpperCase();

    final submittedAtStr = item['submittedAt'] != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(item['submittedAt']))
        : (item['date'] != null ? item['date'].toString() : 'Aug 05, 2026 • 08:50 PM');

    final assessmentNum = item['assessmentNum'] ?? (index + 1);

    // Extract RIASEC top 3
    final primary = item['primaryType']?.toString() ?? 'C';
    final secondary = item['secondaryType']?.toString() ?? 'I';
    final tertiary = item['tertiaryType']?.toString() ?? 'R';

    // Extract RSE & CDSES
    final rseData = item['rse'] as Map<String, dynamic>?;
    final rseScore = rseData?['score'] ?? 21;
    final rseLevel = rseData?['level'] ?? 'Normal Self-Esteem';

    final cdsesData = item['cdses'] as Map<String, dynamic>?;
    final cdsesTotal = (cdsesData?['totalScore'] as num?)?.toInt() ?? 99;
    final cdsesLevel = cdsesData?['selfEfficacyLevel'] ?? 'High';
    final sa = cdsesData?['saScore'] ?? 4.0;
    final oi = cdsesData?['oiScore'] ?? 3.8;
    final gs = cdsesData?['gsScore'] ?? 4.0;
    final pl = cdsesData?['plScore'] ?? 3.8;
    final ps = cdsesData?['psScore'] ?? 4.2;

    // Courses & Cluster Recommendations
    final courses = List<String>.from(item['courses'] ?? [
      'Bachelor of Science in Computer Science',
      'Bachelor of Science in Architecture',
      'Bachelor of Science in Mechanical Engineering',
    ]);
    final clusterRecs = item['clusterRecommendations'] as List<dynamic>?;

    // Counselor note
    final noteText = item['counselorNote']?.toString();
    final noteDate = item['notedAt'] != null
        ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(item['notedAt']))
        : 'September 10, 2025';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header (Clickable)
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isExpanded ? Radius.zero : const Radius.circular(16),
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedIndices.remove(index);
                } else {
                  _expandedIndices.add(index);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Status Icon Circle
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isApproved
                          ? Icons.check_circle_rounded
                          : isPending
                              ? Icons.hourglass_top_rounded
                              : Icons.cancel_rounded,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title & Timestamp
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assessment #$assessmentNum',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Text(
                              submittedAtStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status Badge Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Chevron Icon
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: RIASEC & Other Results (2 Column Row)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 700;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildRiasecSummary(primary, secondary, tertiary, isDark)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildOtherResultsSummary(rseScore, rseLevel, cdsesTotal, cdsesLevel, sa, oi, gs, pl, ps, isDark)),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildRiasecSummary(primary, secondary, tertiary, isDark),
                          const SizedBox(height: 20),
                          _buildOtherResultsSummary(rseScore, rseLevel, cdsesTotal, cdsesLevel, sa, oi, gs, pl, ps, isDark),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Row 2: Recommended Course Clusters
                  _buildRecommendedCoursesSection(clusterRecs, courses, isDark),

                  // Row 3: Counselor Notes & Guidance (Only if note exists)
                  if (noteText != null && noteText.trim().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildCounselorNotesSection(noteText, noteDate, isDark),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiasecSummary(String primary, String secondary, String tertiary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.layers_outlined, color: AppTheme.primaryPurple, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Career Interests (RIASEC)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _riasecChip(primary, isDark),
            Text('+', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
            _riasecChip(secondary, isDark),
            Text('+', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
            _riasecChip(tertiary, isDark),
          ],
        ),
      ],
    );
  }

  Widget _riasecChip(String code, bool isDark) {
    final name = AppTheme.riasecName(code);
    final color = AppTheme.riasecColor(code);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: color,
            child: Text(
              code,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$code - $name',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherResultsSummary(
    int rseScore,
    String rseLevel,
    int cdsesTotal,
    String cdsesLevel,
    dynamic sa,
    dynamic oi,
    dynamic gs,
    dynamic pl,
    dynamic ps,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined, color: AppTheme.primaryPurple, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Other Results',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Self-Esteem
        Row(
          children: [
            const Icon(Icons.sentiment_satisfied_alt_rounded, size: 16, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                children: [
                  const TextSpan(text: 'Self-Esteem: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '$rseScore / 30 ($rseLevel)'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // CDSES Total
        Row(
          children: [
            const Icon(Icons.settings_outlined, size: 16, color: AppTheme.primaryPurple),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                children: [
                  const TextSpan(text: 'Career Decision Self-Efficacy: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '$cdsesTotal / 125 ($cdsesLevel)'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // CDSES Subscales
        Row(
          children: [
            const Icon(Icons.bar_chart_outlined, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              'SA: ${sa.toString()} | OI: ${oi.toString()} | GS: ${gs.toString()} | PL: ${pl.toString()} | PS: ${ps.toString()}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecommendedCoursesSection(List<dynamic>? clusterRecs, List<String> courses, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.hub_rounded, color: AppTheme.primaryPurple, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Top Recommended Course Clusters',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (clusterRecs != null && clusterRecs.isNotEmpty) ...[
          Column(
            children: clusterRecs.map((cluster) {
              final rank = (cluster['rank'] as num?)?.toInt() ?? 1;
              final clusterName = (cluster['cluster_name'] ?? 'General Cluster').toString();
              final exploreCourses = List<String>.from(cluster['explore_courses'] ?? []);

              Color rankColor;
              String badgeTitle;
              if (rank == 1) {
                rankColor = const Color(0xFFD97706);
                badgeTitle = '🥇 Primary Recommendation';
              } else if (rank == 2) {
                rankColor = const Color(0xFF7C3AED);
                badgeTitle = '🥈 Alternative Recommendation';
              } else {
                rankColor = const Color(0xFF0284C7);
                badgeTitle = '🥉 Additional Recommendation';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rankColor.withOpacity(0.35), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: rankColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeTitle,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: rankColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clusterName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (exploreCourses.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        '📌 Courses you might want to explore:',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: exploreCourses.map((c) {
                          final raw = c.toString();
                          final isJmcfi = JmcfiBadge.isJmcfiCourse(raw);
                          final cleanName = JmcfiBadge.cleanCourseTitle(raw);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : AppTheme.primaryPurple.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white12 : AppTheme.primaryPurple.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cleanName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : AppTheme.primaryPurple,
                                  ),
                                ),
                                if (isJmcfi) ...[
                                  const SizedBox(width: 6),
                                  const JmcfiBadge(),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ] else ...[
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: courses.map((course) {
              final raw = course.toString();
              final isJmcfi = JmcfiBadge.isJmcfiCourse(raw);
              final cleanName = JmcfiBadge.cleanCourseTitle(raw);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : AppTheme.primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : AppTheme.primaryPurple.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cleanName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.primaryPurple,
                      ),
                    ),
                    if (isJmcfi) ...[
                      const SizedBox(width: 6),
                      const JmcfiBadge(),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCounselorNotesSection(String noteText, String noteDate, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryPurple, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Counselor/Facilitator\'s Note',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            noteText,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox.shrink(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Guidance Counselor/Facilitator',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Noted on: $noteDate',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HistoryBackgroundPainter extends CustomPainter {
  final bool isDark;

  HistoryBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = isDark
          ? const Color(0xFF6A0DAD).withOpacity(0.06)
          : const Color(0xFF9333EA).withOpacity(0.04)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.15);
    path1.cubicTo(
      size.width * 0.25,
      size.height * 0.05,
      size.width * 0.75,
      size.height * 0.25,
      size.width,
      size.height * 0.1,
    );
    path1.lineTo(size.width, 0);
    path1.lineTo(0, 0);
    path1.close();
    canvas.drawPath(path1, paint1);

    final paint2 = Paint()
      ..color = isDark
          ? const Color(0xFF8B5CF6).withOpacity(0.04)
          : const Color(0xFFA855F7).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.85);
    path2.cubicTo(
      size.width * 0.35,
      size.height * 0.75,
      size.width * 0.65,
      size.height * 0.95,
      size.width,
      size.height * 0.88,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}