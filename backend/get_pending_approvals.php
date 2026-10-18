<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$role = strtolower($_GET['role'] ?? 'psychometrician');
if ($role === 'guidance_counselor' || $role === 'counselor') {
    $whereStatus = "a.Status = 'pending_counselor'";
} else {
    $whereStatus = "a.Status IN ('pending_psychometrician', 'pending_review')";
}

$result = $conn->query("
    SELECT
        a.AssessmentID,
        a.SubmittedAt,
        a.Status,
        GREATEST(0, IFNULL(TIMESTAMPDIFF(SECOND, a.StartedAt, a.SubmittedAt), 0)) AS DurationSeconds,
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
        ar.ResultID,
        ar.ClusterRecommendations,
        ar.GeneralInsights
    FROM assessments a
    JOIN personal_information pi ON pi.PI_ID = a.PI_ID
    JOIN students s ON s.StudentID = a.StudentID
    LEFT JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
    WHERE $whereStatus
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

    // Fetch psychometrician diagnostic briefing note (if available)
    $pm = $conn->prepare("
        SELECT cf.FeedbackNotes, cf.ReviewedAt, cf.AiRating, c.FirstName, c.LastName
        FROM counselor_feedback cf
        LEFT JOIN counselors c ON c.CounselorID = cf.CounselorID
        WHERE cf.AssessmentID = ? AND cf.ReviewerRole = 'psychometrician'
        ORDER BY cf.FeedbackID DESC LIMIT 1
    ");
    $pm->bind_param("i", $row['AssessmentID']);
    $pm->execute();
    $pmRow = $pm->get_result()->fetch_assoc();
    $pm->close();

    // Read pre-computed XGBoost + SHAP cluster recommendations from MySQL cache
    $clusterRecommendations = !empty($row['ClusterRecommendations']) ? json_decode($row['ClusterRecommendations'], true) : null;

    $pending[] = [
        "assessmentId"  => $row['AssessmentID'],
        "studentId"     => $row['StudentID'],
        "studentName"   => $row['FirstName'] . ' ' . $row['LastName'],
        "strand"        => $row['Strand'],
        "gradeLevel"    => $row['GradeLevel'],
        "gender"        => $row['Gender'],
        "submittedAt"   => $row['SubmittedAt'],
        "durationSeconds" => (int)($row['DurationSeconds'] ?? 0),
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
        "clusterRecommendations" => $clusterRecommendations,
        "generalInsights" => !empty($row['GeneralInsights']) ? json_decode($row['GeneralInsights'], true) : null,
        "psychometricianNote" => $pmRow ? [
            "notes"        => $pmRow['FeedbackNotes'],
            "reviewedAt"   => $pmRow['ReviewedAt'],
            "aiRating"     => $pmRow['AiRating'] !== null ? (int)$pmRow['AiRating'] : null,
            "endorserName" => $pmRow['FirstName'] ? ($pmRow['FirstName'] . ' ' . $pmRow['LastName']) : 'Registered Psychometrician'
        ] : null,
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
