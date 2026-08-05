import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/student_sidebar.dart';

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

    // Dynamic Title based on section
    String partTitle = '';
    String partDesc = '';
    List<Map<String, dynamic>> options = [];

    if (type == 'riasec') {
      partTitle = 'Part 1: Career Interests (RIASEC)';
      partDesc = 'Select "Agree" or "Disagree" for each statement based on your preferences.';
      options = [
        {'label': 'Agree', 'value': 1},
        {'label': 'Disagree', 'value': 0},
      ];
    } else if (type == 'rse') {
      partTitle = 'Part 2: Rosenberg Self-Esteem';
      partDesc = 'Rate your agreement with the self-esteem statements below.';
      options = [
        {'label': 'Strongly Agree', 'value': 1},
        {'label': 'Agree', 'value': 2},
        {'label': 'Disagree', 'value': 3},
        {'label': 'Strongly Disagree', 'value': 4},
      ];
    } else if (type == 'cdses') {
      partTitle = 'Part 3: Career Decision Self-Efficacy (CDSES-SF)';
      partDesc = 'How much confidence do you have that you could:';
      options = [
        {'label': 'No confidence at all', 'value': 1},
        {'label': 'Very little confidence', 'value': 2},
        {'label': 'Moderate confidence', 'value': 3},
        {'label': 'Much confidence', 'value': 4},
        {'label': 'Complete confidence', 'value': 5},
      ];
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(partTitle),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showExitDialog(),
          ),
        ),
        body: Column(
          children: [
            // Progress Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              color: AppTheme.backgroundWhite,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentIndex + 1} of ${_questions.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    partDesc,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            // Question text and choices list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question Card
                        Card(
                          elevation: 3,
                          shadowColor: Colors.black12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.backgroundWhite,
                                  AppTheme.backgroundLight.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      type == 'riasec'
                                          ? 'Career Interest Statement'
                                          : type == 'rse'
                                              ? 'Self-Esteem Statement'
                                              : 'Academic Burnout Indicator',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryPurple,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    current['question'],
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Options mapping
                        ...options.map((option) {
                          final value = option['value'] as int;
                          final isSelected = selectedScore == value;
                          final color = _getScoreColorForType(type, value);
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () => _selectScore(value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                decoration: BoxDecoration(
                                  color: isSelected ? color.withOpacity(0.06) : AppTheme.backgroundWhite,
                                  border: Border.all(
                                    color: isSelected ? color : AppTheme.dividerColor.withOpacity(0.8),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: isSelected ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ] : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected ? color : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected ? color : AppTheme.textSecondary.withOpacity(0.4),
                                          width: 2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: isSelected 
                                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                                          : const SizedBox(),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        option['label'],
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? color : AppTheme.textPrimary,
                                          fontSize: 15
                                        ),
                                      ),
                                    ),
                                  ],
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

            // Footer navigation bar
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.backgroundWhite,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentIndex > 0)
                    OutlinedButton.icon(
                      onPressed: _previous,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    )
                  else
                    const SizedBox(),
                  _isSubmitting
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _next,
                          icon: Icon(
                            _currentIndex == _questions.length - 1
                                ? Icons.check
                                : Icons.arrow_forward,
                          ),
                          label: Text(
                            _currentIndex == _questions.length - 1 ? 'Submit' : 'Next',
                          ),
                        ),
                ],
              ),
            ),
          ],
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