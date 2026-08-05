import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/counselor_sidebar.dart';

class StudentRecordsScreen extends StatefulWidget {
  const StudentRecordsScreen({super.key});

  @override
  State<StudentRecordsScreen> createState() => _StudentRecordsScreenState();
}

class _StudentRecordsScreenState extends State<StudentRecordsScreen> {
  final _session = SessionManager();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  // Filters
  String _status       = 'all';
  String _gradeLevel   = 'all';
  String _strand       = 'all';
  String _dominantType = 'all';
  String _rseLevel     = 'all';
  String _mbiStatus    = 'all';
  String _dateFrom     = '';
  String _dateTo       = '';
  String _search       = '';

  final _searchController = TextEditingController();

  final _statusOptions = {
    'all': 'All Statuses',
    'approved': 'Approved',
    'pending_review': 'Pending Review',
    'declined': 'Declined',
  };

  final _gradeLevelOptions = {
    'all': 'All Grade Levels',
    'Grade 11': 'Grade 11',
    'Grade 12': 'Grade 12',
  };

  final _strandOptions = {
    'all': 'All Strands',
    'STEM': 'STEM',
    'ABM': 'ABM',
    'HUMSS': 'HUMSS',
    'GAS': 'GAS',
    'TVL': 'TVL',
    'ICT': 'ICT',
    'Arts and Design': 'Arts & Design',
  };

  final _typeOptions = {
    'all': 'All RIASEC Types',
    'R': 'R - Realistic',
    'I': 'I - Investigative',
    'A': 'A - Artistic',
    'S': 'S - Social',
    'E': 'E - Enterprising',
    'C': 'C - Conventional',
  };

  final _rseOptions = {
    'all': 'All Self-Esteem Levels',
    'High Self-Esteem': 'High Self-Esteem',
    'Normal Self-Esteem': 'Normal Self-Esteem',
    'Low Self-Esteem': 'Low Self-Esteem',
  };

