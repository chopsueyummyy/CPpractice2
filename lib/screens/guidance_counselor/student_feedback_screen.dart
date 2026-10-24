import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/counselor_sidebar.dart';
import '../../widgets/jmcfi_badge.dart';

class StudentFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;

  const StudentFeedbackScreen({super.key, this.extraData});

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  bool _isDark = false;
  final _session = SessionManager();
  bool get isPsych => _session.isPsychometrician;
  String get prefix => isPsych ? '/psychometrician' : '/guidance-counselor';
  final _notesController = TextEditingController();
  final _riasecInsightController = TextEditingController();
  final _rseInsightController = TextEditingController();
  final _cdsesInsightController = TextEditingController();

  String _defaultRiasecInsight = '';
  String _defaultRseInsight = '';
  String _defaultCdsesInsight = '';

  List<Map<String, dynamic>> _pendingList = [];
  List<Map<String, dynamic>> _catalogCourses = [];
  bool _isLoadingPending = true;
  Map<String, dynamic>? _selectedStudent;
  List<Map<String, dynamic>> _editableClusterRecs = [];

  String _action = 'approved';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (_session.isPsychometrician) {
      _action = 'endorse';
    }
    _fetchPendingList();
    _fetchCatalog();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _riasecInsightController.dispose();
    _rseInsightController.dispose();
    _cdsesInsightController.dispose();
    super.dispose();
  }

  Future<void> _fetchCatalog() async {
    try {
      final res = await ApiService.getCourseCatalog();
      if (res['status'] == 'success' && mounted) {
        final list = List<Map<String, dynamic>>.from(res['courses'] ?? []);
        setState(() => _catalogCourses = list);
      }
    } catch (_) {}
  }

  Future<void> _fetchPendingList() async {
    if (!mounted) return;
    setState(() => _isLoadingPending = true);

    try {
      final isPsych = _session.isPsychometrician;
      final res = await ApiService.getPendingApprovals(role: isPsych ? 'psychometrician' : 'guidance_counselor');
      if (res['status'] == 'success' && mounted) {
        final rawList = res['pending'] as List? ?? [];
        final list = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

        setState(() {
          _pendingList = list;
          _isLoadingPending = false;
        });

        if (widget.extraData != null) {
          _action = widget.extraData!['action'] ?? (isPsych ? 'endorse' : 'approved');
          final reason = widget.extraData!['reason'] as String?;
          if (reason != null && reason.isNotEmpty) {
            _notesController.text = reason;
          }

          final passedId = widget.extraData!['assessmentId']?.toString();
          final match = list.firstWhere(
            (item) => item['assessmentId']?.toString() == passedId,
            orElse: () => widget.extraData!,
          );
          if (widget.extraData!['psychometricianNote'] != null && match['psychometricianNote'] == null) {
            match['psychometricianNote'] = widget.extraData!['psychometricianNote'];
          }
          if (widget.extraData!['generalInsights'] != null && match['generalInsights'] == null) {
            match['generalInsights'] = widget.extraData!['generalInsights'];
          }
          _selectStudent(match);
        } else if (list.isNotEmpty) {
          _selectStudent(list.first);
        }
      } else {
        if (mounted) setState(() => _isLoadingPending = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPending = false);
    }
  }

  String _generateDefaultRiasecInsight(Map<String, dynamic> st) {
    final primary = (st['primaryType'] ?? '').toString().toUpperCase();
    final secondary = (st['secondaryType'] ?? '').toString().toUpperCase();
    final scores = (st['scores'] as Map<String, dynamic>?) ?? {};

    final pName = AppTheme.riasecName(primary);
    final sName = secondary.isNotEmpty ? AppTheme.riasecName(secondary) : '';

    final pScoreVal = scores[primary] != null ? (double.tryParse(scores[primary].toString()) ?? 0.0) : null;
    final sScoreVal = secondary.isNotEmpty && scores[secondary] != null ? (double.tryParse(scores[secondary].toString()) ?? 0.0) : null;

    final pScoreStr = pScoreVal != null ? '${pScoreVal.toStringAsFixed(1)}%' : '';
    final sScoreStr = sScoreVal != null ? '${sScoreVal.toStringAsFixed(1)}%' : '';

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

    if (primary.isNotEmpty && secondary.isNotEmpty) {
      return 'The student demonstrates a dominant preference for $pTrait ($pName${pScoreStr.isNotEmpty ? " $pScoreStr" : ""}), complemented by $sTrait ($sName${sScoreStr.isNotEmpty ? " $sScoreStr" : ""}). They thrive in learning environments that combine structured procedures with meaningful analytical inquiry and cooperative goals.';
    } else if (primary.isNotEmpty) {
      return 'The student shows an orientation centered on $pTrait ($pName${pScoreStr.isNotEmpty ? " $pScoreStr" : ""}), suggesting highest motivation in tasks requiring focused application of this domain.';
    }
    return 'RIASEC interest profile is currently being finalized.';
  }

  String _generateDefaultRseInsight(Map<String, dynamic>? rse) {
    if (rse == null) {
      return 'Self-Esteem assessment data is not yet recorded for this student.';
    }
    final score = (rse['score'] as num?)?.toInt() ?? 0;
    final level = (rse['level'] ?? '').toString();
    final isLow = level.toLowerCase().contains('low') || (score > 0 && score < 15);
    final isHigh = level.toLowerCase().contains('high') || score >= 25;

    if (isLow) {
      return 'The student exhibits low self-esteem ($score / 30), which can indicate susceptibility to academic anxiety, impostor feelings, or hesitance in challenging programs. The counselor/facilitator is advised to offer positive affirmation and confidence-building support alongside academic guidance.';
    } else if (isHigh) {
      return 'The student reflects high self-esteem ($score / 30), representing strong self-assurance, personal optimism, and emotional resilience. They are well-equipped to manage academic setbacks and actively advocate for their goals.';
    } else {
      return 'The student displays a healthy, balanced self-esteem profile ($score / 30 - Normal). This indicates sound emotional stability and realistic self-regard, providing a reliable emotional foundation for post-secondary transitions.';
    }
  }

  String _generateDefaultCdsesInsight(Map<String, dynamic>? cdses) {
    if (cdses == null) {
      return 'Career Decision Self-Efficacy assessment data is not yet recorded for this student.';
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

    if (isHigh) {
      return 'The student demonstrates high career decision self-efficacy (${totalScore.toInt()} / 125), indicating strong confidence in making independent vocational decisions. They show exceptional strength in ${highest['name']} (${(highest['score'] as double).toStringAsFixed(2)}/5.0), demonstrating strong self-direction and ability to resolve educational dilemmas.';
    } else if (isMod) {
      return 'The student displays moderate career decision self-efficacy (${totalScore.toInt()} / 125). While capable, lower relative confidence in ${lowest['name']} (${(lowest['score'] as double).toStringAsFixed(2)}/5.0) suggests they may feel hesitant about finalizing choices or gathering career requirements, presenting an optimal entry point for guidance.';
    } else {
      return 'The student reflects low career decision self-efficacy (${totalScore.toInt()} / 125), signaling noticeable uncertainty or anxiety about post-secondary options. Priority counseling focused on ${lowest['name']} (${(lowest['score'] as double).toStringAsFixed(2)}/5.0) is recommended to build clarity and confidence.';
    }
  }

  void _selectStudent(Map<String, dynamic> studentData) {
    final rawRecs = studentData['clusterRecommendations'] as List? ?? [];
    final clonedRecs = rawRecs.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Default to top 3 courses per cluster for evaluation
    for (var rec in clonedRecs) {
      if (rec['explore_courses'] is List) {
        final courses = List<String>.from(rec['explore_courses']);
        if (courses.length > 3) {
          rec['explore_courses'] = courses.take(3).toList();
        }
      }
    }

    _defaultRiasecInsight = _generateDefaultRiasecInsight(studentData);
    _defaultRseInsight = _generateDefaultRseInsight(studentData['rse'] is Map ? Map<String, dynamic>.from(studentData['rse']) : null);
    _defaultCdsesInsight = _generateDefaultCdsesInsight(studentData['cdses'] is Map ? Map<String, dynamic>.from(studentData['cdses']) : null);

    final existingInsights = studentData['generalInsights'] is Map ? Map<String, dynamic>.from(studentData['generalInsights']) : null;
    _riasecInsightController.text = (existingInsights?['riasec'] ?? _defaultRiasecInsight).toString();
    _rseInsightController.text = (existingInsights?['rse'] ?? _defaultRseInsight).toString();
    _cdsesInsightController.text = (existingInsights?['cdses'] ?? _defaultCdsesInsight).toString();

    setState(() {
      _selectedStudent = studentData;
      _editableClusterRecs = clonedRecs;
    });
  }

  String _formatDuration(dynamic rawSeconds) {
    final seconds = int.tryParse(rawSeconds.toString()) ?? 0;
    if (seconds <= 0) return 'N/A';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m ${s}s';
    } else if (m > 0) {
      return '${m}m ${s}s';
    } else {
      return '${s}s';
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _submit() async {
    if (_selectedStudent == null || _selectedStudent!['assessmentId'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a student from the list first.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
      return;
    }

    final rawId = _selectedStudent!['assessmentId'];
    final assessmentId = int.tryParse(rawId.toString()) ?? 0;
    final studentName = _selectedStudent!['studentName'] ?? 'the student';

    final isPsych = _session.isPsychometrician;
    final isApproveOrEndorse = _action == 'approved' || _action == 'endorse';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPsych
              ? (isApproveOrEndorse ? 'Endorse Assessment to Counselor/Facilitator' : 'Flag / Retake Assessment')
              : (_action == 'approved' ? 'Approve & Release Results' : 'Request Assessment Retake'),
        ),
        content: Text(
          isPsych
              ? (isApproveOrEndorse
                  ? 'This will forward $studentName\'s assessment to the Guidance Counselor/Facilitator with your notes and course calibrations.'
                  : 'This will reject $studentName\'s assessment and request a retake.')
              : (_action == 'approved'
                  ? 'This will approve $studentName\'s assessment, send them an automated notification email, and release their official results to their dashboard and downloadable report.'
                  : 'This will decline $studentName\'s assessment and ask them to retake it. Your counseling note will be sent to them.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: !isApproveOrEndorse
                ? ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53E3E))
                : ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: Text(
              isPsych
                  ? (isApproveOrEndorse ? 'Endorse' : 'Flag Retake')
                  : (_action == 'approved' ? 'Approve & Release' : 'Request Retake'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final submitAction = _action == 'rejected'
          ? 'declined'
          : (isPsych ? 'endorse' : _action);

      Map<String, dynamic>? generalInsightsPayload;
      if (isPsych) {
        generalInsightsPayload = {
          'riasec': _riasecInsightController.text.trim(),
          'rse': _rseInsightController.text.trim(),
          'cdses': _cdsesInsightController.text.trim(),
        };
      }

      final data = await ApiService.submitFeedback(
        assessmentId: assessmentId,
        action: submitAction,
        counselorId: _session.counselorId ?? 1,
        feedbackNotes: _notesController.text.trim(),
        curatedRecommendations: _editableClusterRecs,
        reviewerRole: isPsych ? 'psychometrician' : 'guidance_counselor',
        generalInsights: generalInsightsPayload,
      );

      if (!mounted) return;

      if (data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPsych
                  ? (isApproveOrEndorse
                      ? 'Assessment successfully endorsed to Guidance Counselor/Facilitator!'
                      : 'Assessment flagged for retake.')
                  : (_action == 'approved'
                      ? 'Assessment approved! Notification email sent and results released to student.'
                      : 'Assessment declined. Student notified to retake.'),
            ),
            backgroundColor: isApproveOrEndorse ? AppTheme.success : const Color(0xFFE53E3E),
          ),
        );

        _notesController.clear();
        _riasecInsightController.clear();
        _rseInsightController.clear();
        _cdsesInsightController.clear();
        _selectedStudent = null;
        _editableClusterRecs = [];
        await _fetchPendingList();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Something went wrong.'),
            backgroundColor: const Color(0xFFE53E3E),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit. Check your connection.'),
          backgroundColor: Color(0xFFE53E3E),
        ),
      );
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSwapDialog({
    required int clusterIndex,
    required int courseIndex,
    required String currentCourse,
    required String clusterName,
  }) {
    if (_catalogCourses.isEmpty) {
      _fetchCatalog();
    }

    String searchQuery = '';
    Map<String, dynamic>? selectedCatalogCourse;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCatalog = _catalogCourses.where((c) {
              final cName = (c['courseName'] ?? '').toString().toLowerCase();
              final cCode = (c['courseCode'] ?? '').toString().toLowerCase();
              final cClust = (c['clusterName'] ?? '').toString().toLowerCase();
              final isMatchingCluster = cClust == clusterName.toLowerCase();
              if (!isMatchingCluster) return false;

              final q = searchQuery.toLowerCase();
              return q.isEmpty || cName.contains(q) || cCode.contains(q);
            }).toList();

            filteredCatalog.sort((a, b) =>
                (a['courseName'] ?? '').toString().compareTo((b['courseName'] ?? '').toString()));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: AppTheme.primaryPurple),
                  const SizedBox(width: 8),
                  Text(
                    courseIndex < 0 ? 'Add Course to Cluster' : 'Swap Course Recommendation',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cluster: $clusterName',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                    ),
                    if (currentCourse.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Currently Selected: $currentCourse',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search course in $clusterName...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (val) {
                        setDialogState(() => searchQuery = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: filteredCatalog.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: _catalogCourses.isEmpty
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(),
                                          const SizedBox(height: 12),
                                          const Text('Loading course catalog...', style: TextStyle(fontSize: 12)),
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () async {
                                              await _fetchCatalog();
                                              setDialogState(() {});
                                            },
                                            child: const Text('Retry Fetch Catalog'),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'No matching courses found under "$clusterName".',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredCatalog.length,
                              itemBuilder: (context, i) {
                                final item = filteredCatalog[i];
                                final name = (item['courseName'] ?? '').toString();
                                final code = (item['courseCode'] ?? '').toString();
                                final isJmcfi = JmcfiBadge.isJmcfiCourse(name);
                                final cleanName = JmcfiBadge.cleanCourseTitle(name);
                                final isSelected = selectedCatalogCourse == item || name == currentCourse || cleanName == JmcfiBadge.cleanCourseTitle(currentCourse);

                                final displayText = code.isNotEmpty ? '$code - $cleanName' : cleanName;

                                return ListTile(
                                  dense: true,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  tileColor: isSelected ? AppTheme.primaryPurple.withOpacity(0.08) : null,
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(displayText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      if (isJmcfi) ...[
                                        const SizedBox(width: 6),
                                        const JmcfiBadge(),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text(clusterName, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: AppTheme.primaryPurple, size: 18)
                                      : null,
                                  onTap: () {
                                    setDialogState(() => selectedCatalogCourse = item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                  onPressed: selectedCatalogCourse == null
                      ? null
                      : () {
                          final selectedName = (selectedCatalogCourse!['courseName'] ?? '').toString();
                          setState(() {
                            if (clusterIndex >= 0 && clusterIndex < _editableClusterRecs.length) {
                              final currentList = List<String>.from(_editableClusterRecs[clusterIndex]['explore_courses'] ?? []);
                              if (courseIndex >= 0 && courseIndex < currentList.length) {
                                currentList[courseIndex] = selectedName;
                              } else {
                                currentList.add(selectedName);
                              }
                              _editableClusterRecs[clusterIndex]['explore_courses'] = currentList;
                            }
                          });
                          Navigator.pop(ctx);
                        },
                  child: Text(courseIndex < 0 ? 'Add to Cluster' : 'Confirm Swap'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIdStr = _selectedStudent?['assessmentId']?.toString();

    final bool isValueInItems = _pendingList.any((st) => st['assessmentId']?.toString() == selectedIdStr);
    final String? dropdownValue = isValueInItems ? selectedIdStr : (_pendingList.isNotEmpty ? _pendingList.first['assessmentId']?.toString() : null);
    final int currentIndex = _pendingList.indexWhere((st) => st['assessmentId']?.toString() == dropdownValue);
    final isPsych = _session.isPsychometrician;
    final prefix = isPsych ? '/psychometrician' : '/guidance-counselor';
    final isApproveOrEndorse = _action == 'approved' || _action == 'endorse';

    return Scaffold(
      drawer: CounselorSidebar(currentRoute: '$prefix/ai-feedback'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isPsych ? 'Psychometric Evaluation & Review' : 'Student Result'),
            Text(
              isPsych
                  ? (isApproveOrEndorse
                      ? 'Evaluate psychometric profile, refine course recommendations & prepare counselor/facilitator briefing'
                      : 'Flagging assessment — student will retake')
                  : (_action == 'approved'
                      ? 'Review psychometrician briefing, provide guidance, and release results'
                      : 'Declining assessment — student will retake'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Pending List',
            onPressed: _fetchPendingList,
          ),
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Dashboard',
            onPressed: () => context.go('$prefix/dashboard'),
          ),
        ],
      ),
      bottomNavigationBar: _selectedStudent == null || _pendingList.isEmpty
          ? null
          : _buildStickyBottomBar(isPsych, isApproveOrEndorse),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. STUDENT SELECTION DROPDOWN BAR ───────────────────────────
            Card(
              elevation: 2,
              color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.transparent),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.how_to_reg_rounded, color: AppTheme.primaryPurple),
                        const SizedBox(width: 8),
                        Text(
                          'Select Student to Review',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple,
                              ),
                        ),
                        const Spacer(),
                        if (_pendingList.isNotEmpty) ...[
                          // Quick Queue Switcher
                          Container(
                            decoration: BoxDecoration(
                              color: _isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left, size: 20),
                                  tooltip: 'Previous Student',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: currentIndex > 0
                                      ? () => _selectStudent(_pendingList[currentIndex - 1])
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    currentIndex >= 0
                                        ? '${currentIndex + 1} of ${_pendingList.length}'
                                        : '${_pendingList.length} Pending',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryPurple,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, size: 20),
                                  tooltip: 'Next Student',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: currentIndex >= 0 && currentIndex < _pendingList.length - 1
                                      ? () => _selectStudent(_pendingList[currentIndex + 1])
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Chip(
                            label: Text(
                              '${_pendingList.length} Pending Review',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                            ),
                            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    _isLoadingPending
                        ? const LinearProgressIndicator()
                        : _pendingList.isEmpty
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurple.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: AppTheme.success),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'All assessments have been reviewed! No pending students at this time.',
                                        style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : DropdownButtonFormField<String>(
                                value: dropdownValue,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  prefixIcon: const Icon(Icons.person_search_outlined),
                                ),
                                items: _pendingList.map((st) {
                                  final stIdStr = st['assessmentId']?.toString() ?? '';
                                  return DropdownMenuItem<String>(
                                    value: stIdStr,
                                    child: Text(
                                      '${st['studentName'] ?? "Unknown"} (ID: ${st['studentId'] ?? "-"} • ${st['strand'] ?? "N/A"})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (selectedIdStr) {
                                  if (selectedIdStr != null) {
                                    final found = _pendingList.firstWhere(
                                      (element) => element['assessmentId']?.toString() == selectedIdStr,
                                      orElse: () => _pendingList.first,
                                    );
                                    _selectStudent(found);
                                  }
                                },
                              ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 2. RESPONSIVE 2-COLUMN WORKSPACE ───────────────────────────
            if (_selectedStudent != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= 1050;
                  final scoresRaw = _selectedStudent!['scores'];
                  final scores = scoresRaw is Map ? Map<String, dynamic>.from(scoresRaw) : <String, dynamic>{};
                  final rseRaw = _selectedStudent!['rse'];
                  final rse = rseRaw is Map ? Map<String, dynamic>.from(rseRaw) : null;
                  final cdsesRaw = _selectedStudent!['cdses'];
                  final cdses = cdsesRaw is Map ? Map<String, dynamic>.from(cdsesRaw) : null;

                  final leftColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStudentHeaderCard(_selectedStudent!),
                      const SizedBox(height: 14),
                      if (!isPsych && _selectedStudent!['psychometricianNote'] != null) ...[
                        _buildPsychometricianBriefingBox(_selectedStudent!),
                        const SizedBox(height: 14),
                      ],
                      _buildHollandCodeCard(_selectedStudent!),
                      const SizedBox(height: 14),
                      _buildRiasecTraitBreakdown(scores),
                      const SizedBox(height: 14),
                      _buildPsychometricBadges(rse, cdses),
                    ],
                  );

                  final rightColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildClusterRecommendationsSection(context, _selectedStudent!),
                      const SizedBox(height: 16),
                      _buildGeneralInsightsBox(_selectedStudent!),
                      const SizedBox(height: 16),
                      _buildNotesAndActionCard(context, isPsych, isApproveOrEndorse),
                    ],
                  );

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 420,
                          child: leftColumn,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: rightColumn,
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        leftColumn,
                        const SizedBox(height: 16),
                        rightColumn,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STICKY BOTTOM ACTION BAR
  // -------------------------------------------------------------
  Widget _buildStickyBottomBar(bool isPsych, bool isApproveOrEndorse) {
    final stName = _selectedStudent?['studentName']?.toString() ?? 'Selected Student';
    final initials = _getInitials(stName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        border: Border(top: BorderSide(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Left: Student Quick Info
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primaryPurple.withOpacity(0.12),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ID: ${_selectedStudent?['studentId'] ?? "-"} • ${_selectedStudent?['strand'] ?? ""}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Decision Toggle
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: isPsych ? 'endorse' : 'approved',
                  label: Text(isPsych ? 'Endorse' : 'Approve', style: const TextStyle(fontSize: 11.5)),
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                ),
                ButtonSegment(
                  value: 'rejected',
                  label: Text(isPsych ? 'Flag Retake' : 'Retake', style: const TextStyle(fontSize: 11.5)),
                  icon: const Icon(Icons.cancel_outlined, size: 15),
                ),
              ],
              selected: {
                if (isPsych)
                  (_action == 'rejected' ? 'rejected' : 'endorse')
                else
                  (_action == 'rejected' ? 'rejected' : 'approved')
              },
              onSelectionChanged: (v) => setState(() => _action = v.first),
            ),
            const SizedBox(width: 14),

            // Submit Button
            ElevatedButton.icon(
              onPressed: _isSubmitting || _selectedStudent == null ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      isApproveOrEndorse
                          ? (isPsych ? Icons.send_rounded : Icons.mark_email_read_rounded)
                          : Icons.close,
                      size: 15,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Submitting...'
                    : isPsych
                        ? (isApproveOrEndorse ? 'Endorse to Counselor/Facilitator' : 'Flag for Retake')
                        : (_action == 'approved' ? 'Approve & Release' : 'Request Retake'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isApproveOrEndorse ? AppTheme.primaryPurple : const Color(0xFFE53E3E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STUDENT HEADER CARD
  // -------------------------------------------------------------
  Widget _buildStudentHeaderCard(Map<String, dynamic> st) {
    final initials = _getInitials(st['studentName']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.primaryPurple.withOpacity(0.12),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st['studentName']?.toString() ?? 'Student',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'ID: ${st['studentId'] ?? "-"} • ${st['gradeLevel'] ?? "Grade N/A"}',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (st['strand'] != null && st['strand'].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isDark ? Colors.white.withOpacity(0.08) : Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isDark ? Colors.white.withOpacity(0.12) : Colors.blueGrey.shade100),
                  ),
                  child: Text(
                    st['strand'].toString(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isDark ? Colors.white70 : Colors.blueGrey.shade700),
                  ),
                ),
              if (st['durationSeconds'] != null && (int.tryParse(st['durationSeconds'].toString()) ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: AppTheme.primaryPurple),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(st['durationSeconds']),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              if (st['submittedAt'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 11, color: _isDark ? Colors.white60 : Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        st['submittedAt'].toString().split(' ')[0],
                        style: TextStyle(fontSize: 11, color: _isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PSYCHOMETRICIAN BRIEFING BOX (for Guidance Counselor)
  // -------------------------------------------------------------
  Widget _buildPsychometricianBriefingBox(Map<String, dynamic> st) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF261D10) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF78350F).withOpacity(0.3) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lock_rounded, size: 16, color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Psychometrician Briefing (Confidential)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      'Staff-to-staff clinical briefing.',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isDark ? const Color(0xFFFDE68A).withOpacity(0.8) : const Color(0xFFB45309).withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (st['psychometricianNote'] is Map && st['psychometricianNote']['endorserName'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isDark ? const Color(0xFF78350F).withOpacity(0.3) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Endorsed by ${st['psychometricianNote']['endorserName']}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isDark ? const Color(0xFF1E170A) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
            ),
            child: Text(
              (st['psychometricianNote'] is Map ? (st['psychometricianNote']['notes'] ?? '') : st['psychometricianNote'].toString()),
              style: TextStyle(
                fontSize: 12,
                color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // HOLLAND CODE PROFILE CARD
  // -------------------------------------------------------------
  Widget _buildHollandCodeCard(Map<String, dynamic> st) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Holland Code Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (st['primaryType'] != null) _typeChip('Primary: ${st['primaryType']}', st['primaryType'].toString()),
              if (st['secondaryType'] != null) _typeChip('Secondary: ${st['secondaryType']}', st['secondaryType'].toString()),
              if (st['tertiaryType'] != null) _typeChip('Tertiary: ${st['tertiaryType']}', st['tertiaryType'].toString()),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MODERNIZED RIASEC TRAIT VISUALS
  // -------------------------------------------------------------
  Widget _buildRiasecTraitBreakdown(Map<String, dynamic> scores) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 16, color: AppTheme.primaryPurple),
              const SizedBox(width: 6),
              const Text(
                'RIASEC Trait Breakdown',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...['R', 'I', 'A', 'S', 'E', 'C'].map((trait) {
            final val = double.tryParse((scores[trait] ?? "0").toString()) ?? 0.0;
            final traitColor = AppTheme.riasecColor(trait);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: traitColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              trait,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: traitColor),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppTheme.riasecName(trait),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: traitColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${val.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: traitColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (val / 100).clamp(0.0, 1.0),
                      backgroundColor: _isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(traitColor),
                      minHeight: 8,
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

  // -------------------------------------------------------------
  // PSYCHOMETRIC ASSESSMENT BADGES (RSE & CDSES)
  // -------------------------------------------------------------
  Widget _buildPsychometricBadges(Map<String, dynamic>? rse, Map<String, dynamic>? cdses) {
    if (rse == null && cdses == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 16, color: AppTheme.primaryPurple),
              const SizedBox(width: 6),
              const Text(
                'Psychometric Assessment Badges',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryPurple),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rse != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: rse['level'].toString().toLowerCase().contains('low')
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: rse['level'].toString().toLowerCase().contains('low')
                      ? const Color(0xFFEF4444).withOpacity(0.4)
                      : const Color(0xFF16A34A).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    rse['level'].toString().toLowerCase().contains('low')
                        ? Icons.sentiment_dissatisfied
                        : Icons.sentiment_satisfied_alt,
                    color: rse['level'].toString().toLowerCase().contains('low')
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Self-Esteem: ${rse['level']}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rse['level'].toString().toLowerCase().contains('low')
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                          ),
                        ),
                        Text(
                          'Score: ${rse['score']} / 30',
                          style: TextStyle(
                            fontSize: 11,
                            color: rse['level'].toString().toLowerCase().contains('low')
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (rse != null && cdses != null) const SizedBox(height: 8),
          if (cdses != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, color: AppTheme.primaryPurple, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Decision Readiness: ${cdses['selfEfficacyLevel'] ?? "N/A"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                        Text(
                          'Total Score: ${(cdses['totalScore'] as num?)?.toInt() ?? 0} / 125',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _generateShapSynthesis(List<dynamic> explanations) {
    if (explanations.isEmpty) return '';

    final validExps = explanations.where((e) => e is Map && (e['feature'] != null || e['raw_feature'] != null)).toList();
    if (validExps.isEmpty) return '';

    final sorted = List<Map<String, dynamic>>.from(validExps)
      ..sort((a, b) => ((b['impact_score'] as num?)?.toDouble() ?? 0.0)
          .compareTo((a['impact_score'] as num?)?.toDouble() ?? 0.0));

    String getDescriptor(String name) {
      final l = name.toLowerCase();
      if (l.contains('investigative')) return 'analytical problem-solving';
      if (l.contains('social')) return 'passion for helping and mentoring others';
      if (l.contains('realistic')) return 'practical, hands-on focus';
      if (l.contains('artistic')) return 'creative and innovative expression';
      if (l.contains('enterprising')) return 'leadership drive and initiative';
      if (l.contains('conventional')) return 'structured precision and organization';
      return 'strengths';
    }

    String getTraitName(String name) {
      final l = name.toLowerCase();
      if (l.contains('investigative')) return 'Investigative';
      if (l.contains('social')) return 'Social';
      if (l.contains('realistic')) return 'Realistic';
      if (l.contains('artistic')) return 'Artistic';
      if (l.contains('enterprising')) return 'Enterprising';
      if (l.contains('conventional')) return 'Conventional';
      return name.replaceAll(' Interest', '').replaceAll(' Score', '');
    }

    final top1 = sorted[0];
    final feat1 = (top1['feature'] ?? top1['raw_feature'] ?? '').toString();
    final impact1 = (top1['impact_score'] as num?)?.toDouble() ?? 0.0;
    final desc1 = getDescriptor(feat1);
    final name1 = getTraitName(feat1);

    if (sorted.length > 1) {
      final top2 = sorted[1];
      final feat2 = (top2['feature'] ?? top2['raw_feature'] ?? '').toString();
      final impact2 = (top2['impact_score'] as num?)?.toDouble() ?? 0.0;
      final desc2 = getDescriptor(feat2);
      final name2 = getTraitName(feat2);

      if (impact1 >= 0.65 || impact2 < 0.12) {
        return 'Primarily driven by the student\'s $name1 mindset ($desc1).';
      }

      return 'Driven by the student\'s $name1 mindset ($desc1) paired with $name2 strengths ($desc2).';
    }

    return 'Driven primarily by the student\'s $name1 mindset ($desc1).';
  }

  // -------------------------------------------------------------
  // TOP RECOMMENDED COURSE CLUSTERS SECTION
  // -------------------------------------------------------------
  Widget _buildClusterRecommendationsSection(BuildContext context, Map<String, dynamic> st) {
    final clusterRecsRaw = _editableClusterRecs.isNotEmpty
        ? _editableClusterRecs
        : (st['clusterRecommendations'] as List? ?? []);
    final recsRaw = st['recommendations'] as List? ?? [];
    final recs = recsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: AppTheme.primaryPurple, size: 20),
              const SizedBox(width: 8),
              Text(
                'Top Recommended Course Clusters',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _isDark ? AppTheme.lilac : Colors.purple.shade900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (clusterRecsRaw.isNotEmpty) ...[
            ...clusterRecsRaw.map((clusterItem) {
              final cluster = Map<String, dynamic>.from(clusterItem as Map);
              final rank = cluster['rank'] as int? ?? 1;
              final clusterName = (cluster['cluster_name'] ?? 'General Cluster').toString();
              final matchPct = (cluster['match_percentage'] as num?)?.toDouble() ?? 0.0;
              final shapExps = List<Map<String, dynamic>>.from(cluster['shap_explanations'] ?? []);
              final exploreCourses = List<String>.from(cluster['explore_courses'] ?? []);

              Color rankColor;
              if (rank == 1) {
                rankColor = const Color(0xFFD97706);
              } else if (rank == 2) {
                rankColor = const Color(0xFF7C3AED);
              } else {
                rankColor = const Color(0xFF0284C7);
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: _isDark ? const Color(0xFF161426) : Colors.white,
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
                              rank == 1
                                  ? '🥇 Primary Recommendation'
                                  : rank == 2
                                      ? '🥈 Alternative Recommendation'
                                      : '🥉 Additional Recommendation',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: rankColor.withOpacity(0.12),
                            labelStyle: TextStyle(color: rankColor),
                          ),
                          Text(
                            '${matchPct.toStringAsFixed(1)}% Predicted Probability',
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
                              if (shapExps.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.purple.shade100),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 1.5),
                                        child: Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFFD97706)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _generateShapSynthesis(shapExps),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontStyle: FontStyle.italic,
                                            height: 1.35,
                                            fontWeight: FontWeight.w500,
                                            color: _isDark ? Colors.white70 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (exploreCourses.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '📌 Recommended Courses under this Cluster:',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _isDark ? Colors.white : Colors.grey.shade800),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add_circle_outline, size: 14, color: AppTheme.primaryPurple),
                              label: const Text('Add Course', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _showSwapDialog(
                                clusterIndex: clusterRecsRaw.indexOf(clusterItem),
                                courseIndex: -1, // Add new
                                currentCourse: '',
                                clusterName: clusterName,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...exploreCourses.asMap().entries.map((entry) {
                          final cIdx = entry.key;
                          final crs = entry.value;
                          final cRecIdx = clusterRecsRaw.indexOf(clusterItem);
                          final raw = crs.toString();
                          final isJmcfi = JmcfiBadge.isJmcfiCourse(raw);
                          final cleanName = JmcfiBadge.cleanCourseTitle(raw);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : AppTheme.dividerColor.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_right_rounded, size: 16, color: AppTheme.primaryPurple),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Tooltip(
                                            message: cleanName,
                                            child: Text(
                                              cleanName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                height: 1.25,
                                                color: _isDark ? Colors.white : const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isJmcfi) ...[
                                          const SizedBox(width: 8),
                                          const JmcfiBadge(),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(4),
                                    onTap: () => _showSwapDialog(
                                      clusterIndex: cRecIdx,
                                      courseIndex: cIdx,
                                      currentCourse: crs,
                                      clusterName: clusterName,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _isDark ? Colors.white.withOpacity(0.08) : AppTheme.primaryPurple.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.swap_horiz_rounded, size: 14, color: AppTheme.primaryPurple),
                                          SizedBox(width: 4),
                                          Text(
                                            'Swap',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFE53E3E)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Remove Course',
                                    onPressed: () {
                                      setState(() {
                                        if (cRecIdx >= 0 && cRecIdx < _editableClusterRecs.length) {
                                          final currentList = List<String>.from(_editableClusterRecs[cRecIdx]['explore_courses'] ?? []);
                                          currentList.removeAt(cIdx);
                                          _editableClusterRecs[cRecIdx]['explore_courses'] = currentList;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ] else if (recs.isNotEmpty) ...[
            Column(
              children: recs.take(3).map((r) {
                final scoreVal = double.tryParse((r['MatchScore'] ?? '0').toString()) ?? 0.0;
                final rawName = r['CourseName']?.toString() ?? '';
                final isJmcfi = JmcfiBadge.isJmcfiCourse(rawName);
                final cleanName = JmcfiBadge.cleanCourseTitle(rawName);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Rank ${r['Rank'] ?? 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                cleanName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isJmcfi) ...[
                              const SizedBox(width: 8),
                              const JmcfiBadge(),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${scoreVal.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Text('No course recommendations available.', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // NOTES AND EVALUATION ACTION CARD
  // -------------------------------------------------------------
  Widget _buildNotesAndActionCard(BuildContext context, bool isPsych, bool isApproveOrEndorse) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decision Explanation Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isApproveOrEndorse
                  ? AppTheme.success.withOpacity(0.08)
                  : const Color(0xFFE53E3E).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isApproveOrEndorse ? Icons.check_circle : Icons.info_outline,
                  color: isApproveOrEndorse ? AppTheme.success : const Color(0xFFE53E3E),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isPsych
                        ? (isApproveOrEndorse
                            ? 'The assessment will be forwarded to the Guidance Counselor/Facilitator with your notes and course calibrations.'
                            : 'The student will be asked to retake the assessment. Your notes will be logged.')
                        : (_action == 'approved'
                            ? 'The student will immediately receive an official email notification, and their career match results will be unlocked on their student dashboard and official report.'
                            : 'The student will be prompted to retake the assessment. Your counseling notes below will guide them.'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isApproveOrEndorse ? AppTheme.success : const Color(0xFFE53E3E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notes Header
          Row(
            children: [
              Text(
                isPsych ? 'Notes for Counselor/Facilitator' : 'Counselor/Facilitator\'s Note',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPsych
                      ? (_isDark ? const Color(0xFF261D10) : const Color(0xFFFEF3C7))
                      : (_isDark ? const Color(0xFF064E3B).withOpacity(0.4) : const Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPsych
                        ? (_isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B))
                        : (_isDark ? const Color(0xFF059669) : const Color(0xFF16A34A)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPsych ? Icons.lock_outline : Icons.visibility_outlined,
                      size: 12,
                      color: isPsych
                          ? (_isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                          : (_isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPsych ? 'Staff Eyes Only' : 'Visible on Student Results & PDF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isPsych
                            ? (_isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                            : (_isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isApproveOrEndorse) ...[
            const SizedBox(height: 4),
            Text(
              isPsych
                  ? 'Explain why you are flagging this assessment for retake.'
                  : 'Provide clear recommendations explaining why a retake is requested.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: isPsych
                  ? (isApproveOrEndorse
                      ? 'e.g. Student shows strong Artistic & Enterprising traits. Calibrated cluster towards Multimedia Arts. Recommended for JMCFI BS EMC during counseling interview...'
                      : 'e.g. Irregular test completion time detected; scores indicate random answering pattern...')
                  : (_action == 'approved'
                      ? 'e.g. Congratulations on completing your assessment! Based on your strong Conventional and Investigative traits, you are well-positioned for STEM and Business Computing programs. We invite you to visit the Guidance Office to discuss scholarship and enrollment pathways...'
                      : 'e.g. Please retake the assessment in a quiet environment without distraction...'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              prefixIcon: const Icon(Icons.notes),
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting || _selectedStudent == null ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          isApproveOrEndorse
                              ? (isPsych ? Icons.send_rounded : Icons.mark_email_read_rounded)
                              : Icons.close,
                          size: 16,
                        ),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting...'
                        : isPsych
                            ? (isApproveOrEndorse
                                ? 'Endorse to Guidance Counselor/Facilitator'
                                : 'Flag for Retake')
                            : (_action == 'approved'
                                ? 'Approve & Release to Student'
                                : 'Request Retake & Notify Student'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isApproveOrEndorse ? AppTheme.primaryPurple : const Color(0xFFE53E3E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.go('$prefix/pending-approvals'),
              child: Text(
                isPsych ? 'Back to Pending Evaluations' : 'Back to Endorsed Queue',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String code) {
    final color = AppTheme.riasecColor(code);
    return Chip(
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
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
    final existingInsights = a['generalInsights'] as Map<String, dynamic>?;

    final isCalibrated = existingInsights != null &&
        ((existingInsights['riasec'] ?? '').toString().trim().isNotEmpty ||
         (existingInsights['rse'] ?? '').toString().trim().isNotEmpty ||
         (existingInsights['cdses'] ?? '').toString().trim().isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryPurple.withOpacity(_isDark ? 0.3 : 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.2 : 0.05),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'General Assessment Insights & Summary',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _isDark ? AppTheme.lilac : Colors.purple.shade900,
                              ),
                            ),
                          ),
                          if (isPsych)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.2)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 14, color: AppTheme.primaryPurple),
                                  SizedBox(width: 4),
                                  Text(
                                    'Editable Insights',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryPurple),
                                  ),
                                ],
                              ),
                            )
                          else if (isCalibrated)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isDark ? const Color(0xFF261D10) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_user_rounded, size: 14, color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Calibrated by Psychometrician',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isPsych
                            ? 'Review and refine the psychometric interpretations below for the guidance counselor/facilitator. Use "Reset" to restore AI defaults.'
                            : 'Holistic synthesis across RIASEC Interests, Self-Esteem (RSE), and Decision Self-Efficacy (CDSES)',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isPsych ? AppTheme.primaryPurple.withOpacity(0.8) : Colors.grey.shade600,
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
            _buildRiasecInsightSection(primary, secondary, tertiary, scores, existingInsights),

            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 2. Self-Esteem Profile (RSE) Insights
            _buildRseInsightSection(rse, existingInsights),

            const SizedBox(height: 14),
            Divider(height: 1, thickness: 0.8, color: AppTheme.dividerColor),
            const SizedBox(height: 14),

            // 3. Career Decision Self-Efficacy (CDSES) Insights
            _buildCdsesInsightSection(cdses, existingInsights),
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
    Map<String, dynamic>? existingInsights,
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

    final hasCustom = existingInsights != null && (existingInsights['riasec'] ?? '').toString().trim().isNotEmpty;
    final displayText = _riasecInsightController.text.isNotEmpty
        ? _riasecInsightController.text
        : (hasCustom ? existingInsights['riasec'].toString() : _defaultRiasecInsight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: 16, color: AppTheme.primaryPurple),
            const SizedBox(width: 6),
            Text(
              '1. RIASEC Interest Profile Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const Spacer(),
            if (isPsych)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _riasecInsightController.text = _defaultRiasecInsight;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('RIASEC insight reset to default.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.primaryPurple),
                label: const Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else if (hasCustom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF261D10) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B)),
                ),
                child: Text('Calibrated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))),
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
        if (isPsych)
          TextFormField(
            controller: _riasecInsightController,
            maxLines: null,
            minLines: 2,
            style: TextStyle(fontSize: 12, height: 1.45, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Enter calibrated RIASEC interest profile narrative...',
              filled: true,
              fillColor: _isDark ? const Color(0xFF161426) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppTheme.primaryPurple, width: 1.5)),
            ),
          )
        else
          Text(
            displayText,
            style: TextStyle(fontSize: 12, height: 1.45, color: _isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
      ],
    );
  }

  // 2. RSE Section
  Widget _buildRseInsightSection(Map<String, dynamic>? rse, Map<String, dynamic>? existingInsights) {
    if (rse == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, size: 16, color: Colors.pink.shade400),
              const SizedBox(width: 6),
              Text(
                '2. Self-Esteem Profile (RSE) Insights',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Self-Esteem assessment data is not yet recorded for this student.',
            style: TextStyle(fontSize: 12, color: _isDark ? Colors.white60 : Colors.grey.shade600),
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

    final hasCustom = existingInsights != null && (existingInsights['rse'] ?? '').toString().trim().isNotEmpty;
    final displayText = _rseInsightController.text.isNotEmpty
        ? _rseInsightController.text
        : (hasCustom ? existingInsights['rse'].toString() : _defaultRseInsight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.favorite_rounded, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              '2. Self-Esteem Profile (RSE) Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const Spacer(),
            if (isPsych)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _rseInsightController.text = _defaultRseInsight;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Self-Esteem insight reset to default.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: Icon(Icons.refresh_rounded, size: 14, color: badgeColor),
                label: Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: badgeColor)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else if (hasCustom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF261D10) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B)),
                ),
                child: Text('Calibrated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))),
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
        if (isPsych)
          TextFormField(
            controller: _rseInsightController,
            maxLines: null,
            minLines: 2,
            style: TextStyle(fontSize: 12, height: 1.45, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Enter calibrated Self-Esteem narrative...',
              filled: true,
              fillColor: _isDark ? const Color(0xFF161426) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: badgeColor, width: 1.5)),
            ),
          )
        else
          Text(
            displayText,
            style: TextStyle(fontSize: 12, height: 1.45, color: _isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
      ],
    );
  }

  // 3. CDSES Section
  Widget _buildCdsesInsightSection(Map<String, dynamic>? cdses, Map<String, dynamic>? existingInsights) {
    if (cdses == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_rounded, size: 16, color: AppTheme.primaryPurple),
              const SizedBox(width: 6),
              Text(
                '3. Career Decision Self-Efficacy (CDSES) Insights',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Career Decision Self-Efficacy assessment data is not yet recorded for this student.',
            style: TextStyle(fontSize: 12, color: _isDark ? Colors.white60 : Colors.grey.shade600),
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

    final hasCustom = existingInsights != null && (existingInsights['cdses'] ?? '').toString().trim().isNotEmpty;
    final displayText = _cdsesInsightController.text.isNotEmpty
        ? _cdsesInsightController.text
        : (hasCustom ? existingInsights['cdses'].toString() : _defaultCdsesInsight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.explore_rounded, size: 16, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              '3. Career Decision Self-Efficacy (CDSES) Insights',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const Spacer(),
            if (isPsych)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _cdsesInsightController.text = _defaultCdsesInsight;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CDSES insight reset to default.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: Icon(Icons.refresh_rounded, size: 14, color: badgeColor),
                label: Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: badgeColor)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            else if (hasCustom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF261D10) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _isDark ? const Color(0xFF92400E) : const Color(0xFFF59E0B)),
                ),
                child: Text('Calibrated', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))),
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
                color: _isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
              ),
              child: Text(
                'Highest: ${highest['code']} (${(highest['score'] as double).toStringAsFixed(2)})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300),
              ),
              child: Text(
                'Lowest: ${lowest['code']} (${(lowest['score'] as double).toStringAsFixed(2)})',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isPsych)
          TextFormField(
            controller: _cdsesInsightController,
            maxLines: null,
            minLines: 2,
            style: TextStyle(fontSize: 12, height: 1.45, color: _isDark ? Colors.white : const Color(0xFF1E293B)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Enter calibrated CDSES narrative...',
              filled: true,
              fillColor: _isDark ? const Color(0xFF161426) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: badgeColor, width: 1.5)),
            ),
          )
        else
          Text(
            displayText,
            style: TextStyle(fontSize: 12, height: 1.45, color: _isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
      ],
    );
  }
}