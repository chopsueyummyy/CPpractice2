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
        SELECT ar.*, a.Status, a.AssessmentID as AID, pi.Strand FROM assessment_results ar
        JOIN assessments a ON a.AssessmentID = ar.AssessmentID
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
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
        SELECT ar.*, a.Status, pi.Strand FROM assessment_results ar
        JOIN assessments a ON a.AssessmentID = ar.AssessmentID
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
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
    SELECT rr.Rank, rr.MatchScore, rr.Explanation, rr.ShapWeights, rc.CourseName, rc.CourseCode, rc.RIASECCategory
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
    $row['shapWeights'] = !empty($row['ShapWeights']) ? json_decode($row['ShapWeights'], true) : null;
    unset($row['ShapWeights']);
    $recommendations[] = $row;
}

// Fetch RSE results for this assessment
$rse = $conn->prepare("SELECT Score, Level FROM rse_results WHERE AssessmentID = ?");
$rse->bind_param("i", $result['AssessmentID']);
$rse->execute();
$rseRow = $rse->get_result()->fetch_assoc();

// Fetch CDSES results for this assessment
$cdses = $conn->prepare("SELECT SA_Score, OI_Score, GS_Score, PL_Score, PS_Score, TotalScore, SelfEfficacyLevel FROM cdses_results WHERE AssessmentID = ?");
$cdses->bind_param("i", $result['AssessmentID']);
$cdses->execute();
$cdsesRow = $cdses->get_result()->fetch_assoc();
$cdses->close();

// Fetch counselor feedback/notes for this assessment
$cf = $conn->prepare("SELECT FeedbackNotes FROM counselor_feedback WHERE AssessmentID = ? ORDER BY ReviewedAt DESC LIMIT 1");
$cf->bind_param("i", $result['AssessmentID']);
$cf->execute();
$cfRow = $cf->get_result()->fetch_assoc();
$cfNotes = $cfRow['FeedbackNotes'] ?? null;
$cf->close();

echo json_encode([
    "status"           => "success",
    "assessmentStatus" => $result['Status'],
    "assessmentId"     => (int)$result['AssessmentID'],
    "strand"           => $result['Strand'] ?? null,
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
    "cdses" => $cdsesRow ? [
        "saScore" => (float)$cdsesRow['SA_Score'],
        "oiScore" => (float)$cdsesRow['OI_Score'],
        "gsScore" => (float)$cdsesRow['GS_Score'],
        "plScore" => (float)$cdsesRow['PL_Score'],
        "psScore" => (float)$cdsesRow['PS_Score'],
        "totalScore" => (float)$cdsesRow['TotalScore'],
        "selfEfficacyLevel" => $cdsesRow['SelfEfficacyLevel']
    ] : null,
    "counselorNotes" => $cfNotes
]);

$conn->close();
?>