  final _mbiOptions = {
    'all': 'All Burnout Levels',
    'High Burnout Risk': 'High Burnout Risk',
    'Moderate Burnout Risk': 'Moderate Burnout Risk',
    'Low Burnout Risk': 'Low Burnout Risk',
  };

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getStudentRecords(
        status: _status,
        gradeLevel: _gradeLevel,
        strand: _strand,
        dominantType: _dominantType,
        rseLevel: _rseLevel,
        mbiStatus: _mbiStatus,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _search,
      );
      if (data['status'] == 'success') {
        setState(() => _records = List<Map<String, dynamic>>.from(data['records']));
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _resetFilters() {
    setState(() {
      _status       = 'all';
      _gradeLevel   = 'all';
      _strand       = 'all';
      _dominantType = 'all';
      _rseLevel     = 'all';
      _mbiStatus    = 'all';
      _dateFrom     = '';
      _dateTo       = '';
      _search       = '';
      _searchController.clear();
    });
    _loadRecords();
  }

  Future<void> _downloadCsv() async {
    try {
      final String adminId = _session.counselorId?.toString() ?? '0';
      final String roleId = _session.roleId?.toString() ?? '2';
      
      final Uri uri = Uri.parse(
        '${ApiService.baseUrl}/admin_archive.php?exportCsv=1'
        '&adminId=$adminId'
        '&roleId=$roleId'
      );
      
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $uri';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting CSV Export...'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':      return AppTheme.success;
      case 'pending_review': return AppTheme.warning;
      case 'declined':      return AppTheme.error;
      default:              return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved':      return 'Approved';
      case 'pending_review': return 'Pending Review';
      case 'declined':      return 'Declined';
      case 'in_progress':   return 'In Progress';
      default:              return status ?? 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '/guidance-counselor/student-records'),
      appBar: AppBar(
        title: const Text('Student Records'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _records.isEmpty ? null : _downloadCsv,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecords),
        ],
      ),
      body: Column(
        children: [
          // Filter panel
          Container(
            color: AppTheme.backgroundWhite,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or student ID...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                              _loadRecords();
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                  onSubmitted: (_) => _loadRecords(),
                ),
                const SizedBox(height: 12),

                // Filter dropdowns row 1
                Row(
                  children: [
                    Expanded(child: _filterDropdown('Approval Status', _statusOptions, _status,
                        (v) => setState(() => _status = v!))),
                    const SizedBox(width: 8),
                    Expanded(child: _filterDropdown('Grade Level', _gradeLevelOptions, _gradeLevel,
                        (v) => setState(() => _gradeLevel = v!))),
                  ],
                ),
                const SizedBox(height: 8),

                // Filter dropdowns row 2
                Row(
                  children: [
                    Expanded(child: _filterDropdown('Strand', _strandOptions, _strand,
                        (v) => setState(() => _strand = v!))),
                    const SizedBox(width: 8),
                    Expanded(child: _filterDropdown('Dominant Type', _typeOptions, _dominantType,
                        (v) => setState(() => _dominantType = v!))),
                  ],
                ),
                const SizedBox(height: 8),

                // Filter dropdowns row 3 (RSE and MBI-SS)
                Row(
                  children: [
                    Expanded(child: _filterDropdown('Self-Esteem (RSE)', _rseOptions, _rseLevel,
                        (v) => setState(() => _rseLevel = v!))),
                    const SizedBox(width: 8),
                    Expanded(child: _filterDropdown('Burnout Level (MBI-SS)', _mbiOptions, _mbiStatus,
                        (v) => setState(() => _mbiStatus = v!))),
                  ],
                ),
                const SizedBox(height: 8),

                // Date range + buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _dateFrom.isEmpty ? 'Date From' : _dateFrom,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _dateFrom = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _dateTo.isEmpty ? 'Date To' : _dateTo,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) setState(() => _dateTo = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _loadRecords,
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Apply Filters'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _resetFilters,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_records.length} record(s) found',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Records list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _records.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open, size: 64, color: AppTheme.textSecondary),
                            SizedBox(height: 16),
                            Text('No records found', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _records.length,
                        itemBuilder: (ctx, i) {
                          final r = _records[i];
                          final scores = r['scores'] as Map<String, dynamic>;
                          final statusColor = _statusColor(r['status']);
                          final rse = r['rse'] as Map<String, dynamic>?;
                          final mbi = r['mbi'] as Map<String, dynamic>?;
                          final recs = List<Map<String, dynamic>>.from(r['recommendations'] ?? []);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                child: Text(
                                  r['primaryType'] ?? '?',
                                  style: TextStyle(
                                    color: AppTheme.riasecColor(r['primaryType'] ?? 'R'),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                r['studentName'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                'ID: ${r['studentId']} • ${r['gradeLevel']} • ${r['strand']}',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              trailing: Chip(
                                label: Text(
                                  _statusLabel(r['status']),
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: statusColor.withOpacity(0.1),
                                side: BorderSide(color: statusColor.withOpacity(0.3)),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      // Student details chips
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _infoChip(Icons.person_outline, r['gender'] ?? '-'),
                                          _infoChip(Icons.cake_outlined, '${r['age'] ?? '-'} yrs old'),
                                          _infoChip(Icons.calendar_month_outlined, r['submittedAt'] ?? '-'),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      // RIASEC profile progress bars
                                      Text(
                                        'RIASEC Profile Scores',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                                      ),
                                      const SizedBox(height: 10),
                                      ...['R','I','A','S','E','C'].map((t) {
                                        final pct = double.tryParse((scores[t] ?? "0").toString()) ?? 0.0;
                                        final color = AppTheme.riasecColor(t);
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 110,
                                                child: Text(
                                                  '$t - ${AppTheme.riasecName(t)}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: pct / 100,
                                                    backgroundColor: AppTheme.dividerColor.withOpacity(0.3),
                                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                                    minHeight: 6,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                '${pct.toStringAsFixed(0)}%',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      const SizedBox(height: 8),
                                      // Top 3 Badge indicators
                                      Row(
                                        children: [
                                          if (r['primaryType'] != null)
                                            _typeBadge(r['primaryType'], '1st'),
                                          if (r['secondaryType'] != null) ...[
                                            const SizedBox(width: 6),
                                            _typeBadge(r['secondaryType'], '2nd'),
                                          ],
                                          if (r['tertiaryType'] != null) ...[
                                            const SizedBox(width: 6),
                                            _typeBadge(r['tertiaryType'], '3rd'),
                                          ],
                                        ],
                                      ),
                                      
                                      // Self-Esteem Profile (RSE)
                                      if (rse != null) ...[
                                        const Divider(height: 24),
                                        Text(
                                          'Self-Esteem Profile (RSE)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              rse['level'].toString().toLowerCase().contains('low')
                                                  ? Icons.sentiment_very_dissatisfied
                                                  : Icons.sentiment_satisfied_alt,
                                              color: rse['level'].toString().toLowerCase().contains('low')
                                                  ? const Color(0xFFE53E3E)
                                                  : AppTheme.success,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Score: ${rse['score']} / 30 (${rse['level']})',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ],

                                      // Academic Burnout Profile (MBI-SS)
                                      if (mbi != null) ...[
                                        const Divider(height: 24),
                                        Text(
                                          'Academic Burnout Profile (MBI-SS)',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Burnout Status: ${mbi['burnoutStatus']}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: mbi['burnoutStatus'].toString().toLowerCase().contains('high')
                                                ? const Color(0xFFE53E3E)
                                                : mbi['burnoutStatus'].toString().toLowerCase().contains('mod')
                                                    ? AppTheme.warning
                                                    : AppTheme.success,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '• Emotional Exhaustion: ${mbi['exScore']} (${mbi['exLevel']})\n'
                                          '• Cynicism: ${mbi['cyScore']} (${mbi['cyLevel']})\n'
                                          '• Professional Efficacy: ${mbi['efScore']} (${mbi['efLevel']})',
                                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textSecondary),
                                        ),
                                      ],

                                      // Recommended Courses & AI Explanations
                                      if (recs.isNotEmpty) ...[
                                        const Divider(height: 24),
                                        Text(
                                          'Recommended Courses & AI Explanations',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                                        ),
                                        const SizedBox(height: 10),
                                        ...recs.map((rec) {
                                          final explanation = rec['Explanation'] ?? '';
                                          final rank = rec['Rank'] ?? 1;
                                          final cType = rec['RIASECCategory'] ?? 'R';
                                          final cColor = AppTheme.riasecColor(cType);
                                          
                                          Color rankBgColor;
                                          Color rankTxtColor;
                                          String rankLabel;
                                          IconData rankIcon;
                                          
                                          if (rank == 1) {
                                            rankBgColor = const Color(0xFFFFD700).withOpacity(0.15);
                                            rankTxtColor = const Color(0xFFB8860B);
                                            rankLabel = 'Top Match';
                                            rankIcon = Icons.emoji_events_rounded;
                                          } else if (rank == 2) {
                                            rankBgColor = AppTheme.primaryPurple.withOpacity(0.1);
                                            rankTxtColor = AppTheme.primaryPurple;
                                            rankLabel = 'Strong Match';
                                            rankIcon = Icons.verified_rounded;
                                          } else {
                                            rankBgColor = Colors.teal.withOpacity(0.1);
                                            rankTxtColor = Colors.teal.shade800;
                                            rankLabel = 'Suitable Match';
                                            rankIcon = Icons.thumb_up_rounded;
                                          }

                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              side: BorderSide(color: AppTheme.dividerColor.withOpacity(0.5)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                ListTile(
                                                  leading: CircleAvatar(
                                                    backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                                                    child: const Icon(Icons.school, color: AppTheme.primaryPurple, size: 20),
                                                  ),
                                                  title: Text(
                                                    rec['CourseName'] ?? '',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  subtitle: Text(
                                                    '${rec['CourseCode']} • ${AppTheme.riasecName(cType)} • ✦ Match: ${(double.tryParse((rec['MatchScore'] ?? '0').toString()) ?? 0.0).toStringAsFixed(1)}%',
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                                  trailing: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: rankBgColor,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: rankTxtColor.withOpacity(0.3)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(rankIcon, color: rankTxtColor, size: 10),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          rankLabel,
                                                          style: TextStyle(color: rankTxtColor, fontWeight: FontWeight.bold, fontSize: 9),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (explanation.isNotEmpty)
                                                  Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primaryPurple.withOpacity(0.03),
                                                      borderRadius: const BorderRadius.only(
                                                        bottomLeft: Radius.circular(12),
                                                        bottomRight: Radius.circular(12),
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          explanation,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            height: 1.4,
                                                            color: Colors.purple.shade900,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        _buildShapChart(rec['shapWeights'] as Map<String, dynamic>?, Colors.purple.shade700),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ],

                                      // Counselor notes
                                      if (r['feedbackNotes'] != null && (r['feedbackNotes'] as String).isNotEmpty) ...[
                                        const Divider(height: 24),
                                        Text(
                                          'Counselor Notes',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warning.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            r['feedbackNotes'],
                                            style: const TextStyle(fontSize: 12, height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown(String label, Map<String, String> options, String value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _typeBadge(String type, String rank) {
    final color = AppTheme.riasecColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$rank: $type',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapChart(Map<String, dynamic>? weights, Color color) {
    if (weights == null || weights.isEmpty) return const SizedBox.shrink();
    
    final featureOrder = ['Strand', 'R', 'I', 'A', 'S', 'E', 'C', 'RSES', 'MBI'];
    final labels = {
      'Strand': 'Strand Compatibility',
      'R': 'Realistic (R)',
      'I': 'Investigative (I)',
      'A': 'Artistic (A)',
      'S': 'Social (S)',
      'E': 'Enterprising (E)',
      'C': 'Conventional (C)',
      'RSES': 'Rosenberg Self-Esteem',
      'MBI': 'Burnout Resilience',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                '✦ AI Diagnostics (SHAP Feature Attribution):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...featureOrder.map((feat) {
            final weight = double.tryParse(weights[feat]?.toString() ?? '0.0') ?? 0.0;
            if (weight == 0.0) return const SizedBox.shrink();
            
            const double maxRef = 3.0;
            final double absoluteVal = weight.abs();
            final double barWidthRatio = (absoluteVal / maxRef).clamp(0.02, 1.0);
            
            final bool isPositive = weight > 0;
            final Color barColor = isPositive ? AppTheme.success : const Color(0xFFE53E3E);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      labels[feat] ?? feat,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: barWidthRatio,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '${isPositive ? "+" : ""}${weight.toStringAsFixed(2)}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: barColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}