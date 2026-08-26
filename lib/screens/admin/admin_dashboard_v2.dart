import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../../services/session_manager.dart';
import 'admin_monitoring.dart';
import 'admin_registration_v2.dart';
import 'admin_user_manage_v2.dart';
import 'admin_archive_v2.dart';
import 'admin_notifications.dart';

class AdminDashboardV2 extends StatefulWidget {
  const AdminDashboardV2({super.key});

  @override
  State<AdminDashboardV2> createState() => _AdminDashboardV2State();
}

class _AdminDashboardV2State extends State<AdminDashboardV2> {
  final _session = SessionManager();
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Determine admin name for display
    final String adminName = _session.counselorFirstName ?? 'Admin';
    final bool isSuper = _session.roleId == 4;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSuper ? AppTheme.primaryYellow : AppTheme.lilac,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isSuper ? 'SUPER ADMIN' : 'ADMIN',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Citadel Command Center', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: AppTheme.primaryPurple,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                'Welcome, $adminName',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new),
            tooltip: 'Logout',
            onPressed: () {
              _session.logout();
              context.go('/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            width: 240,
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              extended: true,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              unselectedIconTheme: IconThemeData(color: AppTheme.textSecondary),
              selectedIconTheme: const IconThemeData(color: AppTheme.primaryPurple, size: 28),
              unselectedLabelTextStyle: TextStyle(color: AppTheme.textSecondary),
              selectedLabelTextStyle: const TextStyle(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold),
              indicatorColor: AppTheme.primaryPurple.withOpacity(0.1),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.analytics_outlined), 
                  selectedIcon: Icon(Icons.analytics),
                  label: Text('Live Monitoring')
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.person_add_outlined), 
                  selectedIcon: Icon(Icons.person_add),
                  label: Text('Registration')
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.manage_accounts_outlined), 
                  selectedIcon: Icon(Icons.manage_accounts),
                  label: Text('User Control')
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.archive_outlined), 
                  selectedIcon: Icon(Icons.archive),
                  label: Text('Archiving')
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.notifications_active_outlined), 
                  selectedIcon: Icon(Icons.notifications_active),
                  label: Text('Notifications')
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppTheme.backgroundLight,
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  AdminMonitoring(),
                  AdminRegistrationV2(),
                  AdminUserManageV2(),
                  AdminArchiveV2(),
                  AdminNotifications(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
