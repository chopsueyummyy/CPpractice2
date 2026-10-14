import 'package:flutter/material.dart';

class JmcfiBadge extends StatelessWidget {
  const JmcfiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF064E3B).withOpacity(0.35) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFA7F3D0),
          width: 0.8,
        ),
      ),
      child: Text(
        'Available at JMCFI',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  /// Utility to check whether a course is offered at JMCFI
  static bool isJmcfiCourse(String courseName) {
    return courseName.toUpperCase().contains('JMCFI');
  }

  /// Utility to clean raw (JMCFI) tag from the course title
  static String cleanCourseTitle(String courseName) {
    return courseName
        .replaceAll(RegExp(r'\s*\(JMCFI\)', caseSensitive: false), '')
        .trim();
  }
}
