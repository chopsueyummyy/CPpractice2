import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/student_sidebar.dart';

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
        setState(() { _error = data['message']; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Failed to load history.'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: StudentSidebar(currentRoute: '/student/history'),
      appBar: AppBar(
        title: const Text('Assessment History'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Return to Main Menu',
            onPressed: () => context.go('/student/dashboard'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _history.isEmpty
                  ? _buildEmptyState(context)
                  : _buildHistoryList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text('No Assessment History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text('Approved or rejected assessments will appear here.',
            style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/student/dashboard'),
            icon: const Icon(Icons.quiz),
            label: const Text('Go to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    final approvedCount = _history.where((h) => h['status'] == 'approved').length;
    final rejectedCount = _history.where((h) => h['status'] == 'rejected').length;

    return Column(
      children: [
        // Stats
        Container(
          padding: const EdgeInsets.all(16.0),
          color: AppTheme.backgroundWhite,
          child: Row(
            children: [
              Expanded(child: _buildStatCard(context, 'Total Assessments',
                _history.length.toString(), Icons.assessment, AppTheme.primaryPurple)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, 'Approved',
                approvedCount.toString(), Icons.check_circle, AppTheme.success)),
              if (rejectedCount > 0) ...[
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard(context, 'Rejected',
                  rejectedCount.toString(), Icons.cancel, const Color(0xFFE53E3E))),
              ],
            ],
          ),
        ),
        // List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final item = _history[index];
              final status = item['status'] as String;
              final statusColor = status == 'approved' ? AppTheme.success : const Color(0xFFE53E3E);
              final submittedAt = item['submittedAt'] != null
                  ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(item['submittedAt']))
                  : 'Unknown date';
              final courses = List<String>.from(item['courses'] ?? []);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              backgroundColor: statusColor.withOpacity(0.1),
                              child: Icon(
                                status == 'approved' ? Icons.check_circle : Icons.cancel,
                                color: statusColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Assessment #${item['assessmentNum']}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              Text(submittedAt,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
                            ]),
                          ]),
                          Chip(
                            label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10)),
                            backgroundColor: statusColor.withOpacity(0.1),
                            labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // RIASEC types
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _typeChip(item['primaryType'] ?? '', isPrimary: true),
                          if (item['secondaryType'] != null) ...[
                            const Text('+', style: TextStyle(fontWeight: FontWeight.bold)),
                            _typeChip(item['secondaryType'], isPrimary: false),
                          ],
                          if (item['tertiaryType'] != null && item['tertiaryType'].toString().isNotEmpty && item['tertiaryType'] != 'null') ...[
                            const Text('+', style: TextStyle(fontWeight: FontWeight.bold)),
                            _typeChip(item['tertiaryType'], isPrimary: false),
                          ],
                        ],
                      ),
                      if (courses.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Recommended Courses:',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: courses.map((course) => Chip(
                            label: Text(course, style: const TextStyle(fontSize: 11)),
                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                            labelStyle: TextStyle(color: AppTheme.primaryPurple),
                          )).toList(),
                        ),
                      ],
                      if (item['rse'] != null || item['cdses'] != null) ...[
                        const Divider(height: 20),
                        if (item['rse'] != null) ...[
                          Row(
                            children: [
                              Icon(
                                item['rse']['level'].toString().toLowerCase().contains('low')
                                    ? Icons.sentiment_very_dissatisfied
                                    : Icons.sentiment_satisfied_alt,
                                color: item['rse']['level'].toString().toLowerCase().contains('low')
                                    ? const Color(0xFFE53E3E)
                                    : AppTheme.success,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Self-Esteem: Score ${item['rse']['score']}/30 (${item['rse']['level']})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (item['cdses'] != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                item['cdses']['selfEfficacyLevel'].toString().toLowerCase().contains('high')
                                    ? Icons.stars_rounded
                                    : item['cdses']['selfEfficacyLevel'].toString().toLowerCase().contains('mod')
                                        ? Icons.trending_up_rounded
                                        : Icons.info_outline_rounded,
                                color: item['cdses']['selfEfficacyLevel'].toString().toLowerCase().contains('high')
                                    ? AppTheme.success
                                    : item['cdses']['selfEfficacyLevel'].toString().toLowerCase().contains('mod')
                                        ? AppTheme.warning
                                        : const Color(0xFFE53E3E),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Career Self-Efficacy: ${item['cdses']['selfEfficacyLevel']} (Score: ${item['cdses']['totalScore'].toInt()}/125)\n'
                                  '• SA: ${item['cdses']['saScore']} | OI: ${item['cdses']['oiScore']} | '
                                  'GS: ${item['cdses']['gsScore']} | PL: ${item['cdses']['plScore']} | '
                                  'PS: ${item['cdses']['psScore']}',
                                  style: const TextStyle(fontSize: 12, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }

  Widget _typeChip(String type, {required bool isPrimary}) {
    final color = AppTheme.riasecColor(type);
    return Chip(
      label: Text('$type - ${AppTheme.riasecName(type)}',
        style: TextStyle(fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      backgroundColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: color),
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(type, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }
}