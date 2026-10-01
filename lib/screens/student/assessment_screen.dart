import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF12121E) : const Color(0xFFF6F8FC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppTheme.primaryPurple,
          foregroundColor: Colors.white,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Student Assessment',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
        ),
        body: Stack(
          children: [
            // Ambient Fluid Background Waves
            Positioned.fill(
              child: CustomPaint(
                painter: AssessmentBackgroundPainter(isDark: isDark),
              ),
            ),

            Column(
              children: [
                // Progress Header Container
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
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
                              Icon(partIcon, size: 18, color: AppTheme.primaryPurple),
                              const SizedBox(width: 8),
                              Text(
                                'Question ${_currentIndex + 1} of ${_questions.length}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${(progress * 100).toInt()}% Complete',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppTheme.primaryPurple,
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
                          backgroundColor: AppTheme.primaryPurple.withOpacity(0.12),
                          color: AppTheme.primaryPurple,
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
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Dot Matrix Accents
                            Positioned(
                              top: -15,
                              left: -20,
                              child: CustomPaint(
                                size: const Size(60, 60),
                                painter: FormDotGridPainter(
                                  color: AppTheme.primaryPurple.withOpacity(isDark ? 0.3 : 0.25),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 10,
                              right: -20,
                              child: CustomPaint(
                                size: const Size(60, 60),
                                painter: FormDotGridPainter(
                                  color: AppTheme.primaryPurple.withOpacity(isDark ? 0.3 : 0.25),
                                ),
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Instruction Banner Card
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryPurple.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppTheme.primaryPurple.withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryPurple.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.lightbulb_outline_rounded,
                                          color: AppTheme.primaryPurple,
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
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: AppTheme.primaryPurple,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              partDesc,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13.5,
                                                height: 1.45,
                                                color: isDark ? Colors.white70 : const Color(0xFF334155),
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

                                // Glassmorphic Question Card
                                Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF2E2E3E) : Colors.white,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryPurple.withOpacity(0.08),
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
                                              color: AppTheme.primaryPurple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(partIcon, size: 14, color: AppTheme.primaryPurple),
                                                const SizedBox(width: 6),
                                                Text(
                                                  type == 'riasec'
                                                      ? 'Career Statement'
                                                      : type == 'rse'
                                                          ? 'Self-Esteem Item'
                                                          : 'Decision Confidence Task',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.primaryPurple,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '#${_currentIndex + 1}',
                                            style: GoogleFonts.plusJakartaSans(
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
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          height: 1.4,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Choice Options Header
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                                  child: Text(
                                    'SELECT YOUR RESPONSE:',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF64748B),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),

                                // Options Cards Mapping - Horizontal & Grid for Mobile
                                if (type == 'riasec')
                                  _buildRiasecOptionsHorizontal(selectedScore, isDark)
                                else if (type == 'rse')
                                  _buildRseOptionsGrid(selectedScore, isDark)
                                else if (type == 'cdses')
                                  _buildCdsesOptionsGrid(selectedScore, isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer Navigation Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
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
                            foregroundColor: AppTheme.primaryPurple,
                            side: const BorderSide(color: AppTheme.primaryPurple, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _previous,
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: Text(
                            'Previous',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                          ),
                        )
                      else
                        const SizedBox(),
                      _isSubmitting
                          ? const CircularProgressIndicator()
                          : Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6A0DAD), Color(0xFF5B21B6)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6A0DAD).withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
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
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
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

  Widget _buildRiasecOptionsHorizontal(int? selectedScore, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildOptionTileCard(
            label: 'Agree',
            subtitle: 'I like/prefer this',
            value: 1,
            isSelected: selectedScore == 1,
            isDark: isDark,
            activeColor: AppTheme.primaryPurple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOptionTileCard(
            label: 'Disagree',
            subtitle: 'I do not prefer this',
            value: 0,
            isSelected: selectedScore == 0,
            isDark: isDark,
            activeColor: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _buildRseOptionsGrid(int? selectedScore, bool isDark) {
    final opts = [
      {'label': 'Strongly Agree', 'sub': 'Completely true', 'val': 1, 'color': const Color(0xFF059669)},
      {'label': 'Agree', 'sub': 'Mostly true', 'val': 2, 'color': const Color(0xFF0D9488)},
      {'label': 'Disagree', 'sub': 'Mostly untrue', 'val': 3, 'color': const Color(0xFFF97316)},
      {'label': 'Strongly Disagree', 'sub': 'Completely untrue', 'val': 4, 'color': const Color(0xFFEF4444)},
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOptionTileCard(
                label: opts[0]['label'] as String,
                subtitle: opts[0]['sub'] as String,
                value: opts[0]['val'] as int,
                isSelected: selectedScore == 1,
                isDark: isDark,
                activeColor: opts[0]['color'] as Color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOptionTileCard(
                label: opts[1]['label'] as String,
                subtitle: opts[1]['sub'] as String,
                value: opts[1]['val'] as int,
                isSelected: selectedScore == 2,
                isDark: isDark,
                activeColor: opts[1]['color'] as Color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildOptionTileCard(
                label: opts[2]['label'] as String,
                subtitle: opts[2]['sub'] as String,
                value: opts[2]['val'] as int,
                isSelected: selectedScore == 3,
                isDark: isDark,
                activeColor: opts[2]['color'] as Color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOptionTileCard(
                label: opts[3]['label'] as String,
                subtitle: opts[3]['sub'] as String,
                value: opts[3]['val'] as int,
                isSelected: selectedScore == 4,
                isDark: isDark,
                activeColor: opts[3]['color'] as Color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCdsesOptionsGrid(int? selectedScore, bool isDark) {
    final opts = [
      {'num': '1', 'label': 'No Confidence', 'val': 1, 'color': const Color(0xFFDC2626)},
      {'num': '2', 'label': 'Very Little', 'val': 2, 'color': const Color(0xFFEA580C)},
      {'num': '3', 'label': 'Moderate', 'val': 3, 'color': const Color(0xFF4F46E5)},
      {'num': '4', 'label': 'Much Confidence', 'val': 4, 'color': const Color(0xFF0D9488)},
      {'num': '5', 'label': 'Complete Confidence', 'val': 5, 'color': const Color(0xFF059669)},
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCdsesTile(opts[0], selectedScore == 1, isDark, opts[0]['color'] as Color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCdsesTile(opts[1], selectedScore == 2, isDark, opts[1]['color'] as Color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCdsesTile(opts[2], selectedScore == 3, isDark, opts[2]['color'] as Color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCdsesTile(opts[3], selectedScore == 4, isDark, opts[3]['color'] as Color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCdsesTile(opts[4], selectedScore == 5, isDark, opts[4]['color'] as Color),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCdsesTile(Map<String, dynamic> opt, bool isSelected, bool isDark, Color activeColor) {
    final val = opt['val'] as int;
    return InkWell(
      onTap: () => _selectScore(val),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              opt['num'] as String,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isSelected ? Colors.white : isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              opt['label'] as String,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: isSelected ? Colors.white.withOpacity(0.95) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTileCard({
    required String label,
    required String subtitle,
    required int value,
    required bool isSelected,
    required bool isDark,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: () => _selectScore(value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.12)
              : isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : isDark ? const Color(0xFF2E2E3E) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: activeColor.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isSelected ? activeColor : isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
                color: isSelected ? activeColor.withOpacity(0.85) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AssessmentBackgroundPainter extends CustomPainter {
  final bool isDark;

  AssessmentBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final wave1Path = Path();
    wave1Path.moveTo(0, size.height * 0.2);
    wave1Path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.05,
      size.width * 0.7, size.height * 0.22,
    );
    wave1Path.quadraticBezierTo(
      size.width * 0.88, size.height * 0.3,
      size.width, size.height * 0.15,
    );
    wave1Path.lineTo(size.width, 0);
    wave1Path.lineTo(0, 0);
    wave1Path.close();

    final wave1Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryPurple.withOpacity(isDark ? 0.12 : 0.09),
          AppTheme.primaryPurple.withOpacity(isDark ? 0.03 : 0.02),
        ],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(rect);

    canvas.drawPath(wave1Path, wave1Paint);

    final wave2Path = Path();
    wave2Path.moveTo(0, size.height * 0.75);
    wave2Path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.65,
      size.width * 0.7, size.height * 0.85,
    );
    wave2Path.quadraticBezierTo(
      size.width * 0.85, size.height * 0.95,
      size.width, size.height * 0.88,
    );
    wave2Path.lineTo(size.width, size.height);
    wave2Path.lineTo(0, size.height);
    wave2Path.close();

    final wave2Paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryPurple.withOpacity(isDark ? 0.18 : 0.12),
          AppTheme.primaryPurple.withOpacity(isDark ? 0.04 : 0.03),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(rect);

    canvas.drawPath(wave2Path, wave2Paint);
  }

  @override
  bool shouldRepaint(covariant AssessmentBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class FormDotGridPainter extends CustomPainter {
  final Color color;

  FormDotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const double radius = 2.5;
    const double spacing = 12.0;

    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 5; col++) {
        final offset = Offset(col * spacing, row * spacing);
        canvas.drawCircle(offset, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant FormDotGridPainter oldDelegate) => oldDelegate.color != color;
}