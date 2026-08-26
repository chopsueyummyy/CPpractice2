import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../utils/api_config.dart';

class AdminMonitoring extends StatefulWidget {
  const AdminMonitoring({super.key});

  @override
  State<AdminMonitoring> createState() => _AdminMonitoringState();
}

class _AdminMonitoringState extends State<AdminMonitoring> {
  Map<String, dynamic>? _stats;
  List<dynamic>? _liveSessions;
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    // Refresh every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final pin = '1234567'; // In a real app, this would be the session-stored PIN or JWT token
      
      final statsRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/get_admin_stats.php'),
        headers: {"X-Admin-Pin": pin},
      );
      
      final liveRes = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/get_live_sessions.php'),
      );
      
        if (statsRes.statusCode == 200 && liveRes.statusCode == 200) {
          final statsData = jsonDecode(statsRes.body);
          final liveData = jsonDecode(liveRes.body);
          
          if (mounted) {
            setState(() {
              _stats = statsData['data']; // Changed from 'stats' to 'data'
              _liveSessions = liveData['activeSessions'];
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  
    Widget _buildStatCard(String title, String value, IconData icon, Color color) {
      return Expanded(
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(title, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ),
      );
    }
  
    @override
    Widget build(BuildContext context) {
      if (_isLoading && _stats == null) {
        return const Center(child: CircularProgressIndicator());
      }
  
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Citadel Overview', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStatCard('Active Sessions', '${_stats?['active_sessions'] ?? 0}', Icons.wifi_tethering, Colors.green),
                const SizedBox(width: 16),
                _buildStatCard('Completed Assessments', '${_stats?['completed_assessments'] ?? 0}', Icons.check_circle_outline, AppTheme.primaryPurple),
                const SizedBox(width: 16),
                _buildStatCard('Total Students', '${_stats?['total_students'] ?? 0}', Icons.people, Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard('Active Counselors', '${_stats?['total_counselors'] ?? 0}', Icons.psychology, Colors.orange),
              ],
            ),
          const SizedBox(height: 32),
          Text('Live Student Progress', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: _liveSessions == null || _liveSessions!.isEmpty
                ? Center(child: Text("No students currently taking the assessment.", style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)))
                : ListView.builder(
                    itemCount: _liveSessions!.length,
                    itemBuilder: (context, index) {
                      final session = _liveSessions![index];
                      final progress = (session['progress'] * 100).toInt();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                            child: const Icon(Icons.person, color: AppTheme.primaryPurple),
                          ),
                          title: Text(session['studentName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Question ${session['currentQuestion']} of ${session['totalQuestions']}'),
                          trailing: Container(
                            width: 100,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bolt, color: AppTheme.primaryPurple, size: 16),
                                const SizedBox(width: 4),
                                Text('$progress%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
                              ],
                            ),
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
}
