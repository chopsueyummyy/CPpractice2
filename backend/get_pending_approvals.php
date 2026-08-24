<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
include 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$result = $conn->query("
    SELECT
        a.AssessmentID,
        a.SubmittedAt,
        a.Status,
        pi.FirstName,
        pi.LastName,
        pi.Strand,
        pi.GradeLevel,
        pi.Gender,
        s.StudentID,
        ar.PrimaryType,
        ar.SecondaryType,
        ar.TertiaryType,
        ar.R_Percentage,
        ar.I_Percentage,
        ar.A_Percentage,
        ar.S_Percentage,
        ar.E_Percentage,
        ar.C_Percentage,
        ar.ResultID
    FROM assessments a
    JOIN personal_information pi ON pi.PI_ID = a.PI_ID
    JOIN students s ON s.StudentID = a.StudentID
    LEFT JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
    WHERE a.Status = 'pending_review'
    ORDER BY a.SubmittedAt DESC
");

$pending = [];
while ($row = $result->fetch_assoc()) {
    $rec = $conn->prepare("
        SELECT rr.Rank, rr.MatchScore, rr.Explanation, rr.ShapWeights, rc.CourseName, rc.CourseCode, rc.RIASECCategory
        FROM riasec_recommendations rr
        JOIN riasec_courses rc ON rc.CourseID = rr.CourseID
        WHERE rr.ResultID = ?
        ORDER BY rr.Rank
    ");
    $rec->bind_param("i", $row['ResultID']);
    $rec->execute();
    $recResult = $rec->get_result();
    $recommendations = [];
    while ($r = $recResult->fetch_assoc()) {
        $r['shapWeights'] = !empty($r['ShapWeights']) ? json_decode($r['ShapWeights'], true) : null;
        unset($r['ShapWeights']);
        $recommendations[] = $r;
    }

    // Fetch RSE results
    $rse = $conn->prepare("SELECT Score, Level FROM rse_results WHERE AssessmentID = ?");
    $rse->bind_param("i", $row['AssessmentID']);
    $rse->execute();
    $rseRow = $rse->get_result()->fetch_assoc();

    // Fetch CDSES results
    $cdses = $conn->prepare("SELECT SA_Score, OI_Score, GS_Score, PL_Score, PS_Score, TotalScore, SelfEfficacyLevel FROM cdses_results WHERE AssessmentID = ?");
    $cdses->bind_param("i", $row['AssessmentID']);
    $cdses->execute();
    $cdsesRow = $cdses->get_result()->fetch_assoc();
    $cdses->close();

    $pending[] = [
        "assessmentId"  => $row['AssessmentID'],
        "studentId"     => $row['StudentID'],
        "studentName"   => $row['FirstName'] . ' ' . $row['LastName'],
        "strand"        => $row['Strand'],
        "gradeLevel"    => $row['GradeLevel'],
        "gender"        => $row['Gender'],
        "submittedAt"   => $row['SubmittedAt'],
        "status"        => $row['Status'],
        "primaryType"   => $row['PrimaryType'],
        "secondaryType" => $row['SecondaryType'],
        "tertiaryType"  => $row['TertiaryType'],
        "scores" => [
            "R" => $row['R_Percentage'],
            "I" => $row['I_Percentage'],
            "A" => $row['A_Percentage'],
            "S" => $row['S_Percentage'],
            "E" => $row['E_Percentage'],
            "C" => $row['C_Percentage'],
        ],
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
        ] : null
    ];
}

echo json_encode(["status" => "success", "pending" => $pending, "count" => count($pending)]);
$conn->close();
?>
