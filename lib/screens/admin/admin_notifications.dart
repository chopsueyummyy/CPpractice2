import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AdminNotifications extends StatefulWidget {
  const AdminNotifications({super.key});

  @override
  State<AdminNotifications> createState() => _AdminNotificationsState();
}

class _AdminNotificationsState extends State<AdminNotifications> {
  final _session = SessionManager();
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getAdminLogs(_session.adminId ?? 0);
      if (res['status'] == 'success') {
        setState(() => _logs = res['data']);
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Notifications',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                  ),
                  const Text('Audit trail of all administrative actions.'),
                ],
              ),
              IconButton(
                onPressed: _fetchLogs,
                icon: const Icon(Icons.refresh, color: AppTheme.primaryPurple),
                tooltip: 'Refresh Logs',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          return _buildLogCard(log);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(dynamic log) {
    final DateTime date = DateTime.parse(log['CreatedAt']);
    final String formattedDate = DateFormat('MMM d, y • h:mm a').format(date);
    
    IconData icon;
    Color color;
    
    switch (log['Action']) {
      case 'CREATE_USER':
        icon = Icons.person_add;
        color = AppTheme.success;
        break;
      case 'BLOCK_USER':
        icon = Icons.block;
        color = AppTheme.error;
        break;
      case 'UNBLOCK_USER':
        icon = Icons.check_circle;
        color = AppTheme.success;
        break;
      case 'DELETE_USER':
        icon = Icons.delete_forever;
        color = AppTheme.error;
        break;
      case 'PASSWORD_RESET':
        icon = Icons.lock_reset;
        color = AppTheme.warning;
        break;
      default:
        icon = Icons.info;
        color = AppTheme.info;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          log['Action'].replaceAll('_', ' '),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(log['Details'] ?? 'No details provided.'),
            const SizedBox(height: 4),
            Text(
              'By ${log['FirstName']} ${log['LastName']} • $formattedDate',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        trailing: Chip(
          label: Text(
            log['TargetType'].toUpperCase(),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.lilac.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: AppTheme.dividerColor),
          const SizedBox(height: 16),
          const Text('No system logs found.'),
        ],
      ),
    );
  }
}
