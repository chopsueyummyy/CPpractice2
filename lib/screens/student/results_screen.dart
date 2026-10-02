import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/student_sidebar.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _session = SessionManager();
  bool _isLoading = true;
  Map<String, dynamic>? _resultsData;
  String? _error;
  String? _assessmentStatus;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> data;
      if (_session.currentAssessmentId != null) {
        data = await ApiService.getResults(_session.currentAssessmentId!);
      } else if (_session.studentId != null) {
        data = await ApiService.getResultsByStudentId(_session.studentId!);
      } else {
        setState(() { _error = 'No assessment found.'; _isLoading = false; });
        return;
      }

      if (data['status'] == 'success') {
        final asmStatus = data['assessmentStatus'] as String?;
        setState(() {
          _assessmentStatus = asmStatus;
          if (asmStatus == 'approved' || asmStatus == 'rejected') {
            _resultsData = data;
          }
          _isLoading = false;
        });
      } else {
        setState(() { _error = data['message']; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Failed to load results.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: StudentSidebar(currentRoute: '/student/results'),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Assessment Results',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => context.go('/student/dashboard'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _assessmentStatus == 'pending_review'
                  ? _buildPendingView()
                  : _resultsData == null
                      ? _buildNoAssessmentView()
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: ResultsBackgroundPainter(isDark: isDark),
                              ),
                            ),
                            SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 1100),
                                  child: _buildResults(isDark),
                                ),
                              ),
                            ),
                          ],
                        ),
    );
  }

  Widget _buildNoAssessmentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No Results Yet',
            style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Text('Complete your assessment to view results here.', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: () => context.go('/student/dashboard'),
            child: const Text('Go to Dashboard', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top, size: 80, color: AppTheme.warning),
            const SizedBox(height: 24),
            Text(
              'Awaiting Counselor Review',
              style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: Text(
                'Your assessment has been submitted and is currently being reviewed by your guidance counselor. You will be able to view your results once they have been approved or rejected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.warning, height: 1.5, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () => context.go('/student/dashboard'),
              child: const Text('Return to Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final scores    = _resultsData!['scores'] as Map<String, dynamic>;
    final primary   = _resultsData!['primaryType'] as String;
    final secondary = _resultsData!['secondaryType'] as String;
    final tertiary  = _resultsData!['tertiaryType'] as String;
    final recs      = _resultsData!['recommendations'] as List<dynamic>;
    final status    = _resultsData!['assessmentStatus'] as String;
    final strand    = (_resultsData!['strand'] as String?) ?? 'Not Specified';

    final rseData   = _resultsData!['rse'] as Map<String, dynamic>?;
    final cdsesData = _resultsData!['cdses'] as Map<String, dynamic>?;

    final sortedScores = scores.entries.toList()
      ..sort((a, b) {
        final aVal = double.tryParse(a.value['percentage'].toString()) ?? 0.0;
        final bVal = double.tryParse(b.value['percentage'].toString()) ?? 0.0;
        return bVal.compareTo(aVal);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Status Banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: status == 'rejected' ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: status == 'rejected' ? const Color(0xFFFFCDD2) : const Color(0xFFC8E6C9),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                status == 'rejected' ? Icons.cancel : Icons.check_circle,
                color: status == 'rejected' ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  status == 'approved' 
                    ? 'Your assessment results have been approved by your guidance counselor.\nYou can now view the complete results and recommendations.'
                    : 'Your counselor has rejected this submission. Please review the details below and retake the assessment.',
                  style: GoogleFonts.plusJakartaSans(
                    color: status == 'approved' ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Title Header
        Text(
          'Your Assessment Results',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF2B0054),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Here is a summary of your assessment results. Explore your strengths, learn more about yourself, and discover course options that match your profile.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        // --- SECTION 1: CAREER INTERESTS PROFILE (RIASEC) ---
        _buildRiasecSection(sortedScores, primary, secondary, tertiary, isDark),
        const SizedBox(height: 28),

        // --- SECTION 2: SELF-ESTEEM (RSE) & CAREER DECISION SELF-EFFICACY (CDSES-SF) ---
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildRseCard(rseData, isDark)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildCdsesCard(cdsesData, isDark)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildRseCard(rseData, isDark),
                  const SizedBox(height: 24),
                  _buildCdsesCard(cdsesData, isDark),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 28),

        // --- SECTION 3: RECOMMENDED COURSE CLUSTERS (XGBoost + SHAP) ---
        if (_resultsData!['clusterRecommendations'] != null && (_resultsData!['clusterRecommendations'] as List).isNotEmpty) ...[
          _buildClusterRecommendationsSection(_resultsData!['clusterRecommendations'] as List<dynamic>, isDark),
          const SizedBox(height: 28),
        ],

        // --- SECTION 3.5: SPECIFIC RECOMMENDED COURSES (Fallback if no cluster recommendations) ---
        if ((_resultsData!['clusterRecommendations'] as List?)?.isEmpty ?? true) ...[
          if (recs.isNotEmpty) ...[
            _buildRecommendedCoursesSection(recs, isDark),
            const SizedBox(height: 28),
          ],
        ],

        // --- SECTION 4: COUNSELOR NOTES & WHY RECOMMENDED ---
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCounselorNoteCard(isDark)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildWhyRecommendedCard(primary, rseData, cdsesData, strand, isDark)),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildCounselorNoteCard(isDark),
                  const SizedBox(height: 24),
                  _buildWhyRecommendedCard(primary, rseData, cdsesData, strand, isDark),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // --- SECTION 5: DISCLAIMER CARD ---
        _buildDisclaimerCard(isDark),
        const SizedBox(height: 24),

        if (status == 'rejected') ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/student/dashboard'),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text(
                'Retake Assessment',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // --- SECTION 1: RIASEC CARD ---
  Widget _buildRiasecSection(List<MapEntry<String, dynamic>> sortedScores, String primary, String secondary, String tertiary, bool isDark) {
    return Container(
      decoration: _cardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.layers_rounded,
            title: 'Career Interests Profile (RIASEC)',
            subtitle: 'Your interest areas based on your responses.',
            badgeLabel: 'RIASEC',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: sortedScores.map((entry) {
                          return _buildRiasecBarRow(entry.key, double.tryParse(entry.value['percentage'].toString()) ?? 0.0, isDark);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 5,
                      child: _buildTop3InterestPanel(primary, secondary, tertiary, sortedScores, isDark),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    ...sortedScores.map((entry) {
                      return _buildRiasecBarRow(entry.key, double.tryParse(entry.value['percentage'].toString()) ?? 0.0, isDark);
                    }),
                    const SizedBox(height: 24),
                    _buildTop3InterestPanel(primary, secondary, tertiary, sortedScores, isDark),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRiasecBarRow(String type, double percentage, bool isDark) {
    final color = AppTheme.riasecColor(type);
    final name = AppTheme.riasecName(type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                type,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 12,
                backgroundColor: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 55,
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTop3InterestPanel(String primary, String secondary, String tertiary, List<MapEntry<String, dynamic>> sortedScores, bool isDark) {
    double getScore(String t) {
      final match = sortedScores.firstWhere((e) => e.key == t, orElse: () => const MapEntry('', {'percentage': 0.0}));
      return double.tryParse(match.value['percentage'].toString()) ?? 0.0;
    }

    final top3 = [
      {'rank': 1, 'type': primary, 'score': getScore(primary)},
      {'rank': 2, 'type': secondary, 'score': getScore(secondary)},
      {'rank': 3, 'type': tertiary, 'score': getScore(tertiary)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Top 3 Interest Areas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          ...top3.map((item) {
            final type = item['type'] as String;
            final rank = item['rank'] as int;
            final score = item['score'] as double;
            final color = AppTheme.riasecColor(type);
            final name = AppTheme.riasecName(type);
            final desc = AppTheme.riasecDescriptor(type);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6A0DAD),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(
                      child: Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          desc,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${score.toStringAsFixed(1)}%',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.primaryPurple, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What does this mean?',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your top interest areas show the types of work activities and environments you are most likely to enjoy. These results can help guide you toward courses and careers that match your interests.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          height: 1.4,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
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
    );
  }

  // --- SECTION 2: RSE CARD ---
  Widget _buildRseCard(Map<String, dynamic>? rseData, bool isDark) {
    if (rseData == null) {
      return Container(
        decoration: _cardDecoration(isDark),
        padding: const EdgeInsets.all(24),
        child: const Center(child: Text('No Self-Esteem results available.')),
      );
    }

    final int score = rseData['score'] ?? 0;
    final String level = rseData['level'] ?? 'Normal Self-Esteem';
    final isLow = level.toLowerCase().contains('low');
    final color = isLow ? const Color(0xFFE53E3E) : const Color(0xFF2E7D32);

    return Container(
      decoration: _cardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.person_pin_rounded,
            title: 'Self-Esteem Profile (RSE)',
            subtitle: 'Your overall self-esteem score and interpretation.',
            badgeLabel: 'Self-Esteem',
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(
                    isLow ? Icons.sentiment_very_dissatisfied : Icons.sentiment_satisfied_alt,
                    color: color,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  level,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your RSE Score: $score / 30',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isLow
                      ? 'Your self-esteem score suggests low self-esteem. We advise speaking with your guidance counselor for helpful self-esteem enhancement activities.'
                      : 'Your self-esteem score is within the normal range. Keep nurturing a positive and healthy relationship with yourself!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 2: CDSES CARD ---
  Widget _buildCdsesCard(Map<String, dynamic>? cdsesData, bool isDark) {
    if (cdsesData == null) {
      return Container(
        decoration: _cardDecoration(isDark),
        padding: const EdgeInsets.all(24),
        child: const Center(child: Text('No CDSES results available.')),
      );
    }

    final double totalScore = (cdsesData['totalScore'] as num?)?.toDouble() ?? 0.0;
    final String level = cdsesData['selfEfficacyLevel'] ?? 'High Career Decision Self-Efficacy';

    final saScore = (cdsesData['saScore'] as num?)?.toDouble() ?? 4.0;
    final oiScore = (cdsesData['oiScore'] as num?)?.toDouble() ?? 3.8;
    final gsScore = (cdsesData['gsScore'] as num?)?.toDouble() ?? 4.0;
    final plScore = (cdsesData['plScore'] as num?)?.toDouble() ?? 3.8;
    final psScore = (cdsesData['psScore'] as num?)?.toDouble() ?? 4.2;

    return Container(
      decoration: _cardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.psychology_rounded,
            title: 'Career Decision Self-Efficacy Profile (CDSES-SF)',
            subtitle: 'Your overall confidence in making career-related decisions.',
            badgeLabel: 'CDSES',
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: totalScore / 125,
                      strokeWidth: 8,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${totalScore.toInt()}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        '/ 125',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            level,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You have a high level of confidence in successfully navigating career choices, goal planning, and academic decisions.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        height: 1.4,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'CDSES Subscale Scores',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          _buildCdsesSubscaleRow('SA', 'Self-Appraisal', saScore, const Color(0xFF6A0DAD), isDark),
          _buildCdsesSubscaleRow('OI', 'Occupational Information', oiScore, const Color(0xFF10B981), isDark),
          _buildCdsesSubscaleRow('GS', 'Goal Selection', gsScore, const Color(0xFF3B82F6), isDark),
          _buildCdsesSubscaleRow('PL', 'Planning', plScore, const Color(0xFFF59E0B), isDark),
          _buildCdsesSubscaleRow('PS', 'Problem Solving', psScore, const Color(0xFF10B981), isDark),
        ],
      ),
    );
  }

  Widget _buildCdsesSubscaleRow(String code, String name, double score, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              code,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 5.0,
                minHeight: 8,
                backgroundColor: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${score.toStringAsFixed(2)} / 5.00',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 3: RECOMMENDED COURSE CLUSTERS (XGBoost + SHAP) ---
  Widget _buildClusterRecommendationsSection(List<dynamic> clusters, bool isDark) {
    return Container(
      decoration: _cardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.hub_rounded,
            title: 'Top Recommended Course Clusters',
            subtitle: 'Based on your assessment profile, these course clusters received the highest model predictions.',
            badgeLabel: 'Top Recommendations',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: clusters.asMap().entries.map((entry) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: entry.key == clusters.length - 1 ? 0 : 16),
                          child: _buildSingleClusterCard(entry.key + 1, entry.value as Map<String, dynamic>, isDark),
                        ),
                      );
                    }).toList(),
                  ),
                );
              } else {
                return Column(
                  children: clusters.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: _buildSingleClusterCard(entry.key + 1, entry.value as Map<String, dynamic>, isDark),
                    );
                  }).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSingleClusterCard(int rank, Map<String, dynamic> clusterData, bool isDark) {
    final clusterName = clusterData['cluster_name'] as String? ?? 'General Cluster';
    final matchPct = (clusterData['match_percentage'] as num?)?.toDouble() ?? 0.0;
    final explanations = (clusterData['shap_explanations'] as List<dynamic>?) ?? [];
    final exploreCourses = (clusterData['explore_courses'] as List<dynamic>?) ?? [];

    String medalEmoji;
    String rankTitle;
    Color rankColor;
    Color bgBadgeColor;

    if (rank == 1) {
      medalEmoji = '🥇';
      rankTitle = 'Primary Recommendation';
      rankColor = const Color(0xFFD97706);
      bgBadgeColor = const Color(0xFFFEF3C7);
    } else if (rank == 2) {
      medalEmoji = '🥈';
      rankTitle = 'Alternative Recommendation';
      rankColor = const Color(0xFF7C3AED);
      bgBadgeColor = const Color(0xFFF3E8FF);
    } else {
      medalEmoji = '🥉';
      rankTitle = 'Additional Recommendation';
      rankColor = const Color(0xFF059669);
      bgBadgeColor = const Color(0xFFD1FAE5);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rankColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: bgBadgeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$medalEmoji $rankTitle',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${matchPct.toStringAsFixed(1)}% Predicted Probability',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: rankColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                clusterName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E2E3E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF3E3E50) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppTheme.primaryPurple, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Why this cluster was recommended',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...explanations.map((exp) {
                  final feat = exp['feature'] as String? ?? '';
                  final impact = (exp['impact_score'] as num?)?.toDouble() ?? 0.0;
                  final normalizedVal = (impact.abs()).clamp(0.1, 1.0);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                feat,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            Text(
                              '+${(impact * 100).toInt()}% Impact',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: normalizedVal,
                            minHeight: 6,
                            backgroundColor: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '📌 Courses you might want to explore:',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          ...exploreCourses.map((crs) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right_rounded, color: AppTheme.primaryPurple, size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      crs.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
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

  // --- SECTION 3.5: RECOMMENDED COURSES ---
  Widget _buildRecommendedCoursesSection(List<dynamic> recs, bool isDark) {
    return Container(
      decoration: _cardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.track_changes_rounded,
            title: 'Recommended Courses',
            subtitle: 'Based on your assessment results, here are the courses that best match your profile.',
            badgeLabel: 'Top Recommendations',
            isDark: isDark,
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: recs.asMap().entries.map((entry) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: entry.key == recs.length - 1 ? 0 : 16),
                        child: _buildSingleCourseCard(entry.key + 1, entry.value as Map<String, dynamic>, isDark),
                      ),
                    );
                  }).toList(),
                );
              } else {
                return Column(
                  children: recs.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildSingleCourseCard(entry.key + 1, entry.value as Map<String, dynamic>, isDark),
                    );
                  }).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCourseCard(int rank, Map<String, dynamic> rec, bool isDark) {
    final type = rec['RIASECCategory'] as String;
    final color = AppTheme.riasecColor(type);
    final courseName = rec['CourseName'] as String;
    final courseCode = rec['CourseCode'] as String;

    String matchLabel;
    Color matchBg;
    Color matchFg;

    if (rank == 1) {
      matchLabel = '🏆 Top Match';
      matchBg = const Color(0xFFFEF3C7);
      matchFg = const Color(0xFFD97706);
    } else if (rank == 2) {
      matchLabel = '⚙️ Strong Match';
      matchBg = const Color(0xFFF3E8FF);
      matchFg = const Color(0xFF7C3AED);
    } else {
      matchLabel = '👍 Suitable Match';
      matchBg = const Color(0xFFD1FAE5);
      matchFg = const Color(0xFF059669);
    }

    final explanationText = rec['Explanation'] as String? ?? '';
    final sentences = explanationText
        .split('.')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: matchBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  matchLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: matchFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            courseName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildSmallTag(courseCode, isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0), isDark ? Colors.white70 : const Color(0xFF64748B)),
              _buildSmallTag(AppTheme.riasecName(type), color.withOpacity(0.15), color),
            ],
          ),
          const SizedBox(height: 16),
          ...sentences.map((st) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      st,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryPurple,
                side: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                _showCourseDetailsDialog(courseName, courseCode, explanationText);
              },
              child: Text(
                'View Course Details →',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  void _showCourseDetailsDialog(String name, String code, String explanation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Course Code: $code', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
            const SizedBox(height: 12),
            Text(explanation, style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- SECTION 4: COUNSELOR NOTE & WHY RECOMMENDED ---
  Widget _buildCounselorNoteCard(bool isDark) {
    final noteText = _resultsData!['counselorNotes']?.toString() ??
        'Good results. You show strong interest in practical and technical fields. Consider exploring BSCS and BSME based on your strengths.';
    final formattedDate = 'September 10, 2025';

    return Container(
      decoration: _cardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primaryPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Counselor Notes & Guidance',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.primaryPurple,
                      child: const Icon(Icons.person, size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Counselor's Note",
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  noteText,
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.5, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text('Noted on: $formattedDate', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFF64748B))),
                      ],
                    ),
                    Text('Guidance Counselor', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyRecommendedCard(String primary, Map<String, dynamic>? rse, Map<String, dynamic>? cdses, String strand, bool isDark) {
    final interestName = AppTheme.riasecName(primary);
    final riasecText = 'Strong $interestName Interest';

    String rseText = 'High Self-Esteem';
    if (rse != null) {
      final level = rse['level'].toString().toLowerCase();
      if (level.contains('low')) {
        rseText = 'Low Self-Esteem Profile';
      } else {
        rseText = 'High Self-Esteem';
      }
    }

    String cdsesText = 'High Career Decision Self-Efficacy';
    if (cdses != null) {
      final level = cdses['selfEfficacyLevel'].toString().toLowerCase();
      if (level.contains('low')) {
        cdsesText = 'Low Career Decision Self-Efficacy';
      } else if (level.contains('mod')) {
        cdsesText = 'Moderate Career Decision Self-Efficacy';
      }
    }

    String strandShort = 'HUMSS';
    if (strand.contains('STEM')) strandShort = 'STEM';
    else if (strand.contains('ABM')) strandShort = 'ABM';
    else if (strand.contains('HUMSS')) strandShort = 'HUMSS';
    else if (strand.contains('GAS')) strandShort = 'GAS';
    else if (strand.contains('TVL')) strandShort = 'TVL';
    else if (strand.contains('ICT')) strandShort = 'ICT';

    final strandText = 'Strong compatibility with $strandShort-related programs';

    return Container(
      decoration: _cardDecoration(isDark),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.primaryPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.help_outline_rounded, color: AppTheme.primaryPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Why were these courses recommended?',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _whyCheckItem(riasecText, isDark),
          _whyCheckItem(rseText, isDark),
          _whyCheckItem(cdsesText, isDark),
          _whyCheckItem(strandText, isDark),
        ],
      ),
    );
  }

  Widget _whyCheckItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 5: DISCLAIMER CARD ---
  Widget _buildDisclaimerCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'These recommendations represent the best course matches based on your assessment results. They are intended to support—not replace—your personal judgment and the guidance provided by your Guidance Counselor. While the system identifies courses that are compatible with your assessment profile, it does not guarantee academic success or future career outcomes.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                height: 1.45,
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Card Decoration & Header
  BoxDecoration _cardDecoration(bool isDark) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF181825) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildCardHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeLabel,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primaryPurple, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badgeLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryPurple,
            ),
          ),
        ),
      ],
    );
  }
}

