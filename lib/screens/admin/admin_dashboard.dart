import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'admin_registration.dart';
import 'admin_user_manage.dart';
import 'admin_data_manage.dart';
import 'admin_monitoring.dart';
import 'package:go_router/go_router.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Citadel Command Center', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Row(
        children: [
          Container(
            color: AppTheme.primaryPurple,
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() => _selectedIndex = index);
              },
              unselectedIconTheme: const IconThemeData(color: Colors.white70),
              selectedIconTheme: const IconThemeData(color: Colors.white, size: 30),
              unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
              selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard),
                  label: Text('Monitoring'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.manage_accounts),
                  label: Text('Users'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_add),
                  label: Text('Register'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history_edu),
                  label: Text('Archives'),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.black12),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                AdminMonitoring(),
                AdminUserManage(),
                AdminRegistration(),
                AdminDataManage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
