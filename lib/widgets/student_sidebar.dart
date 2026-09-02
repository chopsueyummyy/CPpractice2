import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/session_manager.dart';

class StudentSidebar extends StatelessWidget {
  final String currentRoute;

  const StudentSidebar({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final session = SessionManager();
    final status = session.assessmentStatus;
    final isLocked = status == 'pending_review' || status == 'approved';

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
                      Icons.person,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Student Portal',
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
            icon: Icons.quiz,
            title: 'Career Assessment',
            route: '/student/dashboard',
            isSelected: currentRoute == '/student/assessment' ||
                      currentRoute == '/student/student-details' ||
                      currentRoute == '/student/assessment-instructions',
            isEnabled: !isLocked,
          ),
          _buildNavItem(
            context,
            icon: Icons.assessment,
            title: 'View Results',
            route: '/student/results',
            isSelected: currentRoute == '/student/results',
          ),
          _buildNavItem(
            context,
            icon: Icons.history,
            title: 'History',
            route: '/student/history',
            isSelected: currentRoute == '/student/history',
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.dashboard,
            title: 'Main Menu',
            route: '/student/dashboard',
            isSelected: currentRoute == '/student/dashboard',
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
              session.logout();
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
    bool isEnabled = true,
  }) {
    final color = isEnabled 
        ? (isSelected ? AppTheme.primaryPurple : AppTheme.textPrimary)
        : Colors.grey.shade400;

    return ListTile(
      enabled: isEnabled,
      leading: Icon(
        isEnabled && isSelected ? icon : icon,
        color: isEnabled 
            ? (isSelected ? AppTheme.primaryPurple : AppTheme.textSecondary)
            : Colors.grey.shade400,
      ),
      title: Text(
        !isEnabled ? '$title (Locked)' : title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: color,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryPurple.withOpacity(0.1),
      onTap: isEnabled ? () {
        Navigator.pop(context); // Close drawer
        if (currentRoute != route) {
          context.go(route);
        }
      } : null,
    );
  }
}
