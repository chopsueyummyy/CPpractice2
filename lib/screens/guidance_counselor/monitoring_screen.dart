import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/counselor_sidebar.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _sessions = [];
  int _completedToday = 0;
  bool _isLoading = true;
  bool _isBackgroundSyncing = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSessions(isBackground: false);
    // Auto-refresh every 10 seconds in background
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadSessions(isBackground: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Instantly refresh when counselor returns focus to tab/window
      _loadSessions(isBackground: true);
    }
  }

  Future<void> _loadSessions({bool isBackground = false}) async {
    if (!mounted) return;

    if (!isBackground) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isBackgroundSyncing = true);
    }

    try {
      final data = await ApiService.getLiveSessions();
      if (data['status'] == 'success' && mounted) {
        final activeList = List<Map<String, dynamic>>.from(data['activeSessions'] ?? []);
        final completed = data['completedToday'] ?? 0;
        setState(() {
          _sessions = activeList;
          _completedToday = completed;
          _isLoading = false;
          _isBackgroundSyncing = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isBackgroundSyncing = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isBackgroundSyncing = false;
        });
      }
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
    final isPsych = SessionManager().isPsychometrician;
    final prefix = isPsych ? '/psychometrician' : '/guidance-counselor';

    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '$prefix/monitoring'),
      appBar: AppBar(
        title: const Text('Live Assessment Monitoring'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          // Background syncing indicator
          if (_isBackgroundSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryPurple),
              ),
            ),

          // Live indicator badge
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
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Now',
            onPressed: () => _loadSessions(isBackground: false),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Dashboard',
            onPressed: () => context.go('$prefix/dashboard'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top Summary Header
                Container(
                  color: AppTheme.primaryPurple.withOpacity(0.04),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat(
                        context,
                        icon: Icons.people_outline,
                        label: 'Active Test-Takers',
                        value: '${_sessions.length}',
                        color: AppTheme.primaryPurple,
                      ),
                      _buildSummaryStat(
                        context,
                        icon: Icons.check_circle_outline,
                        label: 'Completed Today',
                        value: '$_completedToday',
                        color: AppTheme.success,
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Active Sessions List
                Expanded(
                  child: _sessions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.hourglass_empty_rounded, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'No Active Test Sessions',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Students currently taking the assessment will appear here in real-time.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sessions.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final session = _sessions[i];
                            final duration = _formatDuration(session['duration'] ?? session['durationSeconds'] ?? 0);
                            final answered = session['currentQuestion'] ?? session['answeredQuestions'] ?? 0;
                            final total = session['totalQuestions'] ?? 77;
                            final progress = total > 0 ? (answered / total).clamp(0.0, 1.0) : 0.0;

                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                          child: Text(
                                            (session['studentName'] ?? 'S')[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: AppTheme.primaryPurple,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                session['studentName'] ?? 'Student',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Text(
                                                'ID: ${session['studentId'] ?? "-"} • ${session['strand'] ?? "N/A"}',
                                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Chip(
                                          avatar: const Icon(Icons.timer_outlined, size: 14, color: AppTheme.primaryPurple),
                                          label: Text(duration, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          backgroundColor: AppTheme.primaryPurple.withOpacity(0.08),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Progress: $answered / $total questions',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ],
    );
  }
}