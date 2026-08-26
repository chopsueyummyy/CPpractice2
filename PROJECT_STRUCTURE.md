# RIASEC Assessment System - Project Structure

## Overview
This is a Flutter Web Application for Phase 1 Frontend Proposal demonstrating the RIASEC Career Assessment System.

## Project Structure

```
lib/
├── main.dart                          # Application entry point
├── models/
│   └── riasec_models.dart            # Data models (RIASEC types, Assessment, Student, etc.)
├── screens/
│   ├── shared/
│   │   └── login_screen.dart         # Login screen for both Student and Guidance Counselor
│   ├── student/
│   │   ├── student_dashboard.dart    # Student main dashboard
│   │   ├── assessment_screen.dart    # RIASEC Q&A Assessment
│   │   ├── results_screen.dart       # Assessment results with email notification status
│   │   └── history_screen.dart       # Assessment and recommendation history
│   └── guidance_counselor/
│       ├── counselor_dashboard.dart          # Guidance Counselor main dashboard
│       ├── monitoring_screen.dart             # Student Assessment Monitoring
│       ├── pending_approvals_screen.dart      # Pending Course Recommendation Approval
│       ├── student_records_screen.dart        # Student Records and Management
│       └── ai_feedback_screen.dart           # AI Supervised Feedback Learning
├── widgets/                           # Reusable UI components (To be added)
├── services/                          # Business logic and API services (To be added)
├── utils/
│   └── app_router.dart               # Application routing configuration
└── theme/
    └── app_theme.dart                 # Application theme and color scheme
```

## Student Module Features

### ✅ Completed Features:

1. **Login Screen** (`login_screen.dart`)
   - User type selection (Student/Counselor)
   - Email and password authentication
   - Demo mode (accepts any credentials)

2. **Student Dashboard** (`student_dashboard.dart`)
   - Welcome section with user info
   - Quick action cards:
     - Take Assessment
     - View Results
     - History
     - Notifications
   - Recent activity display

3. **RIASEC Q&A Assessment** (`assessment_screen.dart`)
   - Progress tracking
   - Question-by-question navigation
   - Multiple choice answers (5-point scale)
   - Category badges for each question
   - Previous/Next navigation
   - Submit functionality

4. **Assessment Results** (`results_screen.dart`)
   - Results summary with primary and secondary RIASEC types
   - Detailed score breakdown for all 6 RIASEC types
   - Visual progress bars for each type
   - Recommended courses list
   - Email notification status indicator
   - Share functionality
   - Options to view history or retake assessment

5. **Assessment History** (`history_screen.dart`)
   - Overview statistics (Total Assessments, Approved count)
   - List of all past assessments
   - Status indicators (Pending/Approved/Rejected)
   - Assessment details modal
   - Date and time information
   - Recommended courses for each assessment

## Dependencies

- `go_router: ^14.0.0` - Navigation and routing
- `provider: ^6.1.1` - State management (ready for future use)
- `intl: ^0.19.0` - Date and time formatting
- `flutter_svg: ^2.0.9` - SVG support (ready for future use)

## Running the Application

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run on web:
   ```bash
   flutter run -d chrome
   ```

3. Or run on specific web browser:
   ```bash
   flutter run -d edge
   ```

## Guidance Counselor Module Features

### ✅ Completed Features:

1. **Guidance Counselor Dashboard** (`counselor_dashboard.dart`)
   - Welcome section with counselor info
   - Statistics cards (Pending Approvals, Total Students, Assessments Today, AI Feedback Given)
   - Quick action cards for all major functions
   - Recent activity feed

2. **Student Assessment Monitoring** (`monitoring_screen.dart`)
   - Search and filter functionality
   - Statistics summary (Total, Pending, Approved, Rejected)
   - List of all student assessments with status indicators
   - Assessment details modal
   - Quick navigation to approval screen

3. **Pending Course Recommendation Approval** (`pending_approvals_screen.dart`)
   - Expandable list of pending approvals
   - **RIASEC Assessment Overview** with:
     - Primary and secondary type display
     - Complete RIASEC score breakdown with visual progress bars
     - All 6 RIASEC types with percentages
   - AI recommended courses with match scores
   - Action buttons: Approve, Reject, Modify & Provide Feedback
   - Integration with AI Feedback Learning system

4. **Student Records and Management** (`student_records_screen.dart`)
   - Search functionality (by name, ID, email)
   - Filter by status (All, Has Assessment, Pending, No Course)
   - Statistics summary
   - Student list with course status indicators
   - Student details modal
   - CRUD operations (View, Edit, Delete)
   - Add new student functionality

5. **AI Supervised Feedback Learning** (`ai_feedback_screen.dart`)
   - **Human-in-the-Loop interface** for counselors to provide feedback
   - Action selection (Approved, Rejected, Modified)
   - 5-star rating system for AI recommendation quality
   - Detailed feedback text input
   - Course modification interface (for modified recommendations)
   - Visual feedback on how feedback helps improve AI
   - Submission to AI learning system
   - Integration with approval workflow

## Next Steps

### Course Recommendation Service (Backend):
- Data Learning via Feedback Learning
- Centralized Data Management
- RIASEC Model Implementation

## Notes

- All screens are currently using mock/demo data
- Email notification is simulated (shows status but doesn't actually send emails)
- Assessment questions are sample questions (full question set to be added)
- Results calculation is simulated (actual RIASEC scoring algorithm to be implemented)
- AI Feedback Learning interface is fully functional for demonstration purposes
- Feedback submission is simulated (actual AI model training integration to be implemented in backend)

## AI Supervised Feedback Learning - How It Works

The Guidance Counselor can interact with the AI learning system through the **AI Feedback Screen**:

1. **After Approving/Rejecting/Modifying** a course recommendation, counselors are prompted to provide feedback
2. **Rating System**: 1-5 stars to rate the quality of AI recommendations
3. **Text Feedback**: Detailed comments explaining their decision
4. **Course Corrections**: For modified recommendations, counselors can specify the correct courses
5. **Learning Impact**: The system shows how feedback helps improve future recommendations
6. **Data Collection**: All feedback is collected and can be used to train/improve the AI model

This implements a **Human-in-the-Loop** machine learning approach where expert human feedback continuously improves the AI's recommendations.
