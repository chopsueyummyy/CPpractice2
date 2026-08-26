import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../services/session_manager.dart';

class CounselorSidebar extends StatelessWidget {
  final String currentRoute;

  const CounselorSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Header
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Guidance Counselor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Career Assessment Suite',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation Items
          _buildNavItem(
            context,
            icon: Icons.dashboard,
            title: 'Dashboard',
            route: '/guidance-counselor/dashboard',
            isSelected: currentRoute == '/guidance-counselor/dashboard',
          ),
          _buildNavItem(
            context,
            icon: Icons.monitor_heart,
            title: 'Monitor Assessments',
            route: '/guidance-counselor/monitoring',
            isSelected: currentRoute == '/guidance-counselor/monitoring',
          ),
          _buildNavItem(
            context,
            icon: Icons.pending_actions,
            title: 'Pending Approvals',
            route: '/guidance-counselor/pending-approvals',
            isSelected: currentRoute == '/guidance-counselor/pending-approvals',
          ),
          _buildNavItem(
            context,
            icon: Icons.people,
            title: 'Student Records',
            route: '/guidance-counselor/student-records',
            isSelected: currentRoute == '/guidance-counselor/student-records',
          ),
          _buildNavItem(
            context,
            icon: Icons.psychology,
            title: 'Student Feedback',
            route: '/guidance-counselor/ai-feedback',
            isSelected: currentRoute == '/guidance-counselor/ai-feedback',
          ),
          const Divider(),
          
          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: const Color(0xFFE53E3E)),
            title: const Text(
              'Logout',
              style: TextStyle(color: const Color(0xFFE53E3E)),
            ),
            onTap: () {
              SessionManager().logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryPurple : AppTheme.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryPurple.withOpacity(0.1),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (currentRoute != route) {
          context.go(route);
        }
      },
    );
  }
}