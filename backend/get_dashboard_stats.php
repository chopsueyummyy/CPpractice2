<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$filter = $_GET['filter'] ?? 'all'; 

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

$pending = $conn->query("
    SELECT COUNT(*) as count FROM assessments a WHERE a.Status = 'pending_review' AND $dateCondition
")->fetch_assoc()['count'];

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

// 4. Burnout risk levels distribution
$mbiStats = [];
$res = $conn->query("
    SELECT m.BurnoutStatus, COUNT(*) as count 
    FROM assessments a
    JOIN mbi_results m ON m.AssessmentID = a.AssessmentID
    WHERE a.Status = 'approved' AND $dateCondition
    GROUP BY m.BurnoutStatus
");
while ($row = $res->fetch_assoc()) {
    if ($row['BurnoutStatus']) {
        $mbiStats[] = [
            "status" => $row['BurnoutStatus'],
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

echo json_encode([
    "status"           => "success",
    "pendingCount"     => (int)$pending,
    "totalStudents"    => (int)$totalStudents,
    "assessmentsToday" => (int)$assessmentsToday,
    "feedbackGiven"    => (int)$feedbackGiven,
    "approvalRate"     => $approvalRate,
    "inProgress"       => (int)$conn->query("SELECT COUNT(*) as count FROM live_sessions ls JOIN assessments a ON a.AssessmentID = ls.AssessmentID WHERE ls.IsActive = TRUE AND a.Status = 'in_progress'")->fetch_assoc()['count'],
    "strandStats"      => $strandStats,
    "riasecStats"      => $riasecStats,
    "rseStats"         => $rseStats,
    "mbiStats"         => $mbiStats,
    "recentActivity"   => $recentActivity
]);

$conn->close();
?>
