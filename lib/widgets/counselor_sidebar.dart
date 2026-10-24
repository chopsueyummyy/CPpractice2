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
    final isPsych = SessionManager().isPsychometrician || currentRoute.startsWith('/psychometrician');
    final prefix = isPsych ? '/psychometrician' : '/guidance-counselor';

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
                    child: Icon(
                      isPsych ? Icons.analytics_outlined : Icons.psychology,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isPsych ? 'Psychometrician' : 'Guidance Counselor/Facilitator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isPsych ? 20 : 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isPsych ? 'Testing & Psychometrics Suite' : 'Career Counseling & Facilitation Suite',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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
            route: '$prefix/dashboard',
            isSelected: currentRoute == '$prefix/dashboard',
          ),
          _buildNavItem(
            context,
            icon: Icons.monitor_heart,
            title: 'Monitor Assessments',
            route: '$prefix/monitoring',
            isSelected: currentRoute == '$prefix/monitoring',
          ),
          _buildNavItem(
            context,
            icon: Icons.pending_actions,
            title: isPsych ? 'Pending Evaluations' : 'Endorsed Queue',
            route: '$prefix/pending-approvals',
            isSelected: currentRoute == '$prefix/pending-approvals',
          ),
          _buildNavItem(
            context,
            icon: Icons.people,
            title: isPsych ? 'Test Records Archive' : 'Student Records',
            route: '$prefix/student-records',
            isSelected: currentRoute == '$prefix/student-records',
          ),
          _buildNavItem(
            context,
            icon: isPsych ? Icons.psychology_outlined : Icons.rate_review_outlined,
            title: isPsych ? 'Psychometric Evaluation & Review' : 'Student Result',
            route: '$prefix/ai-feedback',
            isSelected: currentRoute == '$prefix/ai-feedback',
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
              context.go('/staff/login');
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