<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';
require_once __DIR__ . '/services/CacheService.php';

$filter = $_GET['filter'] ?? 'all'; 

$response = CacheService::remember("dashboard_stats_" . $filter, 60, function() use ($conn, $filter) {
    $dateCondition = "1=1";
    switch ($filter) {
        case 'today':
            $dateCondition = "DATE(a.SubmittedAt) = CURDATE()";
            break;
        case 'week':
            $dateCondition = "a.SubmittedAt >= DATE_SUB(NOW(), INTERVAL 1 WEEK)";
            break;
        case 'month':
            $dateCondition = "a.SubmittedAt >= DATE_SUB(NOW(), INTERVAL 1 MONTH)";
            break;
    }

    $pendingPsychometrician = (int)$conn->query("
        SELECT COUNT(*) as count FROM assessments a WHERE a.Status IN ('pending_psychometrician', 'pending_review') AND $dateCondition
    ")->fetch_assoc()['count'];

    $pendingCounselor = (int)$conn->query("
        SELECT COUNT(*) as count FROM assessments a WHERE a.Status = 'pending_counselor' AND $dateCondition
    ")->fetch_assoc()['count'];

    $pending = $pendingPsychometrician;

    $totalStudents = $conn->query("SELECT COUNT(*) as count FROM students")->fetch_assoc()['count'];

    $assessmentsToday = $conn->query("
        SELECT COUNT(*) as count FROM assessments WHERE DATE(SubmittedAt) = CURDATE()
    ")->fetch_assoc()['count'];

    $feedbackGiven = $conn->query("
        SELECT COUNT(*) as count FROM counselor_feedback cf
        JOIN assessments a ON a.AssessmentID = cf.AssessmentID
        WHERE $dateCondition
    ")->fetch_assoc()['count'];

    $approved = $conn->query("
        SELECT COUNT(*) as count FROM assessments a WHERE a.Status = 'approved' AND $dateCondition
    ")->fetch_assoc()['count'];

    $total = $conn->query("
        SELECT COUNT(*) as count FROM assessments a WHERE a.Status != 'in_progress' AND $dateCondition
    ")->fetch_assoc()['count'];

    $approvalRate = $total > 0 ? round(($approved / $total) * 100, 1) : 0;

    // 1. Strand distribution
    $strandStats = [];
    $res = $conn->query("
        SELECT pi.Strand, COUNT(*) as count 
        FROM assessments a
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        WHERE a.Status = 'approved' AND $dateCondition
        GROUP BY pi.Strand
    ");
    while ($row = $res->fetch_assoc()) {
        $strandStats[] = [
            "strand" => $row['Strand'],
            "count" => (int)$row['count']
        ];
    }

    // 2. RIASEC dominant types distribution
    $riasecStats = [];
    $res = $conn->query("
        SELECT ar.PrimaryType, COUNT(*) as count 
        FROM assessments a
        JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
        WHERE a.Status = 'approved' AND $dateCondition
        GROUP BY ar.PrimaryType
    ");
    while ($row = $res->fetch_assoc()) {
        if ($row['PrimaryType']) {
            $riasecStats[] = [
                "type" => $row['PrimaryType'],
                "count" => (int)$row['count']
            ];
        }
    }

    // 3. Self-esteem levels distribution
    $rseStats = [];
    $res = $conn->query("
        SELECT r.Level, COUNT(*) as count 
        FROM assessments a
        JOIN rse_results r ON r.AssessmentID = a.AssessmentID
        WHERE a.Status = 'approved' AND $dateCondition
        GROUP BY r.Level
    ");
    while ($row = $res->fetch_assoc()) {
        if ($row['Level']) {
            $rseStats[] = [
                "level" => $row['Level'],
                "count" => (int)$row['count']
            ];
        }
    }

    // 4. Career Decision Self-Efficacy (CDSES) levels distribution
    $cdsesStats = [];
    $res = $conn->query("
        SELECT c.SelfEfficacyLevel, COUNT(*) as count 
        FROM assessments a
        JOIN cdses_results c ON c.AssessmentID = a.AssessmentID
        WHERE a.Status = 'approved' AND $dateCondition
        GROUP BY c.SelfEfficacyLevel
    ");
    while ($row = $res->fetch_assoc()) {
        if ($row['SelfEfficacyLevel']) {
            $cdsesStats[] = [
                "level" => $row['SelfEfficacyLevel'],
                "count" => (int)$row['count']
            ];
        }
    }

    // 5. Recent activity logs
    $recentActivity = [];
    $res = $conn->query("
        SELECT a.AssessmentID, a.SubmittedAt, a.Status, pi.FirstName, pi.LastName, pi.Strand 
        FROM assessments a
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        WHERE a.Status != 'in_progress'
        ORDER BY a.SubmittedAt DESC
        LIMIT 5
    ");
    while ($row = $res->fetch_assoc()) {
        $recentActivity[] = [
            "assessmentId" => (int)$row['AssessmentID'],
            "studentName"  => $row['FirstName'] . ' ' . $row['LastName'],
            "strand"       => $row['Strand'],
            "submittedAt"  => $row['SubmittedAt'],
            "status"       => $row['Status']
        ];
    }

    // 6. Cumulative Grade Level distribution (deduplicated per student with assessment records)
    $gradeStats = [];
    $res = $conn->query("
        SELECT 
            COALESCE(NULLIF(TRIM(pi.GradeLevel), ''), 'Unassigned') as GradeLevel,
            COUNT(*) as count
        FROM (
            SELECT a.StudentID, MAX(a.AssessmentID) as latest_assessment_id
            FROM assessments a
            WHERE a.Status != 'in_progress'
            GROUP BY a.StudentID
        ) latest
        JOIN assessments a ON a.AssessmentID = latest.latest_assessment_id
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        GROUP BY COALESCE(NULLIF(TRIM(pi.GradeLevel), ''), 'Unassigned')
        ORDER BY count DESC
    ");
    while ($row = $res->fetch_assoc()) {
        if ($row['GradeLevel']) {
            $gradeStats[] = [
                "gradeLevel" => $row['GradeLevel'],
                "count"      => (int)$row['count']
            ];
        }
    }

    // 7. Cumulative Gender distribution (deduplicated per student with assessment records)
    $genderStats = [];
    $res = $conn->query("
        SELECT 
            COALESCE(NULLIF(TRIM(pi.Gender), ''), 'Not Specified') as Gender,
            COUNT(*) as count
        FROM (
            SELECT a.StudentID, MAX(a.AssessmentID) as latest_assessment_id
            FROM assessments a
            WHERE a.Status != 'in_progress'
            GROUP BY a.StudentID
        ) latest
        JOIN assessments a ON a.AssessmentID = latest.latest_assessment_id
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        GROUP BY COALESCE(NULLIF(TRIM(pi.Gender), ''), 'Not Specified')
        ORDER BY count DESC
    ");
    while ($row = $res->fetch_assoc()) {
        if ($row['Gender']) {
            $genderStats[] = [
                "gender" => $row['Gender'],
                "count"  => (int)$row['count']
            ];
        }
    }

    // 8. Priority Endorsements awaiting Counselor advisory
    $priorityEndorsements = [];
    $res = $conn->query("
        SELECT a.AssessmentID, a.SubmittedAt, a.StudentID, pi.FirstName, pi.LastName, pi.Strand, pi.GradeLevel,
               cf.FeedbackNotes as PsychometricianNotes, cf.ReviewedAt as EndorsedAt
        FROM assessments a
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        LEFT JOIN counselor_feedback cf ON cf.AssessmentID = a.AssessmentID AND cf.ReviewerRole = 'psychometrician'
        WHERE a.Status = 'pending_counselor'
        ORDER BY a.SubmittedAt DESC
        LIMIT 5
    ");
    while ($row = $res->fetch_assoc()) {
        $priorityEndorsements[] = [
            "assessmentId"         => (int)$row['AssessmentID'],
            "studentId"            => $row['StudentID'],
            "studentName"          => $row['FirstName'] . ' ' . $row['LastName'],
            "strand"               => $row['Strand'],
            "gradeLevel"           => $row['GradeLevel'],
            "endorsedAt"           => $row['EndorsedAt'] ?? $row['SubmittedAt'],
            "psychometricianNotes" => $row['PsychometricianNotes'] ?? ''
        ];
    }

    // 9. Recent Released Advisories (Official Counseling releases)
    $recentReleased = [];
    $res = $conn->query("
        SELECT a.AssessmentID, a.SubmittedAt, a.StudentID, pi.FirstName, pi.LastName, pi.Strand, pi.GradeLevel,
               cf.FeedbackNotes as CounselorNotes, cf.ReviewedAt as ReleasedAt
        FROM assessments a
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        LEFT JOIN counselor_feedback cf ON cf.AssessmentID = a.AssessmentID AND cf.ReviewerRole = 'guidance_counselor'
        WHERE a.Status = 'approved'
        ORDER BY a.AssessmentID DESC
        LIMIT 5
    ");
    while ($row = $res->fetch_assoc()) {
        $recentReleased[] = [
            "assessmentId"   => (int)$row['AssessmentID'],
            "studentId"      => $row['StudentID'],
            "studentName"    => $row['FirstName'] . ' ' . $row['LastName'],
            "strand"         => $row['Strand'],
            "gradeLevel"     => $row['GradeLevel'],
            "releasedAt"     => $row['ReleasedAt'] ?? $row['SubmittedAt'],
            "counselorNotes" => $row['CounselorNotes'] ?? ''
        ];
    }

    $activeStrandsCount = count($strandStats);

    return [
        "status"                      => "success",
        "pendingCount"                => (int)$pending,
        "pendingPsychometricianCount" => (int)$pendingPsychometrician,
        "pendingCounselorCount"       => (int)$pendingCounselor,
        "pendingTotalCount"           => (int)($pendingPsychometrician + $pendingCounselor),
        "totalStudents"               => (int)$totalStudents,
        "approved"                    => (int)$approved,
        "assessmentsToday"            => (int)$assessmentsToday,
        "feedbackGiven"               => (int)$feedbackGiven,
        "approvalRate"                => $approvalRate,
        "inProgress"                  => (int)$conn->query("SELECT COUNT(*) as count FROM live_sessions ls JOIN assessments a ON a.AssessmentID = ls.AssessmentID WHERE ls.IsActive = TRUE AND a.Status = 'in_progress'")->fetch_assoc()['count'],
        "strandStats"                 => $strandStats,
        "gradeStats"                  => $gradeStats,
        "genderStats"                 => $genderStats,
        "priorityEndorsements"        => $priorityEndorsements,
        "recentReleased"              => $recentReleased,
        "activeStrandsCount"          => $activeStrandsCount,
        "riasecStats"                 => $riasecStats,
        "rseStats"                    => $rseStats,
        "cdsesStats"                  => $cdsesStats,
        "recentActivity"              => $recentActivity
    ];
});

echo json_encode($response);

$conn->close();
?>
