import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/counselor_sidebar.dart';

class CounselorDashboard extends StatefulWidget {
  const CounselorDashboard({super.key});

  @override
  State<CounselorDashboard> createState() => _CounselorDashboardState();
}

class _CounselorDashboardState extends State<CounselorDashboard> {
  final _session = SessionManager();
  String _timeFilter = 'today';
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
    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '/guidance-counselor/dashboard'),
      appBar: AppBar(
        title: const Text('Counselor Dashboard'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _session.logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile picture settings coming soon!')),
                          );
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: AppTheme.primaryPurple.withOpacity(0.15),
                          child: const Icon(Icons.psychology, size: 30, color: AppTheme.primaryPurple),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${_session.counselorFirstName ?? 'Counselor'}!',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Monitor student assessments and review recommendations.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Time filter
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('Today')),
                  ButtonSegment(value: 'week',  label: Text('This Week')),
                  ButtonSegment(value: 'month', label: Text('This Month')),
                  ButtonSegment(value: 'all',   label: Text('All Time')),
                ],
                selected: {_timeFilter},
                onSelectionChanged: (s) {
                  setState(() => _timeFilter = s.first);
                  _loadStats();
                },
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Local stats variables
                () {
                  final strandStats = List<Map<String, dynamic>>.from(_stats['strandStats'] ?? []);
                  final riasecStats = List<Map<String, dynamic>>.from(_stats['riasecStats'] ?? []);
                  final rseStats = List<Map<String, dynamic>>.from(_stats['rseStats'] ?? []);
                  final mbiStats = List<Map<String, dynamic>>.from(_stats['mbiStats'] ?? []);
                  final recentActivity = List<Map<String, dynamic>>.from(_stats['recentActivity'] ?? []);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stat cards
                      Row(
                        children: [
                          Expanded(child: _statCard(
                            context, 'Pending Approvals',
                            '${_stats['pendingCount'] ?? 0}',
                            Icons.pending_actions_rounded, AppTheme.warning,
                            () => context.go('/guidance-counselor/pending-approvals'),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _statCard(
                            context, 'Total Students',
                            '${_stats['totalStudents'] ?? 0}',
                            Icons.people_alt_rounded, AppTheme.info,
                            () => context.go('/guidance-counselor/student-records'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _statCard(
                            context, 'Assessments Today',
                            '${_stats['assessmentsToday'] ?? 0}',
                            Icons.assessment_rounded, AppTheme.success,
                            () => context.go('/guidance-counselor/monitoring'),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _statCard(
                            context, 'Live Now',
                            '${_stats['inProgress'] ?? 0}',
                            Icons.sensors_rounded, AppTheme.primaryPurple,
                            () => context.go('/guidance-counselor/monitoring'),
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Analytics rate overview card
                      Card(
                        elevation: 0,
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
                                children: [
                                  const Icon(Icons.analytics_rounded, color: AppTheme.primaryPurple),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Analytics Overview',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(child: _analyticItem(
                                    'Approval Rate',
                                    '${_stats['approvalRate'] ?? 0}%',
                                    AppTheme.success,
                                    Icons.trending_up_rounded,
                                  )),
                                  const SizedBox(width: 16),
                                  Expanded(child: _analyticItem(
                                    'Feedback Given',
                                    '${_stats['feedbackGiven'] ?? 0}',
                                    AppTheme.primaryPurple,
                                    Icons.feedback_rounded,
                                  )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // RIASEC Dominant Interest Distribution
                      _buildRiasecDistributionCard(riasecStats),
                      const SizedBox(height: 24),

                      // Strand Distribution
                      _buildStrandStatsCard(strandStats),
                      const SizedBox(height: 24),

                      // RSE Profile + MBI-SS Profile side-by-side
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRseStatsCard(rseStats)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildMbiStatsCard(mbiStats)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Recent activity logs
                      _buildRecentActivityCard(recentActivity),
                    ],
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminPinDialog(BuildContext context) {
    final TextEditingController _pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Admin Access'),
        content: TextField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 7,
          decoration: const InputDecoration(
            labelText: 'Enter 7-Digit PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_pinController.text.trim() == '1234567') {
                Navigator.pop(ctx);
                context.push('/admin/dashboard');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid PIN')),
                );
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _analyticItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRiasecDistributionCard(List<Map<String, dynamic>> riasecStats) {
    final map = {for (var s in riasecStats) s['type'].toString(): s['count'] as int};
    final total = map.values.fold(0, (sum, val) => sum + val);

    return Card(
      elevation: 0,
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
              children: [
                const Icon(Icons.pie_chart_rounded, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                const Text('Dominant Career Interests (Primary Types)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No approved assessment results yet.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              ...['R','I','A','S','E','C'].map((t) {
                final count = map[t] ?? 0;
                final pct = total > 0 ? count / total : 0.0;
                final color = AppTheme.riasecColor(t);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          '$t - ${AppTheme.riasecName(t)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$count student(s)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStrandStatsCard(List<Map<String, dynamic>> strandStats) {
    final total = strandStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
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
              children: [
                const Icon(Icons.school_rounded, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                const Text('Strand Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const SizedBox(
                height: 100,
                child: Center(
                  child: Text('No strand data available.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              Column(
                children: strandStats.map((item) {
                  final strandName = item['strand'].toString();
                  final count = item['count'] as int;
                  final pct = total > 0 ? count / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(strandName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('$count student(s)', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                            minHeight: 6,
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

  Widget _buildRseStatsCard(List<Map<String, dynamic>> rseStats) {
    final total = rseStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
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
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFE53E3E)),
                const SizedBox(width: 8),
                const Text(
                  'Self-Esteem (RSE)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const SizedBox(
                height: 120,
                child: Center(
                  child: Text('No self-esteem data available.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else ...[
              Row(
                children: rseStats.map((item) {
                  final level = item['level'].toString();
                  final count = item['count'] as int;
                  final isLow = level.toLowerCase().contains('low');
                  final color = isLow ? const Color(0xFFE53E3E) : AppTheme.success;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            level,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count Student(s)',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Identifies students with low self-esteem levels who may benefit from academic self-worth enrichment programs.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMbiStatsCard(List<Map<String, dynamic>> mbiStats) {
    final total = mbiStats.fold(0, (sum, item) => sum + (item['count'] as int));

    return Card(
      elevation: 0,
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
              children: [
                const Icon(Icons.local_fire_department_rounded, color: AppTheme.warning),
                const SizedBox(width: 8),
                const Text(
                  'Academic Burnout (MBI-SS)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (total == 0)
              const SizedBox(
                height: 120,
                child: Center(
                  child: Text('No academic burnout data available.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else ...[
              ...mbiStats.map((item) {
                final status = item['status'].toString();
                final count = item['count'] as int;
                final isHigh = status.toLowerCase().contains('high');
                final isMod = status.toLowerCase().contains('mod');
                final color = isHigh ? const Color(0xFFE53E3E) : isMod ? AppTheme.warning : AppTheme.success;
                final pct = total > 0 ? count / total : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                          Text('$count Student(s)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 4),
              const Text(
                'Monitors levels of emotional exhaustion, cynicism, and professional efficacy among students.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard(List<Map<String, dynamic>> recentActivity) {
    return Card(
      elevation: 0,
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
              children: [
                const Icon(Icons.history_rounded, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                const Text('Recent Student Activities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            if (recentActivity.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No student activity logged yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentActivity.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final act = recentActivity[index];
                  final isApproved = act['status'].toString() == 'approved';
                  final color = isApproved ? AppTheme.success : AppTheme.warning;
                  return Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: color.withOpacity(0.1),
                        radius: 16,
                        child: Icon(isApproved ? Icons.check : Icons.hourglass_top, color: color, size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              act['studentName'] ?? 'Anonymous Student',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Strand: ${act['strand']} • Submitted: ${act['submittedAt']}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          isApproved ? 'Approved' : 'Pending',
                          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}