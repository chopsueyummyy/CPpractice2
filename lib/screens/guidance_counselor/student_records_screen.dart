import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/counselor_sidebar.dart';
import '../../widgets/jmcfi_badge.dart';

class StudentRecordsScreen extends StatefulWidget {
  const StudentRecordsScreen({super.key});

  @override
  State<StudentRecordsScreen> createState() => _StudentRecordsScreenState();
}

class _StudentRecordsScreenState extends State<StudentRecordsScreen> with WidgetsBindingObserver {
  final _session = SessionManager();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  Timer? _debounceTimer;
  Timer? _autoRefreshTimer;
  final _scrollController = ScrollController();

  // Pagination (5 students per page)
  int _currentPage = 0;
  static const int _pageSize = 5;

  int get _totalPages => (_records.isEmpty) ? 1 : ((_records.length - 1) ~/ _pageSize) + 1;

  List<Map<String, dynamic>> get _pagedRecords {
    if (_records.isEmpty) return [];
    final start = _currentPage * _pageSize;
    if (start >= _records.length) return [];
    final end = (start + _pageSize).clamp(0, _records.length);
    return _records.sublist(start, end);
  }

  // Filters
  String _status       = 'all';
  String _gradeLevel   = 'all';
  String _strand       = 'all';
  String _dominantType = 'all';
  String _rseLevel     = 'all';
  String _cdsesLevel   = 'all';
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

  final _cdsesOptions = {
    'all': 'All Self-Efficacy Levels',
    'High Career Decision Self-Efficacy': 'High Self-Efficacy',
    'Moderate Career Decision Self-Efficacy': 'Moderate Self-Efficacy',
    'Low Career Decision Self-Efficacy': 'Low Self-Efficacy',
  };

  bool _isFilterExpanded = false;

  int get _activeFilterCount {
    int count = 0;
    if (_status != 'all') count++;
    if (_gradeLevel != 'all') count++;
    if (_strand != 'all') count++;
    if (_dominantType != 'all') count++;
    if (_rseLevel != 'all') count++;
    if (_cdsesLevel != 'all') count++;
    if (_dateFrom.isNotEmpty) count++;
    if (_dateTo.isNotEmpty) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRecords();
    // Auto-refresh every 20 seconds in background
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _loadRecords(isBackground: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadRecords(isBackground: true);
    }
  }

