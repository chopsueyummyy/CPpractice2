import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class AdminUserManageV2 extends StatefulWidget {
  const AdminUserManageV2({super.key});

  @override
  State<AdminUserManageV2> createState() => _AdminUserManageV2State();
}

class _AdminUserManageV2State extends State<AdminUserManageV2> {
  final _session = SessionManager();
  bool _isLoading = true;
  
  List<dynamic> _students = [];
  List<dynamic> _counselors = [];
  List<dynamic> _admins = [];
  
  String _searchQuery = '';
  String _selectedTab = 'Students';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getAdminUsers(_session.adminId ?? 0, _session.roleId ?? 0);
      if (res['status'] == 'success') {
        setState(() {
          _students = res['data']['students'] ?? [];
          _counselors = res['data']['counselors'] ?? [];
          _admins = res['data']['admins'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAction(String action, String targetType, dynamic targetId, {int? isBlocked, String? newPassword}) async {
    // Hierarchy safeguard: Admins cannot touch other admins
    if (_session.roleId != 4 && targetType == 'admin') {
      _showSnackBar('Unauthorized: Only Super Admins can manage other Admins.', AppTheme.error);
      return;
    }

    try {
      final res = await ApiService.manageAdminUser({
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        'isBlocked': isBlocked,
        'newPassword': newPassword,
        'reqAdminId': _session.adminId,
        'reqRoleId': _session.roleId,
      });

      if (res['status'] == 'success') {
        _showSnackBar(res['message'], AppTheme.success);
        _fetchUsers(); // Refresh
      } else {
        _showSnackBar(res['message'], AppTheme.error);
      }
    } catch (e) {
      _showSnackBar('Transaction failed. Check connection.', AppTheme.error);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _showPasswordResetDialog(String targetType, dynamic targetId, String name) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Password for $name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New Password', hintText: 'Enter at least 8 characters'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length < 6) return;
              Navigator.pop(context);
              _handleAction('change_password', targetType, targetId, newPassword: controller.text);
            },
            child: const Text('Reset Keys'),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredList() {
    List<dynamic> baseList;
    if (_selectedTab == 'Students') baseList = _students;
    else if (_selectedTab == 'Counselors') baseList = _counselors;
    else baseList = _admins;

    if (_searchQuery.isEmpty) return baseList;
    
    return baseList.where((u) {
      final fullName = '${u['firstName']} ${u['lastName']}'.toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final id = (u['id'] ?? '').toString().toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase()) || 
             email.contains(_searchQuery.toLowerCase()) ||
             id.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildUserList(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Control',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryPurple,
          ),
        ),
        const Text('Manage, block, and secure system accounts.'),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'Students', label: Text('Students'), icon: Icon(Icons.school_outlined)),
              const ButtonSegment(value: 'Counselors', label: Text('Counselors'), icon: Icon(Icons.psychology_outlined)),
              if (_session.roleId == 4)
                const ButtonSegment(value: 'Admins', label: Text('Admins'), icon: Icon(Icons.admin_panel_settings_outlined)),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _selectedTab = newSelection.first);
            },
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 300,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(List<dynamic> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppTheme.dividerColor),
            const SizedBox(height: 16),
            const Text('No matching users found.'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final bool isBlocked = (user['isBlocked'].toString() == '1');
        final String targetType = _selectedTab == 'Students' ? 'student' : (_selectedTab == 'Counselors' ? 'counselor' : 'admin');
        
        final String firstName = user['firstName'] ?? '';
        final String lastName = user['lastName'] ?? '';
        final String fullName = (firstName.isEmpty && lastName.isEmpty) ? 'Unidentified Student' : '$firstName $lastName';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.5)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isBlocked ? AppTheme.error.withOpacity(0.1) : AppTheme.primaryPurple.withOpacity(0.1),
              child: Icon(
                _selectedTab == 'Students' ? Icons.person : Icons.verified_user, 
                color: isBlocked ? AppTheme.error : AppTheme.primaryPurple
              ),
            ),
            title: Text(
              fullName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isBlocked ? TextDecoration.lineThrough : null,
                color: (firstName.isEmpty && lastName.isEmpty) ? AppTheme.textSecondary : null,
                fontStyle: (firstName.isEmpty && lastName.isEmpty) ? FontStyle.italic : null,
              ),
            ),
            subtitle: Text(user['email'] ?? 'No email associated'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBlocked)
                  const Chip(
                    label: Text('SUSPENDED', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: AppTheme.error,
                    padding: EdgeInsets.zero,
                  ),
                const SizedBox(width: 8),
                if (!(_selectedTab == 'Admins' && user['roleId'].toString() == '4'))
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'block') _handleAction('toggle_block', targetType, user['id'], isBlocked: isBlocked ? 0 : 1);
                      if (val == 'password') _showPasswordResetDialog(targetType, user['id'], '${user['firstName']} ${user['lastName']}');
                      if (val == 'delete') _confirmDelete(targetType, user['id'], '${user['firstName']} ${user['lastName']}');
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'password',
                        child: Row(children: const [Icon(Icons.lock_outline, size: 18), SizedBox(width: 8), Text('Reset Password')]),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(isBlocked ? Icons.check_circle_outline : Icons.block_flipped, size: 18), 
                            const SizedBox(width: 8), 
                            Text(isBlocked ? 'Lift Suspension' : 'Suspend Account')
                          ],
                        ),
                      ),
                      if (_session.roleId == 4) // Only Super Admin can delete
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: const [
                              Icon(Icons.delete_outline, size: 18, color: AppTheme.error), 
                              SizedBox(width: 8), 
                              Text('Permanently Delete', style: TextStyle(color: AppTheme.error))
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String targetType, dynamic targetId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanent Deletion', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold)),
        content: Text('Are you absolutely sure you want to delete the account for $name?\n\nThis action is irreversible and will remove all associated assessment data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleAction('delete', targetType, targetId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete Irreversibly'),
          ),
        ],
      ),
    );
  }
}
