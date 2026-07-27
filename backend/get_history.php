<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

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

    $mbi = $conn->prepare("SELECT EX_Score, CY_Score, EF_Score, EX_Level, CY_Level, EF_Level, BurnoutStatus FROM mbi_results WHERE AssessmentID = ?");
    $mbi->bind_param("i", $row['AssessmentID']);
    $mbi->execute();
    $mbiRow = $mbi->get_result()->fetch_assoc();

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
        "mbi" => $mbiRow ? [
            "exScore" => (float)$mbiRow['EX_Score'],
            "cyScore" => (float)$mbiRow['CY_Score'],
            "efScore" => (float)$mbiRow['EF_Score'],
            "exLevel" => $mbiRow['EX_Level'],
            "cyLevel" => $mbiRow['CY_Level'],
            "efLevel" => $mbiRow['EF_Level'],
            "burnoutStatus" => $mbiRow['BurnoutStatus']
        ] : null
    ];
}

echo json_encode(["status" => "success", "history" => $history, "total" => count($history)]);
$conn->close();
?>
