import 'package:flutter/material.dart';
import '../../services/admin_api.dart';
import '../../theme/app_theme.dart';

class AdminUserManage extends StatefulWidget {
  const AdminUserManage({super.key});
  @override
  State<AdminUserManage> createState() => _AdminUserManageState();
}

class _AdminUserManageState extends State<AdminUserManage> {
  List<dynamic> _students = [];
  List<dynamic> _counselors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApiService.getAllUsers();
      if (res['status'] == 'success') {
        _students = res['students'] ?? [];
        _counselors = res['counselors'] ?? [];
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _deleteUser(String role, int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to completely delete this user and all associated data? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (ok != true) return;
    
    final res = await AdminApiService.deleteUser(role, id);
    if (!mounted) return;
    if (res['status'] == 'success') {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: AppTheme.success));
       _loadUsers();
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _toggleBlockUser(String role, int id, bool blockStatus) async {
    final data = {
      'action': 'toggle_block',
      'role': role,
      'id': id,
      'isBlocked': blockStatus ? 1 : 0
    };
    final res = await AdminApiService.updateUser(data);
    if (!mounted) return;
    if (res['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account restriction updated.'), backgroundColor: AppTheme.success));
      _loadUsers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _showEditDialog(dynamic user, String role) async {
    final id = int.tryParse(user['ID'].toString()) ?? 0;
    final fNameCtrl = TextEditingController(text: user['FirstName']);
    final lNameCtrl = TextEditingController(text: user['LastName']);
    final emailCtrl = TextEditingController(text: user['Email']);
    final passCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${role == "student" ? "Student" : "Counselor"} Credentials'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fNameCtrl, decoration: const InputDecoration(labelText: 'First Name')),
              TextField(controller: lNameCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password (leave blank to keep current)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white),
            onPressed: () async {
              final data = {
                'action': 'update_profile',
                'role': role,
                'id': id,
                'firstName': fNameCtrl.text,
                'lastName': lNameCtrl.text,
                'email': emailCtrl.text,
                if (passCtrl.text.isNotEmpty) 'password': passCtrl.text,
              };
              final res = await AdminApiService.updateUser(data);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: res['status'] == 'success' ? AppTheme.success : AppTheme.error));
              }
              _loadUsers();
            },
            child: const Text('Save Changes'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Counselors', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
          const SizedBox(height: 8),
          ..._counselors.map((c) => _userTile(c, 'counselor')),
          const SizedBox(height: 24),
          Text('Students', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
          const SizedBox(height: 8),
          ..._students.map((s) => _userTile(s, 'student')),
        ],
      ),
    );
  }

  Widget _userTile(dynamic user, String role) {
    final int id = int.tryParse(user['ID'].toString()) ?? 0;
    final bool isBlocked = int.tryParse(user['IsBlocked']?.toString() ?? '0') == 1;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
         leading: CircleAvatar(
           backgroundColor: isBlocked ? Colors.grey.shade300 : (role == 'counselor' ? AppTheme.info.withOpacity(0.2) : AppTheme.success.withOpacity(0.2)),
           child: Icon(isBlocked ? Icons.block : (role == 'counselor' ? Icons.psychology : Icons.school), 
             color: isBlocked ? Colors.grey : (role == 'counselor' ? AppTheme.info : AppTheme.success)),
         ),
         title: Text('${user['FirstName']} ${user['LastName']} ${isBlocked ? "(BLOCKED)" : ""}', style: TextStyle(fontWeight: FontWeight.bold, color: isBlocked ? Colors.grey : Colors.black87)),
         subtitle: Text('${user['Email']} • ID: $id'),
         trailing: PopupMenuButton<String>(
           icon: const Icon(Icons.more_vert),
           tooltip: 'User Actions',
           onSelected: (action) {
             if (action == 'edit') _showEditDialog(user, role);
             if (action == 'block') _toggleBlockUser(role, id, !isBlocked);
             if (action == 'delete') _deleteUser(role, id);
           },
           itemBuilder: (ctx) => [
             const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit Credentials'))),
             PopupMenuItem(value: 'block', child: ListTile(leading: Icon(isBlocked ? Icons.check_circle : Icons.block), title: Text(isBlocked ? 'Unblock Account' : 'Block Account'))),
             const PopupMenuDivider(),
             const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete Data', style: TextStyle(color: Colors.red)))),
           ],
         ),
      ),
    );
  }
}
