import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    return Scaffold(
      drawer: StudentSidebar(currentRoute: '/student/results'),
      appBar: AppBar(
        title: const Text('Assessment Results'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
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
                      : _buildResults(),
    );
  }

  Widget _buildNoAssessmentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text('No Results Yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Complete your assessment to view results here.', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/student/dashboard'),
            child: const Text('Go to Dashboard'),
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Your assessment has been submitted and is currently being reviewed by your guidance counselor. You will be able to view your results once they have been approved or rejected.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.warning, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/student/dashboard'),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final scores    = _resultsData!['scores'] as Map<String, dynamic>;
    final primary   = _resultsData!['primaryType'] as String;
    final secondary = _resultsData!['secondaryType'] as String;
    final tertiary  = _resultsData!['tertiaryType'] as String;
    final recs      = _resultsData!['recommendations'] as List<dynamic>;
    final status    = _resultsData!['assessmentStatus'] as String;
    final strand    = (_resultsData!['strand'] as String?) ?? 'Not Specified';

    final rseData   = _resultsData!['rse'] as Map<String, dynamic>?;
    final mbiData   = _resultsData!['mbi'] as Map<String, dynamic>?;

    final sortedScores = scores.entries.toList()
      ..sort((a, b) {
        final aVal = double.tryParse(a.value['percentage'].toString()) ?? 0.0;
        final bVal = double.tryParse(b.value['percentage'].toString()) ?? 0.0;
        return bVal.compareTo(aVal);
      });

    return SingleChildScrollView(
      child: Column(
        children: [
          // Banner Status
          Container(
            width: double.infinity,
            color: status == 'rejected' ? const Color(0xFFE53E3E).withOpacity(0.08) : AppTheme.success.withOpacity(0.08),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  status == 'rejected' ? Icons.cancel : Icons.check_circle,
                  color: status == 'rejected' ? const Color(0xFFE53E3E) : AppTheme.success,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status == 'approved' 
                      ? 'Your assessment results have been approved by your guidance counselor.'
                      : 'Your counselor has rejected this submission. Please review the details below and retake the assessment.',
                    style: TextStyle(
                      color: status == 'approved' ? AppTheme.success : const Color(0xFFE53E3E),
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: CAREER INTEREST PROFILE (RIASEC) ---
                    _buildSectionHeader('Career Interests Profile', Icons.school_rounded),
                    const SizedBox(height: 12),
                    
                    // Type Chip Banner
                    Card(
                      elevation: 0,
                      color: AppTheme.backgroundLight,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your Career Interest Profile',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Center(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                alignment: WrapAlignment.center,
                                children: [
                                  _typeChip(primary, rank: 1),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16.0),
                                    child: Icon(Icons.add, color: AppTheme.textSecondary, size: 16),
                                  ),
                                  _typeChip(secondary, rank: 2),
                                  const Padding(
                                    padding: EdgeInsets.only(top: 16.0),
                                    child: Icon(Icons.add, color: AppTheme.textSecondary, size: 16),
                                  ),
                                  _typeChip(tertiary, rank: 3),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('RIASEC Percentage Scores',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ...sortedScores.map((entry) {
                      final type = entry.key;
                      final percentage = double.tryParse(entry.value['percentage'].toString()) ?? 0.0;
                      return _scoreCard(context, type, percentage);
                    }),
                    const SizedBox(height: 32),

                    // --- SECTION 2: SELF-ESTEEM (RSE) ---
                    _buildSectionHeader('Self-Esteem Profile (RSE)', Icons.person_pin_rounded),
                    const SizedBox(height: 12),
                    rseData == null 
                      ? const Center(child: Text('No Self-Esteem results available for this record.'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRseOverviewCard(rseData),
                            const SizedBox(height: 20),
                            Text('Scale Interpretation & Guidelines',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            _buildRseInterpretationPanel(),
                          ],
                        ),
                    const SizedBox(height: 32),

                    // --- SECTION 3: ACADEMIC BURNOUT (MBI-SS) ---
                    _buildSectionHeader('Academic Burnout Profile (MBI-SS)', Icons.psychology_rounded),
                    const SizedBox(height: 12),
                    mbiData == null 
                      ? const Center(child: Text('No Academic Burnout results available for this record.'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMbiOverviewCard(mbiData),
                            const SizedBox(height: 20),
                            Text('Academic Burnout Subscale Scores',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            _buildMbiScoreCard('EX', 'Emotional Exhaustion', mbiData['exScore'], mbiData['exLevel'], 
                                'Measures feelings of being emotionally overextended and exhausted by schoolwork.', 
                                AppTheme.error, maxVal: 6.0),
                            _buildMbiScoreCard('CY', 'Cynicism', mbiData['cyScore'], mbiData['cyLevel'], 
                                'Measures detached, cynical, or indifferent attitude towards academic commitments.', 
                                Colors.orange, maxVal: 6.0),
                            _buildMbiScoreCard('EF', 'Professional Efficacy', mbiData['efScore'], mbiData['efLevel'], 
                                'Measures feelings of academic competence and achievements. Lower efficacy signifies higher risk.', 
                                AppTheme.success, maxVal: 6.0, isEfficacy: true),
                            const SizedBox(height: 20),
                            Text('Academic Burnout Risk Scale Details',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            _buildMbiInterpretationPanel(),
                          ],
                        ),
                    const SizedBox(height: 32),

                    // --- SECTION 4: RECOMMENDED COURSES ---
                    if (recs.isNotEmpty) ...[
                      _buildSectionHeader('Recommended Courses', Icons.assignment_turned_in_rounded),
                      const SizedBox(height: 12),
                      ...recs.asMap().entries.map((entry) =>
                        _courseCard(context, entry.key + 1, entry.value as Map<String, dynamic>)),
                      const SizedBox(height: 16),

                      // Why recommended? (SHAP dynamic explanations summary)
                      _buildWhyRecommendedCard(primary, rseData, mbiData, strand),
                      const SizedBox(height: 16),

                      // Disclaimer Card
                      _buildDisclaimerCard(),
                      const SizedBox(height: 32),
                    ],

                    if (status == 'rejected') ...[
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/student/dashboard'),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake Assessment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryPurple, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryPurple,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyRecommendedCard(String primary, Map<String, dynamic>? rse, Map<String, dynamic>? mbi, String strand) {
    final interestName = AppTheme.riasecName(primary);
    final riasecText = 'Strong $interestName interest';

    String rseText = 'Healthy Self-Esteem Profile';
    if (rse != null) {
      final level = rse['level'].toString().toLowerCase();
      if (level.contains('low')) {
        rseText = 'Low Self-Esteem Profile';
      } else {
        rseText = 'High Self-Esteem';
      }
    }

    String mbiText = 'Low Academic Burnout';
    if (mbi != null) {
      final status = mbi['burnoutStatus'].toString().toLowerCase();
      if (status.contains('high') || status.contains('burnout')) {
        mbiText = 'High Academic Burnout Risk';
      } else if (status.contains('moderate') || status.contains('mod')) {
        mbiText = 'Moderate Academic Burnout Risk';
      } else {
        mbiText = 'Low Academic Burnout';
      }
    }

    String strandShort = 'Selected program';
    if (strand.contains('STEM')) strandShort = 'STEM';
    else if (strand.contains('ABM')) strandShort = 'ABM';
    else if (strand.contains('HUMSS')) strandShort = 'HUMSS';
    else if (strand.contains('GAS')) strandShort = 'GAS';
    else if (strand.contains('TVL')) strandShort = 'TVL';
    else if (strand.contains('ICT')) strandShort = 'ICT';
    else if (strand.contains('Arts')) strandShort = 'Arts & Design';
    final strandText = 'Strong compatibility with $strandShort-related programs';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why were these courses recommended?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _whyBullet(riasecText),
          _whyBullet(rseText),
          _whyBullet(mbiText),
          _whyBullet(strandText),
        ],
      ),
    );
  }

  Widget _whyBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200.withOpacity(0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'These recommendations represent the best course matches based on your assessment results. They are intended to support—not replace—your personal judgment and the guidance provided by your Guidance Counselor. While the system identifies courses that are compatible with your assessment profile, it does not guarantee academic success or future career outcomes.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String type, {required int rank}) {
    final color = AppTheme.riasecColor(type);
    return Column(
      children: [
        Text(rank == 1 ? '1st' : rank == 2 ? '2nd' : '3rd',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Chip(
          label: Text('$type - ${AppTheme.riasecName(type)}',
            style: TextStyle(fontWeight: rank == 1 ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
          backgroundColor: color.withOpacity(0.12),
          labelStyle: TextStyle(color: color),
          avatar: CircleAvatar(
            backgroundColor: color,
            child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _scoreCard(BuildContext context, String type, double percentage) {
    final color = AppTheme.riasecColor(type);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.15),
                    child: Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(AppTheme.riasecName(type), style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(AppTheme.riasecDescriptor(type),
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ]),
                Text('${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 10,
                backgroundColor: AppTheme.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseCard(BuildContext context, int rank, Map<String, dynamic> rec) {
    final type  = rec['RIASECCategory'] as String;
    final color = AppTheme.riasecColor(type);
    
    // Choose ranking colors & titles
    Color rankBgColor;
    Color rankTxtColor;
    String rankLabel;
    IconData rankIcon;
    
    if (rank == 1) {
      rankBgColor = const Color(0xFFFFD700).withOpacity(0.15); // Soft Gold
      rankTxtColor = const Color(0xFFB8860B); // Dark Gold
      rankLabel = 'Top Match';
      rankIcon = Icons.emoji_events_rounded;
    } else if (rank == 2) {
      rankBgColor = AppTheme.primaryPurple.withOpacity(0.1); // Soft Purple
      rankTxtColor = AppTheme.primaryPurple;
      rankLabel = 'Strong Match';
      rankIcon = Icons.verified_rounded;
    } else {
      rankBgColor = Colors.teal.withOpacity(0.1); // Soft Teal
      rankTxtColor = Colors.teal.shade800;
      rankLabel = 'Suitable Match';
      rankIcon = Icons.thumb_up_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.dividerColor.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left category color strip indicator
              Container(
                width: 6,
                color: color,
              ),
              
              // Card contents
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent, // Removes line separators from ExpansionTile
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    iconColor: AppTheme.primaryPurple,
                    collapsedIconColor: AppTheme.primaryPurple,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: rankBgColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: rankTxtColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(rankIcon, color: rankTxtColor, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            rankLabel,
                            style: TextStyle(
                              color: rankTxtColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      rec['CourseName'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundLight,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              rec['CourseCode'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              AppTheme.riasecName(type),
                              style: TextStyle(
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: color.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded, color: color, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Recommendation Analysis',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                rec['Explanation'] ?? '',
                                style: const TextStyle(
                                  color: Color(0xFF4A4A4A),
                                  fontSize: 13,
                                  height: 1.6,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // RSE Helpers
  Widget _buildRseOverviewCard(Map<String, dynamic> rse) {
    final int score = rse['score'] ?? 0;
    final String level = rse['level'] ?? 'Normal Self-Esteem';
    final isLow = level.toLowerCase().contains('low');
    final color = isLow ? const Color(0xFFE53E3E) : AppTheme.success;

    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2), width: 1)
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(isLow ? Icons.sentiment_very_dissatisfied : Icons.sentiment_satisfied_alt, 
                  color: color, size: 48),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              level,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              'Your RSE Score: $score / 30',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              isLow 
                ? 'Your self-esteem score suggests low self-esteem. We advise speaking with your guidance counselor for helpful self-esteem enhancement activities.'
                : 'Your self-esteem score is within the normal range. Keep nurturing a positive and healthy relationship with yourself!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRseInterpretationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor)
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Rosenberg Self-Esteem Scale (RSE) is a 10-item scale that measures global self-worth by assessing both positive and negative feelings about the self.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 12),
          Divider(),
          SizedBox(height: 12),
          Text(
            'Scoring Ranges:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Score of 15 - 30: Normal Self-Esteem range (Healthy self-worth).', 
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              )
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFE53E3E), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Score below 15: Indicates low self-esteem (May benefit from guidance discussions).', 
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              )
            ],
          ),
        ],
      ),
    );
  }

  // MBI-SS Helpers
  Widget _buildMbiOverviewCard(Map<String, dynamic> mbi) {
    final String status = mbi['burnoutStatus'] ?? 'Low Burnout Risk';
    final bool isHigh = status.toLowerCase().contains('high');
    final bool isMod = status.toLowerCase().contains('mod');
    final color = isHigh 
      ? const Color(0xFFE53E3E) 
      : isMod 
        ? AppTheme.warning 
        : AppTheme.success;

    return Card(
      elevation: 0,
      color: color.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2), width: 1)
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(
                  isHigh 
                    ? Icons.local_fire_department 
                    : isMod 
                      ? Icons.warning_amber_rounded 
                      : Icons.battery_charging_full, 
                  color: color, 
                  size: 48
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              status,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              isHigh 
                ? 'Your scores indicate a high risk of academic learning burnout. Low professional efficacy coupled with high exhaustion and cynicism shows a high strain on school-life balance. Speaking to guidance counsel is highly recommended.'
                : isMod
                  ? 'Your scores indicate a moderate burnout risk. Take steps to establish boundaries, schedule breaks, and consult guidance officers to discuss stress management.'
                  : 'Your academic burnout risk is low! Keep maintaining healthy study schedules, positive strategies, and active school-life boundaries.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMbiScoreCard(String code, String name, double score, String riskLevel, String desc, Color color, {required double maxVal, bool isEfficacy = false}) {
    // Risk level display color
    final riskColor = riskLevel.toLowerCase().contains('high') 
      ? const Color(0xFFE53E3E) 
      : riskLevel.toLowerCase().contains('mod') 
        ? AppTheme.warning 
        : AppTheme.success;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$name ($code)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text(
                    '$riskLevel Risk',
                    style: TextStyle(color: riskColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / maxVal,
                      minHeight: 8,
                      backgroundColor: AppTheme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${score.toStringAsFixed(2)} / ${maxVal.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMbiInterpretationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor)
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The Maslach Burnout Inventory - Student Survey (MBI-SS) evaluates academic learning burnout across three distinct subscales:',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary),
          ),
          SizedBox(height: 12),
          Divider(),
          SizedBox(height: 12),
          Text('Academic Burnout Ranges (Based on Subscale Item Means):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: 8),
          Text('• Emotional Exhaustion (EX):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text('  - Low: < 2.00  |  Moderate: 2.00 - 2.80  |  High: > 2.80', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          SizedBox(height: 8),
          Text('• Cynicism (CY):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text('  - Low: < 0.50  |  Moderate: 0.50 - 1.50  |  High: > 1.50', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          SizedBox(height: 8),
          Text('• Professional Efficacy (EF):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text('  - Low Burnout Risk: > 4.50  |  Moderate: 3.83 - 4.50  |  High Burnout Risk (Low Efficacy): < 3.83', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}