class ResultsBackgroundPainter extends CustomPainter {
  final bool isDark;

  ResultsBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final wave1Path = Path();
    wave1Path.moveTo(0, size.height * 0.15);
    wave1Path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.03,
      size.width * 0.7, size.height * 0.18,
    );
    wave1Path.quadraticBezierTo(
      size.width * 0.88, size.height * 0.25,
      size.width, size.height * 0.12,
    );
    wave1Path.lineTo(size.width, 0);
    wave1Path.lineTo(0, 0);
    wave1Path.close();

    final wave1Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryPurple.withOpacity(isDark ? 0.12 : 0.08),
          AppTheme.primaryPurple.withOpacity(isDark ? 0.02 : 0.01),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(rect);

    canvas.drawPath(wave1Path, wave1Paint);

    final wave2Path = Path();
    wave2Path.moveTo(0, size.height * 0.82);
    wave2Path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.7,
      size.width * 0.7, size.height * 0.88,
    );
    wave2Path.quadraticBezierTo(
      size.width * 0.85, size.height * 0.96,
      size.width, size.height * 0.86,
    );
    wave2Path.lineTo(size.width, size.height);
    wave2Path.lineTo(0, size.height);
    wave2Path.close();

    final wave2Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryPurple.withOpacity(isDark ? 0.15 : 0.1),
          AppTheme.primaryPurple.withOpacity(isDark ? 0.03 : 0.02),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(rect);

    canvas.drawPath(wave2Path, wave2Paint);
  }

  @override
  bool shouldRepaint(covariant ResultsBackgroundPainter oldDelegate) => oldDelegate.isDark != isDark;
}