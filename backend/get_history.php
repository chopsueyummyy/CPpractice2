<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$studentId = $_GET['studentId'] ?? '';
if (empty($studentId)) {
    echo json_encode(["status" => "error", "message" => "Missing studentId"]);
    exit();
}

$stmt = $conn->prepare("
    SELECT a.AssessmentID, a.Status, a.SubmittedAt,
           ar.PrimaryType, ar.SecondaryType, ar.TertiaryType,
           ar.ResultID
    FROM assessments a
    LEFT JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
    WHERE a.StudentID = ?
      AND a.Status IN ('approved', 'rejected')
    ORDER BY a.SubmittedAt DESC
");
$stmt->bind_param("s", $studentId);
$stmt->execute();
$result = $stmt->get_result();

$history = [];
$count = 1;
while ($row = $result->fetch_assoc()) {
    $courses = [];
    if ($row['ResultID']) {
        $rec = $conn->prepare("
            SELECT rc.CourseName FROM riasec_recommendations rr
            JOIN riasec_courses rc ON rc.CourseID = rr.CourseID
            WHERE rr.ResultID = ? ORDER BY rr.Rank LIMIT 3
        ");
        $rec->bind_param("i", $row['ResultID']);
        $rec->execute();
        $recResult = $rec->get_result();
        while ($r = $recResult->fetch_assoc()) {
            $courses[] = $r['CourseName'];
        }
    }

    $rse = $conn->prepare("SELECT Score, Level FROM rse_results WHERE AssessmentID = ?");
    $rse->bind_param("i", $row['AssessmentID']);
    $rse->execute();
    $rseRow = $rse->get_result()->fetch_assoc();

    $cdses = $conn->prepare("SELECT SA_Score, OI_Score, GS_Score, PL_Score, PS_Score, TotalScore, SelfEfficacyLevel FROM cdses_results WHERE AssessmentID = ?");
    $cdses->bind_param("i", $row['AssessmentID']);
    $cdses->execute();
    $cdsesRow = $cdses->get_result()->fetch_assoc();

    $history[] = [
        "assessmentId"  => (int)$row['AssessmentID'],
        "assessmentNum" => $count++,
        "status"        => $row['Status'],
        "submittedAt"   => $row['SubmittedAt'],
        "primaryType"   => $row['PrimaryType'],
        "secondaryType" => $row['SecondaryType'],
        "tertiaryType"  => $row['TertiaryType'],
        "courses"       => $courses,
        "rse" => $rseRow ? [
            "score" => (int)$rseRow['Score'],
            "level" => $rseRow['Level']
        ] : null,
        "cdses" => $cdsesRow ? [
            "saScore" => (float)$cdsesRow['SA_Score'],
            "oiScore" => (float)$cdsesRow['OI_Score'],
            "gsScore" => (float)$cdsesRow['GS_Score'],
            "plScore" => (float)$cdsesRow['PL_Score'],
            "psScore" => (float)$cdsesRow['PS_Score'],
            "totalScore" => (float)$cdsesRow['TotalScore'],
            "selfEfficacyLevel" => $cdsesRow['SelfEfficacyLevel']
        ] : null
    ];
}

echo json_encode(["status" => "success", "history" => $history, "total" => count($history)]);
$conn->close();
?>
