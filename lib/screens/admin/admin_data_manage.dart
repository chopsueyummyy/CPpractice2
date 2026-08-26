import 'package:flutter/material.dart';
import '../../services/admin_api.dart';
import '../../theme/app_theme.dart';

class AdminDataManage extends StatefulWidget {
  const AdminDataManage({super.key});
  @override
  State<AdminDataManage> createState() => _AdminDataManageState();
}

class _AdminDataManageState extends State<AdminDataManage> {
  List<dynamic> _archives = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await AdminApiService.getArchives();
      if (res['status'] == 'success') _archives = res['archives'] ?? [];
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _invalidate(int assessmentId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Invalidate Document'),
        content: const Text('If you invalidate this assessment, its status changes to "Declined". This fundamentally erases its verified presence and forces the student to retake the exam. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Invalidate Now', style: TextStyle(color: Colors.red))),
        ],
      )
    );
    if (ok != true) return;
    
    final res = await AdminApiService.invalidateRecord(assessmentId);
    if (!mounted) return;
    if (res['status'] == 'success') {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']), backgroundColor: AppTheme.success));
       _loadData();
    } else {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _viewArchiveDetails(int assessmentId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    final res = await AdminApiService.getArchiveDetails(assessmentId);
    if (!mounted) return;
    Navigator.pop(context); // close loader
    
    if (res['status'] != 'success' || res['details'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch detailed records. Note: Assessment has not been verified yet.'), backgroundColor: AppTheme.error));
      return;
    }
    
    final results = res['details']['results'];
    final reqs = res['details']['recommendations'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deep Dive (Assesment #$assessmentId)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryPurple)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 const Text('RIASEC Competency Graph:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 const SizedBox(height: 8),
                 _scoreRow('Realistic', results['R_Percentage']),
                 _scoreRow('Investigative', results['I_Percentage']),
                 _scoreRow('Artistic', results['A_Percentage']),
                 _scoreRow('Social', results['S_Percentage']),
                 _scoreRow('Enterprising', results['E_Percentage']),
                 _scoreRow('Conventional', results['C_Percentage']),
                 const Divider(height: 32),
                 const Text('Computed Course Path:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 const SizedBox(height: 8),
                 if (reqs.isEmpty) const Text("No generated curriculum maps linked yet."),
                 ...reqs.map((r) => ListTile(
                   contentPadding: EdgeInsets.zero,
                   leading: CircleAvatar(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white, child: Text(r['Rank'].toString())),
                   title: Text(r['CourseName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                   subtitle: Text('Match Confidence: ${r['MatchScore']}%'),
                 )),
              ],
            )
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white), child: const Text('Close Archive')),
        ]
      )
    );
  }

  Widget _scoreRow(String label, dynamic score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text('$score%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  void _exportCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading CSV data structure to your machine...'), backgroundColor: AppTheme.info)
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportCSV,
        icon: const Icon(Icons.download),
        label: const Text('Export Structure'),
        backgroundColor: AppTheme.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView.builder(
          padding: const EdgeInsets.all(24).copyWith(bottom: 80),
          itemCount: _archives.length,
          itemBuilder: (context, index) {
            final item = _archives[index];
            final int aId = int.tryParse(item['AssessmentID'].toString()) ?? 0;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () => _viewArchiveDetails(aId),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text('${item['FirstName']} ${item['LastName']} (ID: $aId)', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Current Substate: ${item['Status'].toString().toUpperCase()}\nTaken: ${item['StartedAt']}\nTap to Read Complete Archive Report.'),
                trailing: (item['Status'] == 'in_progress' || item['Status'] == 'declined') ? null : IconButton(
                  icon: const Icon(Icons.block, color: AppTheme.warning),
                  tooltip: 'Invalidate / Decline Record',
                  onPressed: () => _invalidate(aId),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
