<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$assessmentId = $_GET['assessmentId'] ?? '';
$studentId    = $_GET['studentId'] ?? '';

if (!empty($assessmentId)) {
    $stmt = $conn->prepare("
        SELECT ar.*, a.Status, a.AssessmentID as AID FROM assessment_results ar
        JOIN assessments a ON a.AssessmentID = ar.AssessmentID
        WHERE ar.AssessmentID = ?
    ");
    $stmt->bind_param("i", $assessmentId);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
} elseif (!empty($studentId)) {
    $aStmt = $conn->prepare("
        SELECT AssessmentID, Status FROM assessments
        WHERE StudentID = ?
        ORDER BY AssessmentID DESC LIMIT 1
    ");
    $aStmt->bind_param("s", $studentId);
    $aStmt->execute();
    $aRow = $aStmt->get_result()->fetch_assoc();

    if (!$aRow) {
        echo json_encode(["status" => "error", "message" => "No assessment found"]);
        exit();
    }

    if ($aRow['Status'] === 'pending_review') {
        echo json_encode([
            "status"           => "success",
            "assessmentStatus" => "pending_review",
            "assessmentId"     => (int)$aRow['AssessmentID']
        ]);
        exit();
    }

    $stmt = $conn->prepare("
        SELECT ar.*, a.Status FROM assessment_results ar
        JOIN assessments a ON a.AssessmentID = ar.AssessmentID
        WHERE ar.AssessmentID = ?
    ");
    $stmt->bind_param("i", $aRow['AssessmentID']);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
} else {
    echo json_encode(["status" => "error", "message" => "Missing assessmentId or studentId"]);
    exit();
}

if (!$result) {
    echo json_encode(["status" => "error", "message" => "Results not found"]);
    exit();
}

if ($result['Status'] === 'pending_review') {
    echo json_encode([
        "status"           => "success",
        "assessmentStatus" => "pending_review",
        "assessmentId"     => (int)$result['AssessmentID']
    ]);
    exit();
}

$rec = $conn->prepare("
    SELECT rr.Rank, rr.MatchScore, rr.Explanation, rc.CourseName, rc.CourseCode, rc.RIASECCategory
    FROM riasec_recommendations rr
    JOIN riasec_courses rc ON rc.CourseID = rr.CourseID
    WHERE rr.ResultID = ?
    ORDER BY rr.Rank
");
$rec->bind_param("i", $result['ResultID']);
$rec->execute();
$recResult = $rec->get_result();
$recommendations = [];
while ($row = $recResult->fetch_assoc()) {
    $recommendations[] = $row;
}

// Fetch RSE results for this assessment
$rse = $conn->prepare("SELECT Score, Level FROM rse_results WHERE AssessmentID = ?");
$rse->bind_param("i", $result['AssessmentID']);
$rse->execute();
$rseRow = $rse->get_result()->fetch_assoc();

// Fetch MBI results for this assessment
$mbi = $conn->prepare("SELECT EX_Score, CY_Score, EF_Score, EX_Level, CY_Level, EF_Level, BurnoutStatus FROM mbi_results WHERE AssessmentID = ?");
$mbi->bind_param("i", $result['AssessmentID']);
$mbi->execute();
$mbiRow = $mbi->get_result()->fetch_assoc();

echo json_encode([
    "status"           => "success",
    "assessmentStatus" => $result['Status'],
    "assessmentId"     => (int)$result['AssessmentID'],
    "scores" => [
        "R" => ["score" => $result['R_Score'], "percentage" => $result['R_Percentage']],
        "I" => ["score" => $result['I_Score'], "percentage" => $result['I_Percentage']],
        "A" => ["score" => $result['A_Score'], "percentage" => $result['A_Percentage']],
        "S" => ["score" => $result['S_Score'], "percentage" => $result['S_Percentage']],
        "E" => ["score" => $result['E_Score'], "percentage" => $result['E_Percentage']],
        "C" => ["score" => $result['C_Score'], "percentage" => $result['C_Percentage']],
    ],
    "primaryType"     => $result['PrimaryType'],
    "secondaryType"   => $result['SecondaryType'],
    "tertiaryType"    => $result['TertiaryType'],
    "recommendations" => $recommendations,
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
]);

$conn->close();
?>
