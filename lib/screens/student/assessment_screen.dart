import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final _session = SessionManager();
  int _currentIndex = 0;

  // Answers by scale
  final Map<int, int> _riasecAnswers = {};
  final Map<int, int> _rseAnswers = {};
  final Map<int, int> _cdsesAnswers = {};

  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _loadQuestions();
  }

  void _restoreProgress() {
    final storage = html.window.localStorage;
    final savedRiasec = storage['riasec_answers_v2'];
    final savedRse = storage['rse_answers_v2'];
    final savedCdses = storage['cdses_answers_v2'];
    final savedIndex = storage['currentIndex_v2'];

    if (savedRiasec != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedRiasec);
        setState(() {
          decoded.forEach((key, value) {
            _riasecAnswers[int.parse(key)] = value;
          });
        });
      } catch (_) {}
    }
    if (savedRse != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedRse);
        setState(() {
          decoded.forEach((key, value) {
            _rseAnswers[int.parse(key)] = value;
          });
        });
      } catch (_) {}
    }
    if (savedCdses != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedCdses);
        setState(() {
          decoded.forEach((key, value) {
            _cdsesAnswers[int.parse(key)] = value;
          });
        });
      } catch (_) {}
    }

    if (savedIndex != null) {
      setState(() {
        _currentIndex = int.tryParse(savedIndex) ?? 0;
      });
    }
  }

  void _saveProgress() {
    final storage = html.window.localStorage;

    final Map<String, int> encRiasec = {};
    _riasecAnswers.forEach((key, value) => encRiasec[key.toString()] = value);
    storage['riasec_answers_v2'] = jsonEncode(encRiasec);

    final Map<String, int> encRse = {};
    _rseAnswers.forEach((key, value) => encRse[key.toString()] = value);
    storage['rse_answers_v2'] = jsonEncode(encRse);

    final Map<String, int> encCdses = {};
    _cdsesAnswers.forEach((key, value) => encCdses[key.toString()] = value);
    storage['cdses_answers_v2'] = jsonEncode(encCdses);

    storage['currentIndex_v2'] = _currentIndex.toString();
  }

  Future<void> _loadQuestions() async {
    try {
      final data = await ApiService.getQuestions();
      if (data['status'] == 'success') {
        final List<Map<String, dynamic>> loadedQuestions = [];

        // Add RIASEC questions
        if (data['riasec'] != null) {
          final riasec = List<Map<String, dynamic>>.from(data['riasec']);
          for (var q in riasec) {
            loadedQuestions.add({
              'id': q['id'],
              'question': q['question'],
              'type': 'riasec',
              'category': q['category'],
            });
          }
        }

        // Add RSE questions
        if (data['rse'] != null) {
          final rse = List<Map<String, dynamic>>.from(data['rse']);
          for (var q in rse) {
            loadedQuestions.add({
              'id': q['id'],
              'question': q['question'],
              'type': 'rse',
              'category': q['isNegative'].toString(),
            });
          }
        }

        // Add CDSES questions
        if (data['cdses'] != null) {
          final cdses = List<Map<String, dynamic>>.from(data['cdses']);
          for (var q in cdses) {
            loadedQuestions.add({
              'id': q['id'],
              'question': q['question'],
              'type': 'cdses',
              'category': q['subscale'],
            });
          }
        }

        setState(() {
          _questions = loadedQuestions;
          _isLoading = false;
        });
        _restoreProgress();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load questions. Please try again.')),
        );
      }
    }
  }

  Future<void> _updateLiveSession() async {
    if (_session.currentAssessmentId == null) return;
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    await ApiService.updateLiveSession(
      _session.currentAssessmentId!,
      _currentIndex + 1,
      duration,
    );
  }

  void _selectScore(int score) {
    if (_questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    final type = currentQ['type'];
    final questionId = currentQ['id'] as int;

    setState(() {
      if (type == 'riasec') {
        _riasecAnswers[questionId] = score;
      } else if (type == 'rse') {
        _rseAnswers[questionId] = score;
      } else if (type == 'cdses') {
        _cdsesAnswers[questionId] = score;
      }
    });
    _saveProgress();

    // Auto-advance to the next question with a smooth 250ms feedback delay
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        if (_currentIndex < _questions.length - 1) {
          setState(() {
            _currentIndex++;
          });
          _updateLiveSession();
        }
      }
    });
  }

  void _next() {
    if (_questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    final type = currentQ['type'];
    final questionId = currentQ['id'] as int;

    bool answered = false;
    if (type == 'riasec') {
      answered = _riasecAnswers.containsKey(questionId);
    } else if (type == 'rse') {
      answered = _rseAnswers.containsKey(questionId);
    } else if (type == 'cdses') {
      answered = _cdsesAnswers.containsKey(questionId);
    }

    if (!answered) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an answer before continuing.')),
      );
      return;
    }

    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      _updateLiveSession();
    } else {
      _confirmSubmit();
    }
  }

  void _previous() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Assessment'),
        content: const Text(
          'Are you sure you want to submit? You cannot change your answers after submission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Review Answers'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    Navigator.pop(ctx);
                    _submitAssessment();
                  },
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAssessment() async {
    if (_session.currentAssessmentId == null) return;
    setState(() => _isSubmitting = true);

    final riasecList = _riasecAnswers.entries
        .map((e) => {'questionId': e.key, 'score': e.value})
        .toList();
    final rseList = _rseAnswers.entries
        .map((e) => {'questionId': e.key, 'score': e.value})
        .toList();
    final cdsesList = _cdsesAnswers.entries
        .map((e) => {'questionId': e.key, 'score': e.value})
        .toList();

    try {
      final data = await ApiService.submitAssessment(
        assessmentId: _session.currentAssessmentId!,
        answers: riasecList,
        rseAnswers: rseList,
        cdsesAnswers: cdsesList,
      );

      if (data['status'] == 'success') {
        _session.currentResultId = int.tryParse(data['resultId'].toString());
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              icon: Icon(Icons.check_circle, color: AppTheme.success, size: 48),
              title: const Text('Assessment Submitted!'),
              content: const Text(
                'Your assessments (RIASEC, Self-Esteem, and Career Decision Self-Efficacy) have been submitted and are now pending review by your guidance counselor. '
                'You will be notified once results are available.',
                textAlign: TextAlign.center,
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    html.window.localStorage.remove('riasec_answers_v2');
                    html.window.localStorage.remove('rse_answers_v2');
                    html.window.localStorage.remove('cdses_answers_v2');
                    html.window.localStorage.remove('currentIndex_v2');
                    context.go('/student/dashboard');
                  },
                  child: const Text('Return to Dashboard'),
                ),
              ],
            ),
          );
        }
      } else {
        throw Exception(data['message']);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Color _getScoreColorForType(String type, int value) {
    if (type == 'riasec') {
      return value == 1 ? AppTheme.success : AppTheme.error;
    } else if (type == 'rse') {
      switch (value) {
        case 1: return AppTheme.primaryPurple;
        case 2: return AppTheme.success;
        case 3: return AppTheme.warning;
        case 4: return AppTheme.error;
        default: return AppTheme.textSecondary;
      }
    } else { // cdses
      switch (value) {
        case 1: return AppTheme.error;
        case 2: return Colors.orange;
        case 3: return AppTheme.primaryYellow;
        case 4: return Colors.blue;
        case 5: return AppTheme.success;
        default: return AppTheme.textSecondary;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assessments Portal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assessments Portal')),
        body: const Center(child: Text('No questions available.')),
      );
    }

    final current = _questions[_currentIndex];
    final questionId = current['id'] as int;
    final progress = (_currentIndex + 1) / _questions.length;
    final type = current['type'] as String;

    int? selectedScore;
    if (type == 'riasec') {
      selectedScore = _riasecAnswers[questionId];
    } else if (type == 'rse') {
      selectedScore = _rseAnswers[questionId];
    } else if (type == 'cdses') {
      selectedScore = _cdsesAnswers[questionId];
    }

    // Dynamic Title and Instruction setup based on section
    String partTitle = '';
    String partDesc = '';
    String instructionHeader = '';
    IconData partIcon = Icons.quiz_outlined;
    Color partThemeColor = AppTheme.primaryPurple;
    List<Map<String, dynamic>> options = [];

    if (type == 'riasec') {
      partTitle = 'Part 1: Career Interests (RIASEC)';
      instructionHeader = 'How to Answer:';
      partDesc = 'Read each statement carefully and select "Agree" if it describes an activity or interest you enjoy, or "Disagree" if it does not.';
      partIcon = Icons.psychology_outlined;
      partThemeColor = AppTheme.primaryPurple;
      options = [
        {'label': 'Agree', 'value': 1, 'subtitle': 'I like or prefer this'},
        {'label': 'Disagree', 'value': 0, 'subtitle': 'I do not like or prefer this'},
      ];
    } else if (type == 'rse') {
      partTitle = 'Part 2: Rosenberg Self-Esteem';
      instructionHeader = 'Rate Your Agreement:';
      partDesc = 'Select how strongly you agree or disagree with each statement regarding your general feelings about yourself.';
      partIcon = Icons.sentiment_satisfied_alt_outlined;
      partThemeColor = Colors.teal;
      options = [
        {'label': 'Strongly Agree', 'value': 1, 'subtitle': 'Completely true for me'},
        {'label': 'Agree', 'value': 2, 'subtitle': 'Mostly true for me'},
        {'label': 'Disagree', 'value': 3, 'subtitle': 'Mostly untrue for me'},
        {'label': 'Strongly Disagree', 'value': 4, 'subtitle': 'Completely untrue for me'},
      ];
    } else if (type == 'cdses') {
      partTitle = 'Part 3: Career Decision Self-Efficacy';
      instructionHeader = 'Rate Your Confidence:';
      partDesc = 'Indicate how much confidence you have that you could successfully accomplish each career-related task below.';
      partIcon = Icons.auto_graph_outlined;
      partThemeColor = Colors.indigo;
      options = [
        {'label': 'No Confidence At All', 'value': 1, 'subtitle': 'Cannot do this at all'},
        {'label': 'Very Little Confidence', 'value': 2, 'subtitle': 'Low chance of doing this'},
        {'label': 'Moderate Confidence', 'value': 3, 'subtitle': 'Somewhat confident'},
        {'label': 'Much Confidence', 'value': 4, 'subtitle': 'Fairly confident'},
        {'label': 'Complete Confidence', 'value': 5, 'subtitle': 'Extremely confident'},
      ];
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.backgroundWhite,
          surfaceTintColor: Colors.transparent,
          title: Text(
            partTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          leadingWidth: 150,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showExitDialog(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Leave Portal',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            // Stage Stepper Chips
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  _buildStageChip('1. RIASEC', type == 'riasec', AppTheme.primaryPurple),
                  const SizedBox(width: 6),
                  _buildStageChip('2. Self-Esteem', type == 'rse', Colors.teal),
                  const SizedBox(width: 6),
                  _buildStageChip('3. CDSES', type == 'cdses', Colors.indigo),
                ],
              ),
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF6F8FC),
                Color(0xFFEDF2F9),
              ],
            ),
          ),
          child: Column(
            children: [
              // Progress Bar Header Container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(partIcon, size: 18, color: partThemeColor),
                            const SizedBox(width: 8),
                            Text(
                              'Question ${_currentIndex + 1} of ${_questions.length}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: partThemeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${(progress * 100).toInt()}% Complete',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: partThemeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: partThemeColor.withOpacity(0.12),
                        color: partThemeColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Main Assessment Scroll Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Prominent Instruction Banner Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  partThemeColor.withOpacity(0.09),
                                  partThemeColor.withOpacity(0.03),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: partThemeColor.withOpacity(0.25),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: partThemeColor.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: partThemeColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        instructionHeader,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: partThemeColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        partDesc,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.45,
                                          color: Color(0xFF334155),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Glassmorphic / Modern Elevated Question Card
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: partThemeColor.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: partThemeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(partIcon, size: 14, color: partThemeColor),
                                          const SizedBox(width: 6),
                                          Text(
                                            type == 'riasec'
                                                ? 'Career Statement'
                                                : type == 'rse'
                                                    ? 'Self-Esteem Item'
                                                    : 'Decision Confidence Task',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: partThemeColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '#${_currentIndex + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textSecondary.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  current['question'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    height: 1.4,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Choice Options Header
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'SELECT YOUR RESPONSE:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),

                          // Options Cards Mapping
                          ...options.map((option) {
                            final value = option['value'] as int;
                            final isSelected = selectedScore == value;
                            final color = _getScoreColorForType(type, value);
                            final subtitle = option['subtitle'] as String?;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _selectScore(value),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? color.withOpacity(0.08) 
                                          : AppTheme.backgroundWhite,
                                      border: Border.all(
                                        color: isSelected ? color : const Color(0xFFE2E8F0),
                                        width: isSelected ? 2.5 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withOpacity(0.18),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              )
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.02),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                            ],
                                    ),
                                    child: Row(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          width: 26,
                                          height: 26,
                                          decoration: BoxDecoration(
                                            color: isSelected ? color : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected ? color : const Color(0xFF94A3B8),
                                              width: 2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: isSelected
                                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                : const SizedBox(),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                option['label'],
                                                style: TextStyle(
                                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                  color: isSelected ? color : const Color(0xFF1E293B),
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (subtitle != null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: isSelected 
                                                        ? color.withOpacity(0.85) 
                                                        : const Color(0xFF64748B),
                                                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 16,
                                            color: color,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Sleek Footer Navigation Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentIndex > 0)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _previous,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text(
                          'Previous',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      const SizedBox(),
                    _isSubmitting
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: partThemeColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _next,
                            icon: Icon(
                              _currentIndex == _questions.length - 1
                                  ? Icons.check_circle_outline
                                  : Icons.arrow_forward_rounded,
                              size: 20,
                            ),
                            label: Text(
                              _currentIndex == _questions.length - 1 ? 'Submit Assessment' : 'Next Question',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageChip(String label, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.12) : Colors.transparent,
        border: Border.all(
          color: isActive ? color : const Color(0xFFCBD5E1),
          width: isActive ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          color: isActive ? color : const Color(0xFF64748B),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Assessment?'),
        content: const Text(
          'Your progress will be saved in your local storage, but leaving now will interrupt the assessment. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                if (_session.currentAssessmentId != null) {
                  await ApiService.cancelAssessment(_session.currentAssessmentId!);
                  _session.currentAssessmentId = null;
                }
                // Clear local progress
                html.window.localStorage.remove('riasec_answers_v2');
                html.window.localStorage.remove('rse_answers_v2');
                html.window.localStorage.remove('mbi_answers_v2');
                html.window.localStorage.remove('currentIndex_v2');
              } catch (_) {}

              if (mounted) {
                context.go('/student/dashboard');
              }
            },
            child: const Text('Leave & Cancel'),
          ),
        ],
      ),
    );
  }
}