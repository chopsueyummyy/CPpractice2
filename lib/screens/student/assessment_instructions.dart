import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/riasec_models.dart';
import '../../services/api_service.dart';
import '../../services/session_manager.dart';
import '../../widgets/student_sidebar.dart';

class AssessmentInstructionsScreen extends StatelessWidget {
  final StudentDetails? studentDetails;

  const AssessmentInstructionsScreen({super.key, this.studentDetails});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: StudentSidebar(currentRoute: '/student/assessment'),
      appBar: AppBar(
        title: const Text('Assessment Instructions'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Return to Main Menu',
            onPressed: () => context.go('/student/dashboard'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              color: AppTheme.primaryPurple.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.quiz,
                      size: 48,
                      color: AppTheme.primaryPurple,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to RIASEC Assessment',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (studentDetails != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Hello, ${studentDetails!.fullName}!',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            Text(
              'How the Test Works',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildInstructionItem(
              context,
              icon: Icons.help_outline,
              title: 'Answer Honestly',
              description: 'There are no right or wrong answers. Please answer each question based on your genuine interests, preferences, and personality.',
            ),
            _buildInstructionItem(
              context,
              icon: Icons.timer,
              title: 'Take Your Time',
              description: 'You can take as much time as you need. Read each question carefully and select the answer that best describes you.',
            ),
            _buildInstructionItem(
              context,
              icon: Icons.arrow_forward,
              title: 'Navigate Questions',
              description: 'Use the Previous and Next buttons to navigate between questions. You can review and change your answers before submitting.',
            ),
            _buildInstructionItem(
              context,
              icon: Icons.check_circle,
              title: 'Complete All Questions',
              description: 'Make sure to answer all questions before submitting. You will see a progress bar indicating how many questions you have completed.',
            ),
            _buildInstructionItem(
              context,
              icon: Icons.assessment,
              title: 'Get Your Results',
              description: 'After submission, your assessment will be reviewed. You will receive your RIASEC results and course recommendations via email.',
            ),

            const SizedBox(height: 32),

            // Important Notes
            Card(
              color: const Color.fromARGB(255, 238, 137, 5).withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info,
                      color: const Color.fromARGB(255, 238, 137, 5),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Notes',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Your responses are confidential and will only be used for career guidance purposes.\n'
                            '• The assessment typically takes 15-20 minutes to complete.\n'
                            '• Make sure you are in a quiet environment where you can focus.\n'
                            '• You cannot pause the assessment once started, so ensure you have enough time.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDisclaimerDialog(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Assessment'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/student/dashboard'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return to Main Menu'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisclaimerDialog(BuildContext context) {
    final session = SessionManager();
    bool isChecked = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.primaryPurple, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Assessment Acknowledgment',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryPurple,
                        ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Before proceeding with the assessment, please read the following:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      _disclaimerBullet(
                        'This assessment is designed to assist you in identifying college courses that best match your interests and assessment results.',
                      ),
                      _disclaimerBullet(
                        'Please answer all questions honestly to obtain more accurate recommendations.',
                      ),
                      _disclaimerBullet(
                        'Your responses will be securely stored and used only within the CourseAlign system.',
                      ),
                      _disclaimerBullet(
                        'The generated recommendations are intended to support your decision-making and should not replace professional guidance.',
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'By clicking "I Agree", you acknowledge that you understand the purpose of this assessment and agree to proceed.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      
                      // Checkbox list tile
                      CheckboxListTile(
                        value: isChecked,
                        onChanged: isSubmitting
                            ? null
                            : (val) {
                                setDialogState(() {
                                  isChecked = val ?? false;
                                });
                              },
                        title: const Text(
                          'I have read and understood the information above.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryPurple,
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: (!isChecked || isSubmitting)
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          
                          try {
                            final data = await ApiService.startAssessment(
                              session.studentId!,
                              session.currentPiId!,
                              agreed: true,
                            );
                            
                            if (data['status'] == 'success' || data['status'] == 'resume') {
                              session.currentAssessmentId = int.tryParse(data['assessmentId'].toString());
                              
                              if (context.mounted) {
                                Navigator.pop(context); // Close dialog
                                context.go('/student/assessment', extra: studentDetails);
                              }
                            } else {
                              throw Exception(data['message'] ?? 'Failed to start assessment');
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('I Agree', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _disclaimerBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5.0),
            child: Icon(Icons.lens, size: 6, color: AppTheme.primaryPurple),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryPurple.withOpacity(0.1),
            child: Icon(
              icon,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
