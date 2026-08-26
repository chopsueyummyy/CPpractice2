import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../widgets/counselor_sidebar.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  List<Map<String, dynamic>> _sessions = [];
  int _completedToday = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadSessions());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      final data = await ApiService.getLiveSessions();
      if (data['status'] == 'success' && mounted) {
        setState(() {
          _sessions       = List<Map<String, dynamic>>.from(data['activeSessions']);
          _completedToday = data['completedToday'] ?? 0;
          _isLoading      = false;
        });
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '/guidance-counselor/monitoring'),
      appBar: AppBar(
        title: const Text('Live Assessment Monitoring'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          // Live indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.success),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text('LIVE', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSessions),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/guidance-counselor/dashboard'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner
                if (_sessions.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: AppTheme.primaryPurple.withOpacity(0.08),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.primaryPurple),
                        const SizedBox(width: 12),
                        Text(
                          '${_sessions.length} student(s) currently taking the assessment',
                          style: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                // Stats bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppTheme.backgroundWhite,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem('In Progress', '${_sessions.length}', AppTheme.primaryPurple),
                      _statItem('Completed Today', '$_completedToday', AppTheme.success),
                    ],
                  ),
                ),

                Expanded(
                  child: _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assessment_outlined, size: 64, color: AppTheme.textSecondary),
                              const SizedBox(height: 16),
                              Text(
                                'No Active Assessments',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Students currently taking the assessment will appear here.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: _loadSessions,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSessions,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _sessions.length,
                            itemBuilder: (ctx, i) {
                              final s = _sessions[i];
                              final progress = (s['progress'] as num).toDouble();
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
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                                child: const Icon(Icons.person, color: AppTheme.primaryPurple),
                                              ),
                                              const SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    s['studentName'],
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  Text(
                                                    'ID: ${s['studentId']} • ${s['gradeLevel']}',
                                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Chip(
                                            label: const Text('IN PROGRESS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                            labelStyle: const TextStyle(color: AppTheme.primaryPurple),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Progress',
                                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                          Text(
                                            '${s['currentQuestion']}/${s['totalQuestions']} questions',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 8,
                                          backgroundColor: AppTheme.dividerColor,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Time elapsed: ${_formatDuration(s['duration'])}',
                                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                          const Spacer(),
                                          Text(
                                            s['strand'],
                                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}