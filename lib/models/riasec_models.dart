// RIASEC Models for the application

enum RIASECType {
  realistic('R', 'Realistic', 'Doers'),
  investigative('I', 'Investigative', 'Thinkers'),
  artistic('A', 'Artistic', 'Creators'),
  social('S', 'Social', 'Helpers'),
  enterprising('E', 'Enterprising', 'Persuaders'),
  conventional('C', 'Conventional', 'Organizers');

  const RIASECType(this.code, this.name, this.description);
  final String code;
  final String name;
  final String description;
}

class RIASECScore {
  final RIASECType type;
  final int score;
  final double percentage;

  RIASECScore({
    required this.type,
    required this.score,
    required this.percentage,
  });
}

class AssessmentQuestion {
  final String id;
  final String question;
  final RIASECType category;
  final List<String> options;

  AssessmentQuestion({
    required this.id,
    required this.question,
    required this.category,
    required this.options,
  });
}

class AssessmentResult {
  final String id;
  final String studentId;
  final DateTime completedAt;
  final List<RIASECScore> scores;
  final RIASECType primaryType;
  final RIASECType secondaryType;
  final List<String> recommendedCourses;
  final String? status; // 'pending', 'approved', 'rejected'

  AssessmentResult({
    required this.id,
    required this.studentId,
    required this.completedAt,
    required this.scores,
    required this.primaryType,
    required this.secondaryType,
    required this.recommendedCourses,
    this.status,
  });
}

class Student {
  final String id;
  final String name;
  final String email;
  final String studentNumber;
  final String? course;
  final int? yearLevel;

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.studentNumber,
    this.course,
    this.yearLevel,
  });
}

class StudentDetails {
  final String firstName;
  final String lastName;
  final String? middleName;
  final String? suffixes;
  final int age;
  final DateTime birthdate;
  final String gender;
  final String strand;
  final String gradeLevel;

  StudentDetails({
    required this.firstName,
    required this.lastName,
    this.middleName,
    this.suffixes,
    required this.age,
    required this.birthdate,
    required this.gender,
    required this.strand,
    required this.gradeLevel,
  });

  // Getter for full name
  String get fullName {
    final parts = [firstName];
    if (middleName != null && middleName!.isNotEmpty) {
      parts.add(middleName!);
    }
    parts.add(lastName);
    if (suffixes != null && suffixes!.isNotEmpty) {
      parts.add(suffixes!);
    }
    return parts.join(' ');
  }
}

class CourseRecommendation {
  final String id;
  final String courseName;
  final String courseCode;
  final String description;
  final List<RIASECType> matchingTypes;
  final double matchScore;

  CourseRecommendation({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.description,
    required this.matchingTypes,
    required this.matchScore,
  });
}

class FeedbackData {
  final String id;
  final String assessmentId;
  final String counselorId;
  final String action; // 'approved', 'rejected', 'modified'
  final int? rating; // 1-5 stars
  final String? comment;
  final List<String>? correctedCourses;
  final DateTime feedbackDate;

  FeedbackData({
    required this.id,
    required this.assessmentId,
    required this.counselorId,
    required this.action,
    this.rating,
    this.comment,
    this.correctedCourses,
    required this.feedbackDate,
  });
}

class PendingApproval {
  final AssessmentResult assessment;
  final Student student;
  final List<CourseRecommendation> recommendations;
  final DateTime submittedAt;

  PendingApproval({
    required this.assessment,
    required this.student,
    required this.recommendations,
    required this.submittedAt,
  });
}

// Archived Student Record - combines StudentDetails and AssessmentResult
class ArchivedStudentRecord {
  final String id;
  final StudentDetails studentDetails;
  final AssessmentResult assessmentResult;
  final List<CourseRecommendation> recommendedCourses;
  final DateTime archivedAt;

  ArchivedStudentRecord({
    required this.id,
    required this.studentDetails,
    required this.assessmentResult,
    required this.recommendedCourses,
    required this.archivedAt,
  });
}