  Future<void> _loadRecords({bool isBackground = false}) async {
    if (!mounted) return;
    if (!isBackground) {
      setState(() => _isLoading = true);
    }
    try {
      final data = await ApiService.getStudentRecords(
        status: _status,
        gradeLevel: _gradeLevel,
        strand: _strand,
        dominantType: _dominantType,
        rseLevel: _rseLevel,
        cdsesLevel: _cdsesLevel,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        search: _search,
      );
      if (data['status'] == 'success' && mounted) {
        setState(() {
          _records = List<Map<String, dynamic>>.from(data['records']);
          if (_currentPage >= _totalPages) {
            _currentPage = 0;
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _resetFilters() {
    setState(() {
      _status       = 'all';
      _gradeLevel   = 'all';
      _strand       = 'all';
      _dominantType = 'all';
      _rseLevel     = 'all';
      _cdsesLevel   = 'all';
      _dateFrom     = '';
      _dateTo       = '';
      _search       = '';
      _currentPage  = 0;
      _searchController.clear();
    });
    _loadRecords();
  }

  Future<void> _downloadPdfSummary() async {
    try {
      final String adminId = _session.counselorId?.toString() ?? '0';
      final String roleId = _session.roleId?.toString() ?? '2';
      
      final Uri uri = Uri.parse(
        '${ApiService.baseUrl}/export_pdf_summary.php'
        '?adminId=$adminId'
        '&roleId=$roleId'
      );
      
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $uri';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening General PDF Summary Report...'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Export failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _downloadIndividualPdf(int assessmentId) async {
    try {
      final Uri uri = Uri.parse('${ApiService.baseUrl}/export_student_pdf.php?assessmentId=$assessmentId&t=${DateTime.now().millisecondsSinceEpoch}');
      
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $uri';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloading Individual Student PDF Report...'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Individual PDF Export failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _downloadCsv() async {
    try {
      final String adminId = _session.counselorId?.toString() ?? '0';
      final String roleId = _session.roleId?.toString() ?? '2';
      
      final visibleIds = _records
          .map((r) => r['assessmentId']?.toString())
          .where((id) => id != null && id!.isNotEmpty)
          .join(',');

      final String queryParams = [
        'exportCsv=1',
        'adminId=$adminId',
        'roleId=$roleId',
        if (visibleIds.isNotEmpty) 'ids=$visibleIds',
        'status=${Uri.encodeComponent(_status)}',
        'strand=${Uri.encodeComponent(_strand)}',
        'gradeLevel=${Uri.encodeComponent(_gradeLevel)}',
        'dominantType=${Uri.encodeComponent(_dominantType)}',
        'rseLevel=${Uri.encodeComponent(_rseLevel)}',
        'cdsesLevel=${Uri.encodeComponent(_cdsesLevel)}',
        'search=${Uri.encodeComponent(_search)}',
        'dateFrom=${Uri.encodeComponent(_dateFrom)}',
        'dateTo=${Uri.encodeComponent(_dateTo)}',
      ].join('&');

      final Uri uri = Uri.parse('${ApiService.baseUrl}/admin_archive.php?$queryParams');
      
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $uri';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Starting Filtered CSV Export...'),
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
    final approvedCount = _records.where((r) => r['status'] == 'approved').length;
    final pendingCount = _records.where((r) => r['status'] == 'pending_review').length;

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
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Download General PDF Report',
            onPressed: _downloadPdfSummary,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _records.isEmpty ? null : _downloadCsv,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecords),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PART 1: Top Search, Filter Drawer, Active Chips, Summary Badges
                    _buildFilterSection(approvedCount, pendingCount),

                    const SizedBox(height: 12),

                    // PART 2: Paginated Student Records (7-8 students per page)
                    _buildRecordsSection(),

                    const SizedBox(height: 20),

                    // PART 3: Interactive Visual Analytics & Charts
                    _buildAnalyticsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // ==========================================
  // PART 1: Top Filter, Search & Summary Bar
  // ==========================================
  Widget _buildFilterSection(int approvedCount, int pendingCount) {
    return Container(
      color: AppTheme.backgroundWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Single line: Search Input + Filter Toggle Button + Reset
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or student ID...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _currentPage = 0;
                              });
                              _loadRecords();
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _search = v;
                      _currentPage = 0;
                    });
                    _debounceTimer?.cancel();
                    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
                      _loadRecords();
                    });
                  },
                  onSubmitted: (_) {
                    _debounceTimer?.cancel();
                    setState(() => _currentPage = 0);
                    _loadRecords();
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Collapsible Filter Button with Badge
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _isFilterExpanded = !_isFilterExpanded);
                },
                icon: Icon(
                  _isFilterExpanded ? Icons.filter_list_off : Icons.tune_rounded,
                  size: 18,
                ),
                label: Row(
                  children: [
                    Text(_isFilterExpanded ? 'Hide Filters' : 'Filters'),
                    if (_activeFilterCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryYellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_activeFilterCount',
                          style: const TextStyle(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFilterExpanded || _activeFilterCount > 0
                      ? AppTheme.primaryPurple
                      : Colors.purple.shade50,
                  foregroundColor: _isFilterExpanded || _activeFilterCount > 0
                      ? Colors.white
                      : AppTheme.primaryPurple,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_activeFilterCount > 0 || _search.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFFE53E3E)),
                  tooltip: 'Reset All Filters',
                  onPressed: _resetFilters,
                ),
              ],
            ],
          ),

          // Active Filter Badges (Horizontal Chips)
          if (_activeFilterCount > 0) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Active:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  if (_status != 'all')
                    _activeFilterChip('Status: ${_statusOptions[_status]}', () {
                      setState(() {
                        _status = 'all';
                        _currentPage = 0;
                      });
                      _loadRecords();
                    }),
                  if (_gradeLevel != 'all')
                    _activeFilterChip('Grade: $_gradeLevel', () {
                      setState(() {
                        _gradeLevel = 'all';
                        _currentPage = 0;
                      });
                      _loadRecords();
                    }),
                  if (_strand != 'all')
                    _activeFilterChip('Strand: $_strand', () {
                      setState(() {
                        _strand = 'all';
                        _currentPage = 0;
                      });
                      _loadRecords();
                    }),
                  if (_dominantType != 'all')
                    _activeFilterChip('RIASEC: $_dominantType', () {
                      setState(() {
                        _dominantType = 'all';
                        _currentPage = 0;
                      });
                      _loadRecords();
                    }),
                  if (_rseLevel != 'all')
                    _activeFilterChip('Self-Esteem: ${_rseOptions[_rseLevel]}', () {
                      setState(() {
                        _rseLevel = 'all';
                        _currentPage = 0;
                      });
                      _loadRecords();
                    }),
                  if (_cdsesLevel != 'all')
                    _activeFilterChip('Self-Efficacy: ${_cdsesOptions[_cdsesLevel]}', () {
                      setState(() {
                        _cdsesLevel = 'all';
                        _currentPage = 0;
                      });
                      _loadRecords();
                    }),
                  if (_dateFrom.isNotEmpty || _dateTo.isNotEmpty)
                    _activeFilterChip('Date: ${_dateFrom.isEmpty ? '...' : _dateFrom} to ${_dateTo.isEmpty ? '...' : _dateTo}', () {
                      setState(() {
                        _dateFrom = '';
                        _dateTo = '';
                        _currentPage = 0;
                      });
                      _loadRecords();
                    }),
                ],
              ),
            ),
          ],

          // Expanded Dropdowns Panel
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isFilterExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _filterDropdown('Approval Status', _statusOptions, _status,
                          (v) => setState(() {
                            _status = v!;
                            _currentPage = 0;
                          }))),
                      const SizedBox(width: 8),
                      Expanded(child: _filterDropdown('Grade Level', _gradeLevelOptions, _gradeLevel,
                          (v) => setState(() {
                            _gradeLevel = v!;
                            _currentPage = 0;
                          }))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _filterDropdown('Strand', _strandOptions, _strand,
                          (v) => setState(() {
                            _strand = v!;
                            _currentPage = 0;
                          }))),
                      const SizedBox(width: 8),
                      Expanded(child: _filterDropdown('Dominant Type', _typeOptions, _dominantType,
                          (v) => setState(() {
                            _dominantType = v!;
                            _currentPage = 0;
                          }))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _filterDropdown('Self-Esteem (RSE)', _rseOptions, _rseLevel,
                          (v) => setState(() {
                            _rseLevel = v!;
                            _currentPage = 0;
                          }))),
                      const SizedBox(width: 8),
                      Expanded(child: _filterDropdown('Self-Efficacy (CDSES)', _cdsesOptions, _cdsesLevel,
                          (v) => setState(() {
                            _cdsesLevel = v!;
                            _currentPage = 0;
                          }))),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                            if (d != null) {
                              setState(() {
                                _dateFrom = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                _currentPage = 0;
                              });
                            }
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
                            if (d != null) {
                              setState(() {
                                _dateTo = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _loadRecords();
                            setState(() {
                              _isFilterExpanded = false;
                              _currentPage = 0;
                            });
                          },
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Apply & Close Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Summary Metrics Banner
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _metricBadge(Icons.folder_shared_rounded, '${_records.length} Total Records', Colors.purple.shade700),
                const SizedBox(width: 10),
                _metricBadge(Icons.hourglass_top_rounded, '$pendingCount Pending', AppTheme.warning),
                const SizedBox(width: 10),
                _metricBadge(Icons.check_circle_rounded, '$approvedCount Approved', AppTheme.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PART 2: Paginated Student Records (7-8 per page)
  // ==========================================
  Widget _buildRecordsSection() {
    if (_records.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 14),
              Text(
                'No student records found matching the active criteria',
                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                label: const Text('Reset All Filters'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryPurple),
              ),
            ],
          ),
        ),
      );
    }

    final startIdx = (_currentPage * _pageSize) + 1;
    final endIdx = math.min((_currentPage + 1) * _pageSize, _records.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header with pagination counter
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.people_alt_rounded, size: 18, color: AppTheme.primaryPurple),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Student Records Directory',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.purple.shade100),
                      ),
                      child: Text(
                        'Showing $startIdx–$endIdx of ${_records.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Paged Student Cards (7 to 8 items)
          ..._pagedRecords.map((r) => _buildStudentCard(r)).toList(),

          // Bottom Pagination Bar
          _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _scrollController.animateTo(
                      220,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text('Previous'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
              side: BorderSide(color: Colors.purple.shade200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          // Page number buttons
          ...List.generate(_totalPages, (i) {
            if (_totalPages > 7) {
              if (i != 0 && i != _totalPages - 1 && (i < _currentPage - 1 || i > _currentPage + 1)) {
                if (i == _currentPage - 2 || i == _currentPage + 2) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  );
                }
                return const SizedBox.shrink();
              }
            }
            final isSelected = i == _currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  setState(() => _currentPage = i);
                  _scrollController.animateTo(
                    220,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryPurple : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryPurple : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _currentPage < _totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _scrollController.animateTo(
                      220,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Next'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPurple,
              side: BorderSide(color: Colors.purple.shade200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> r) {
    final scores = (r['scores'] as Map<String, dynamic>?) ?? {};
    final statusColor = _statusColor(r['status']);
    final rse = r['rse'] as Map<String, dynamic>?;
    final cdses = r['cdses'] as Map<String, dynamic>?;
    final clusterRecs = List<Map<String, dynamic>>.from(r['clusterRecommendations'] ?? []);
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
          r['studentName'] ?? 'Unknown Student',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'ID: ${r['studentId']} • ${r['gradeLevel']} • ${r['strand']}',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r['status'] == 'approved') ...[
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.primaryPurple, size: 20),
                tooltip: 'Download Student PDF Report',
                onPressed: () => _downloadIndividualPdf(r['assessmentId']),
              ),
              const SizedBox(width: 4),
            ],
            Chip(
              label: Text(
                _statusLabel(r['status']),
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              backgroundColor: statusColor.withOpacity(0.1),
              side: BorderSide(color: statusColor.withOpacity(0.3)),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                // Student details chips + Prominent PDF Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _infoChip(Icons.person_outline, r['gender'] ?? '-'),
                          _infoChip(Icons.cake_outlined, '${r['age'] ?? '-'} yrs old'),
                          _infoChip(Icons.calendar_month_outlined, r['submittedAt'] ?? '-'),
                        ],
                      ),
                    ),
                    if (r['status'] == 'approved') ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Download Individual PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _downloadIndividualPdf(r['assessmentId']),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // RIASEC profile progress bars
                Text(
                  'RIASEC Profile Scores',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                ),
                const SizedBox(height: 10),
                ...['R', 'I', 'A', 'S', 'E', 'C'].map((t) {
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

                // Career Decision Self-Efficacy (CDSES-SF)
                if (cdses != null) ...[
                  const Divider(height: 24),
                  Text(
                    'Career Decision Self-Efficacy Profile (CDSES-SF)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Self-Efficacy Level: ${cdses['selfEfficacyLevel']}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cdses['selfEfficacyLevel'].toString().toLowerCase().contains('high')
                          ? AppTheme.success
                          : cdses['selfEfficacyLevel'].toString().toLowerCase().contains('mod')
                              ? AppTheme.warning
                              : const Color(0xFFE53E3E),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Total Score: ${cdses['totalScore']?.toInt() ?? 0} / 125\n'
                    '• SA: ${cdses['saScore']} | OI: ${cdses['oiScore']} | '
                    'GS: ${cdses['gsScore']} | PL: ${cdses['plScore']} | '
                    'PS: ${cdses['psScore']}',
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textSecondary),
                  ),
                ],

                // Recommended Courses & AI Explanations
                if (clusterRecs.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'Top Recommended Course Clusters',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
                  ),
                  const SizedBox(height: 10),
                  ...clusterRecs.map((cluster) {
                    final rank = cluster['rank'] as int? ?? 1;
                    final clusterName = (cluster['cluster_name'] ?? 'General Cluster').toString();
                    final shapExps = List<Map<String, dynamic>>.from(cluster['shap_explanations'] ?? []);
                    final exploreCourses = List<String>.from(cluster['explore_courses'] ?? []);

                    Color rankColor;
                    if (rank == 1) {
                      rankColor = const Color(0xFFD97706);
                    } else if (rank == 2) {
                      rankColor = const Color(0xFF7C3AED);
                    } else {
                      rankColor = const Color(0xFF059669);
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: rankColor.withOpacity(0.4), width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(
                                    rank == 1 ? '🥇 Primary Recommendation' : rank == 2 ? '🥈 Alternative Recommendation' : '🥉 Additional Recommendation',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  backgroundColor: rankColor.withOpacity(0.12),
                                  labelStyle: TextStyle(color: rankColor),
                                ),
                                Text(
                                  '% Predicted Probability',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: rankColor, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              clusterName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 12),
                            if (shapExps.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.auto_awesome, size: 14, color: Colors.purple.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Why this cluster was recommended:',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...shapExps.map((exp) {
                                      final feat = (exp['feature'] ?? '').toString();
                                      final impact = (exp['impact_score'] as num?)?.toDouble() ?? 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                feat,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                              ),
                                            ),
                                            Text(
                                              '+${(impact * 100).toStringAsFixed(0)}% Impact',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (exploreCourses.isNotEmpty) ...[
                              Text(
                                '📌 Recommended Courses under this Cluster:',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                              ),
                              const SizedBox(height: 6),
                              ...exploreCourses.map((crs) {
                                final raw = crs.toString();
                                final isJmcfi = JmcfiBadge.isJmcfiCourse(raw);
                                final cleanName = JmcfiBadge.cleanCourseTitle(raw);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.arrow_right_rounded,
                                        size: 15,
                                        color: AppTheme.primaryPurple,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Tooltip(
                                          message: cleanName,
                                          child: Text(
                                            cleanName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              height: 1.25,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (isJmcfi) ...[
                                        const SizedBox(width: 6),
                                        const JmcfiBadge(),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ] else if (recs.isNotEmpty) ...[
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
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    JmcfiBadge.cleanCourseTitle(rec['CourseName'] ?? ''),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                if (JmcfiBadge.isJmcfiCourse(rec['CourseName'] ?? '')) ...[
                                  const SizedBox(width: 8),
                                  const JmcfiBadge(),
                                ],
                              ],
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

                const SizedBox(height: 16),

                // General Assessment Insights & Summary
                _buildGeneralInsightsBox(r),

                // Counselor notes
                if (r['feedbackNotes'] != null && (r['feedbackNotes'] as String).isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'Counselor\'s Note',
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
  }

  // ==========================================
  // PART 3: Visual Analytics & Distribution
  // ==========================================
  Widget _buildAnalyticsSection() {
    final total = _records.length;

    if (total == 0) {
      return const SizedBox.shrink();
    }

    // 1. Approval Status
    final approvedCount = _records.where((r) => r['status'] == 'approved').length;
    final pendingCount = _records.where((r) => r['status'] == 'pending_review').length;
    final declinedCount = _records.where((r) => r['status'] == 'declined').length;
    final otherStatus = (total - approvedCount - pendingCount - declinedCount).clamp(0, total);
    final approvalPct = ((approvedCount / total) * 100).toStringAsFixed(0);

    final statusSegments = [
      DonutSegment(value: approvedCount.toDouble(), color: AppTheme.success, label: 'Approved'),
      DonutSegment(value: pendingCount.toDouble(), color: AppTheme.warning, label: 'Pending Review'),
      DonutSegment(value: declinedCount.toDouble(), color: AppTheme.error, label: 'Declined'),
      if (otherStatus > 0)
        DonutSegment(value: otherStatus.toDouble(), color: Colors.grey, label: 'Other'),
    ];

    // 2. Career Decision Self-Efficacy (CDSES)
    final highCdses = _records.where((r) => (r['cdses']?['selfEfficacyLevel'] ?? '').toString().toLowerCase().contains('high')).length;
    final modCdses = _records.where((r) => (r['cdses']?['selfEfficacyLevel'] ?? '').toString().toLowerCase().contains('mod')).length;
    final lowCdses = _records.where((r) => (r['cdses']?['selfEfficacyLevel'] ?? '').toString().toLowerCase().contains('low')).length;
    final assessedCdses = highCdses + modCdses + lowCdses;
    final pendingCdses = (total - assessedCdses).clamp(0, total);
    final highCdsesPct = assessedCdses > 0 ? ((highCdses / assessedCdses) * 100).toStringAsFixed(0) : "0";

    final cdsesSegments = [
      DonutSegment(value: highCdses.toDouble(), color: AppTheme.success, label: 'High Readiness'),
      DonutSegment(value: modCdses.toDouble(), color: AppTheme.warning, label: 'Moderate Readiness'),
      DonutSegment(value: lowCdses.toDouble(), color: const Color(0xFFEF4444), label: 'Low Readiness'),
      if (pendingCdses > 0)
        DonutSegment(value: pendingCdses.toDouble(), color: Colors.grey.shade400, label: 'Pending / Unassessed'),
    ];

    final cdsesSubtitle = pendingCdses > 0
        ? 'Career decision readiness ($assessedCdses of $total assessed)'
        : 'Career decision-making readiness level';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 860;
          final donut1 = _buildDonutCard(
            title: 'Assessment Approval Status',
            subtitle: 'Counselor decision breakdown across cohort',
            centerPrimary: '$approvalPct%',
            centerSecondary: 'Approved',
            segments: statusSegments,
          );
          final donut2 = _buildDonutCard(
            title: 'Career Confidence (CDSES)',
            subtitle: cdsesSubtitle,
            centerPrimary: '$highCdsesPct%',
            centerSecondary: 'High Ready',
            segments: cdsesSegments,
          );
          final riasecBars = _buildRiasecBarCard(total);
          final strandBars = _buildStrandBarCard(total);
          final rseCard = _buildRseDiagnosticsCard(total);

          if (isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: donut1),
                    const SizedBox(width: 14),
                    Expanded(child: donut2),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: riasecBars),
                    const SizedBox(width: 14),
                    Expanded(child: strandBars),
                  ],
                ),
                const SizedBox(height: 14),
                rseCard,
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                donut1,
                const SizedBox(height: 12),
                donut2,
                const SizedBox(height: 12),
                riasecBars,
                const SizedBox(height: 12),
                strandBars,
                const SizedBox(height: 12),
                rseCard,
              ],
            );
          }
        },
      ),
    );
  }

  // Visual Helper: Circular Donut Ring Card
  Widget _buildDonutCard({
    required String title,
    required String subtitle,
    required String centerPrimary,
    required String centerSecondary,
    required List<DonutSegment> segments,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Custom Donut Ring
                SizedBox(
                  width: 116,
                  height: 116,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(116, 116),
                        painter: DonutChartPainter(segments: segments, strokeWidth: 14),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            centerPrimary,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                          ),
                          Text(
                            centerSecondary,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                // Legend
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: segments.map((seg) {
                      final total = segments.fold<double>(0, (sum, s) => sum + s.value);
                      final pct = total > 0 ? ((seg.value / total) * 100).toStringAsFixed(1) : "0.0";
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: seg.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                seg.label,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${seg.value.toInt()} ($pct%)',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Visual Helper: RIASEC Horizontal Distribution Bars Card
  Widget _buildRiasecBarCard(int total) {
    const types = ['R', 'I', 'A', 'S', 'E', 'C'];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'RIASEC Dominant Type Breakdown',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Cohort: $total',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Primary personality classification across students',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            ...types.map((type) {
              final count = _records.where((r) => r['primaryType'] == type).length;
              final pct = total > 0 ? (count / total) : 0.0;
              final color = AppTheme.riasecColor(type);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: Text(
                        AppTheme.riasecName(type),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '$count (${(pct * 100).toStringAsFixed(1)}%)',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Visual Helper: Senior High School Strand Representation Card
  Widget _buildStrandBarCard(int total) {
    const strandDefinitions = [
      {'code': 'STEM', 'name': 'STEM', 'color': Color(0xFF2563EB)},
      {'code': 'ABM', 'name': 'ABM', 'color': Color(0xFF059669)},
      {'code': 'HUMSS', 'name': 'HUMSS', 'color': Color(0xFFD97706)},
      {'code': 'GAS', 'name': 'GAS', 'color': Color(0xFF7C3AED)},
      {'code': 'TVL', 'name': 'TVL', 'color': Color(0xFFDC2626)},
      {'code': 'ICT', 'name': 'ICT', 'color': Color(0xFF0891B2)},
      {'code': 'ARTS', 'name': 'Arts & Design', 'color': Color(0xFFDB2777)},
    ];

    int knownCount = 0;
    final strandCounts = <String, int>{};
    for (final def in strandDefinitions) {
      final code = def['code'] as String;
      final count = _records.where((r) {
        final s = (r['strand'] ?? '').toString().toUpperCase();
        return s.startsWith(code) || s.contains(code);
      }).length;
      strandCounts[code] = count;
      knownCount += count;
    }
    final otherCount = (total - knownCount).clamp(0, total);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Academic Strand Representation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Cohort: $total',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Student distribution across SHS academic tracks',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            ...strandDefinitions.map((def) {
              final code = def['code'] as String;
              final name = def['name'] as String;
              final count = strandCounts[code] ?? 0;
              final pct = total > 0 ? (count / total) : 0.0;
              final color = def['color'] as Color;

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '$count (${(pct * 100).toStringAsFixed(1)}%)',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (otherCount > 0) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Other',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: total > 0 ? (otherCount / total) : 0.0,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '$otherCount (${((otherCount / total) * 100).toStringAsFixed(1)}%)',
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Visual Helper: Psychological Wellbeing & Self-Esteem Diagnostics Card
  Widget _buildRseDiagnosticsCard(int total) {
    final lowRseCount = _records.where((r) => (r['rse']?['level'] ?? '').toString().toLowerCase().contains('low')).length;
    final normalRseCount = (total - lowRseCount).clamp(0, total);
    final lowPct = total > 0 ? ((lowRseCount / total) * 100).toStringAsFixed(1) : "0.0";
    final normalPct = total > 0 ? ((normalRseCount / total) * 100).toStringAsFixed(1) : "0.0";

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    size: 20,
                    color: AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rosenberg Self-Esteem (RSE) Diagnostics',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'Psychological health indicator across cohort',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Split Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (normalRseCount > 0)
                      Expanded(
                        flex: normalRseCount,
                        child: Container(color: AppTheme.success),
                      ),
                    if (lowRseCount > 0)
                      Expanded(
                        flex: lowRseCount,
                        child: Container(color: const Color(0xFFEF4444)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Breakdown pills
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            const Text('Normal / High Self-Esteem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text('$normalRseCount ($normalPct%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            const Text('Low Self-Esteem', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                          ],
                        ),
                        Text('$lowRseCount ($lowPct%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
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
            style: TextStyle(
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
      'MBI': 'Career Self-Efficacy',
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

  Widget _activeFilterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
        ),
        deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.primaryPurple),
        onDeleted: onRemove,
        backgroundColor: AppTheme.primaryPurple.withOpacity(0.08),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primaryPurple.withOpacity(0.2)),
        ),
      ),
    );
  }

  Widget _metricBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // GENERAL ASSESSMENT INSIGHTS & SUMMARY CONTAINER
  // -------------------------------------------------------------
  Widget _buildGeneralInsightsBox(Map<String, dynamic> a) {
    final primary = (a['primaryType'] ?? '').toString().toUpperCase();
    final secondary = (a['secondaryType'] ?? '').toString().toUpperCase();
    final tertiary = (a['tertiaryType'] ?? '').toString().toUpperCase();
    final scores = (a['scores'] as Map<String, dynamic>?) ?? {};
    final rse = a['rse'] as Map<String, dynamic>?;
    final cdses = a['cdses'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Container Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_rounded, color: AppTheme.primaryPurple, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'General Assessment Insights & Summary',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Holistic synthesis across RIASEC Interests, Self-Esteem (RSE), and Decision Self-Efficacy (CDSES)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 1. RIASEC Interest Profile Insights
            _buildRiasecInsightSection(primary, secondary, tertiary, scores),

            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 2. Self-Esteem Profile (RSE) Insights
            _buildRseInsightSection(rse),

            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 3. Career Decision Self-Efficacy (CDSES) Insights
            _buildCdsesInsightSection(cdses),
          ],
        ),
      ),
    );
  }

  // 1. RIASEC Section
  Widget _buildRiasecInsightSection(
    String primary,
    String secondary,
    String tertiary,
    Map<String, dynamic> scores,
  ) {
    final codeList = [primary, secondary, tertiary].where((t) => t.isNotEmpty).toList();
    final hollandCode = codeList.join();

    final pName = AppTheme.riasecName(primary);
    final sName = secondary.isNotEmpty ? AppTheme.riasecName(secondary) : '';
    final tName = tertiary.isNotEmpty ? AppTheme.riasecName(tertiary) : '';

    final pScoreVal = scores[primary] != null ? (double.tryParse(scores[primary].toString()) ?? 0.0) : null;
    final sScoreVal = secondary.isNotEmpty && scores[secondary] != null ? (double.tryParse(scores[secondary].toString()) ?? 0.0) : null;
    final tScoreVal = tertiary.isNotEmpty && scores[tertiary] != null ? (double.tryParse(scores[tertiary].toString()) ?? 0.0) : null;

    final pScoreStr = pScoreVal != null ? '${pScoreVal.toStringAsFixed(1)}%' : '';
    final sScoreStr = sScoreVal != null ? '${sScoreVal.toStringAsFixed(1)}%' : '';
    final tScoreStr = tScoreVal != null ? '${tScoreVal.toStringAsFixed(1)}%' : '';

    final traitMap = {
      'R': 'hands-on, practical execution and concrete problem-solving',
      'I': 'intellectual curiosity, scientific research, and deep analytical inquiry',
      'A': 'creative expression, intuitive exploration, and original conceptualization',
      'S': 'empathetic interpersonal communication, service, and collaborative teamwork',
      'E': 'persuasion, organizational leadership, initiative, and goal achievement',
      'C': 'structured processes, data precision, systematic organization, and high attention to detail',
    };

    final pTrait = traitMap[primary] ?? 'vocational interest';
    final sTrait = traitMap[secondary] ?? '';

    String narrative = '';
    if (primary.isNotEmpty && secondary.isNotEmpty) {
      narrative =
          'The student demonstrates a dominant preference for $pTrait ($pName${pScoreStr.isNotEmpty ? " $pScoreStr" : ""}), complemented by $sTrait ($sName${sScoreStr.isNotEmpty ? " $sScoreStr" : ""}). They thrive in learning environments that combine structured procedures with meaningful analytical inquiry and cooperative goals.';
    } else if (primary.isNotEmpty) {
      narrative =
          'The student shows an orientation centered on $pTrait ($pName${pScoreStr.isNotEmpty ? " $pScoreStr" : ""}), suggesting highest motivation in tasks requiring focused application of this domain.';
    } else {
      narrative = 'RIASEC interest profile is currently being finalized.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 16, color: AppTheme.primaryPurple),
            const SizedBox(width: 6),
            const Text(
              '1. RIASEC Interest Profile Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
              ),
              child: Text(
                'Dominant Code: $hollandCode ($pName • $sName • $tName)',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
              ),
            ),
            if (pScoreStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.riasecColor(primary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$primary: $pScoreStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.riasecColor(primary)),
                ),
              ),
            if (sScoreStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.riasecColor(secondary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$secondary: $sScoreStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.riasecColor(secondary)),
                ),
              ),
            if (tScoreStr.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.riasecColor(tertiary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$tertiary: $tScoreStr',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.riasecColor(tertiary)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          narrative,
          style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF334155)),
        ),
      ],
    );
  }

  // 2. RSE Section
  Widget _buildRseInsightSection(Map<String, dynamic>? rse) {
    if (rse == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 16, color: Colors.pink.shade400),
              const SizedBox(width: 6),
              const Text(
                '2. Self-Esteem Profile (RSE) Insights',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Self-Esteem assessment data is not yet recorded for this student.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    final score = (rse['score'] as num?)?.toInt() ?? 0;
    final level = (rse['level'] ?? '').toString();
    final isLow = level.toLowerCase().contains('low') || (score > 0 && score < 15);
    final isHigh = level.toLowerCase().contains('high') || score >= 25;

    final badgeColor = isLow
        ? const Color(0xFFE53E3E)
        : isHigh
            ? AppTheme.success
            : const Color(0xFF10B981);

    String rseNarrative;
    if (isLow) {
      rseNarrative =
          'The student exhibits low self-esteem ($score / 30), which can indicate susceptibility to academic anxiety, impostor feelings, or hesitance in challenging programs. The counselor is advised to offer positive affirmation and confidence-building support alongside academic guidance.';
    } else if (isHigh) {
      rseNarrative =
          'The student reflects high self-esteem ($score / 30), representing strong self-assurance, personal optimism, and emotional resilience. They are well-equipped to manage academic setbacks and actively advocate for their goals.';
    } else {
      rseNarrative =
          'The student displays a healthy, balanced self-esteem profile ($score / 30 - Normal). This indicates sound emotional stability and realistic self-regard, providing a reliable emotional foundation for post-secondary transitions.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite_rounded, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            const Text(
              '2. Self-Esteem Profile (RSE) Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLow ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                size: 14,
                color: badgeColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Score: $score / 30 ($level)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rseNarrative,
          style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF334155)),
        ),
      ],
    );
  }

  // 3. CDSES Section
  Widget _buildCdsesInsightSection(Map<String, dynamic>? cdses) {
    if (cdses == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_rounded, size: 16, color: AppTheme.primaryPurple),
              const SizedBox(width: 6),
              const Text(
                '3. Career Decision Self-Efficacy (CDSES) Insights',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Career Decision Self-Efficacy assessment data is not yet recorded for this student.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    final totalScore = (cdses['totalScore'] as num?)?.toDouble() ?? 0.0;
    final level = (cdses['selfEfficacyLevel'] ?? '').toString();
    final sa = (cdses['saScore'] as num?)?.toDouble() ?? 0.0;
    final oi = (cdses['oiScore'] as num?)?.toDouble() ?? 0.0;
    final gs = (cdses['gsScore'] as num?)?.toDouble() ?? 0.0;
    final pl = (cdses['plScore'] as num?)?.toDouble() ?? 0.0;
    final ps = (cdses['psScore'] as num?)?.toDouble() ?? 0.0;

    final isHigh = level.toLowerCase().contains('high') || totalScore >= 85;
    final isMod = level.toLowerCase().contains('mod') || (totalScore >= 60 && totalScore < 85);

    final badgeColor = isHigh
        ? AppTheme.success
        : isMod
            ? AppTheme.warning
            : const Color(0xFFE53E3E);

    final subscales = [
      {'name': 'Self-Appraisal', 'code': 'SA', 'score': sa},
      {'name': 'Occupational Information', 'code': 'OI', 'score': oi},
      {'name': 'Goal Selection', 'code': 'GS', 'score': gs},
      {'name': 'Planning', 'code': 'PL', 'score': pl},
      {'name': 'Problem Solving', 'code': 'PS', 'score': ps},
    ];
    subscales.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final highest = subscales.first;
    final lowest = subscales.last;

    String cdsesNarrative;
    if (isHigh) {
      cdsesNarrative =
          'The student demonstrates high career decision self-efficacy (${totalScore.toInt()} / 125), indicating strong confidence in making independent vocational decisions. They show exceptional strength in ${highest['name']} (${(highest['score'] as double).toStringAsFixed(2)}/5.0), demonstrating strong self-direction and ability to resolve educational dilemmas.';
    } else if (isMod) {
      cdsesNarrative =
          'The student displays moderate career decision self-efficacy (${totalScore.toInt()} / 125). While capable, lower relative confidence in ${lowest['name']} (${(lowest['score'] as double).toStringAsFixed(2)}/5.0) suggests they may feel hesitant about finalizing choices or gathering career requirements, presenting an optimal entry point for guidance.';
    } else {
      cdsesNarrative =
          'The student reflects low career decision self-efficacy (${totalScore.toInt()} / 125), signaling noticeable uncertainty or anxiety about post-secondary options. Priority counseling focused on ${lowest['name']} (${(lowest['score'] as double).toStringAsFixed(2)}/5.0) is recommended to build clarity and confidence.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.explore_rounded, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            const Text(
              '3. Career Decision Self-Efficacy (CDSES) Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: badgeColor.withOpacity(0.3)),
              ),
              child: Text(
                'Total: ${totalScore.toInt()} / 125 ($level)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: badgeColor),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Highest: ${highest['code']} (${(highest['score'] as double).toStringAsFixed(2)})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                'Lowest: ${lowest['code']} (${(lowest['score'] as double).toStringAsFixed(2)})',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          cdsesNarrative,
          style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF334155)),
        ),
      ],
    );
  }
}

class DonutSegment {
  final double value;
  final Color color;
  final String label;

  const DonutSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}

class DonutChartPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double strokeWidth;

  DonutChartPainter({required this.segments, this.strokeWidth = 14});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    // Background track ring
    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final total = segments.fold<double>(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final activeCount = segments.where((s) => s.value > 0).length;
    final sweepGap = activeCount > 1 ? 0.05 : 0.0;
    double startAngle = -math.pi / 2; // Start from top (12 o'clock)

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweepAngle = (seg.value / total) * 2 * math.pi;
      final effectiveSweep = (sweepAngle - sweepGap).clamp(0.02, sweepAngle);

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (sweepGap / 2),
        effectiveSweep,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.strokeWidth != strokeWidth;
  }
}