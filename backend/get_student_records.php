<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$status       = $_GET['status']       ?? 'all'; 
$gradeLevel   = $_GET['gradeLevel']   ?? 'all';
$strand       = $_GET['strand']       ?? 'all';
$dominantType = $_GET['dominantType'] ?? 'all'; 
$rseLevel     = $_GET['rseLevel']     ?? 'all';
$cdsesLevel   = $_GET['cdsesLevel']   ?? 'all';
$dateFrom     = $_GET['dateFrom']     ?? '';
$dateTo       = $_GET['dateTo']       ?? '';
$search       = $_GET['search']       ?? '';

$where = ["1=1"];
$params = [];
$types  = "";

if ($status !== 'all') {
    if ($status === 'declined' || $status === 'rejected') {
        $where[] = "(a.Status = 'declined' OR a.Status = 'rejected')";
    } else {
        $where[] = "a.Status = ?";
        $params[] = $status;
        $types   .= "s";
    }
}
if ($gradeLevel !== 'all') {
    $where[] = "pi.GradeLevel = ?";
    $params[] = $gradeLevel;
    $types   .= "s";
}
if ($strand !== 'all') {
    $where[] = "pi.Strand LIKE ?";
    $params[] = "%$strand%";
    $types   .= "s";
}
if ($dominantType !== 'all') {
    $where[] = "ar.PrimaryType = ?";
    $params[] = $dominantType;
    $types   .= "s";
}
if ($rseLevel !== 'all') {
    $where[] = "rse.Level = ?";
    $params[] = $rseLevel;
    $types   .= "s";
}
if ($cdsesLevel !== 'all') {
    $where[] = "cdses.SelfEfficacyLevel = ?";
    $params[] = $cdsesLevel;
    $types   .= "s";
}
if (!empty($dateFrom)) {
    $where[] = "DATE(a.SubmittedAt) >= ?";
    $params[] = $dateFrom;
    $types   .= "s";
}
if (!empty($dateTo)) {
    $where[] = "DATE(a.SubmittedAt) <= ?";
    $params[] = $dateTo;
    $types   .= "s";
}
if (!empty($search)) {
    $where[] = "(CONCAT(IFNULL(pi.FirstName,''), ' ', IFNULL(pi.MiddleName,''), ' ', IFNULL(pi.LastName,'')) LIKE ? OR s.StudentID LIKE ?)";
    $params[] = "%$search%";
    $params[] = "%$search%";
    $types   .= "ss";
}

$whereClause = implode(" AND ", $where);

$hasGeneralInsights = false;
$colCheck = $conn->query("SHOW COLUMNS FROM `assessment_results` LIKE 'GeneralInsights'");
if ($colCheck && $colCheck->num_rows > 0) {
    $hasGeneralInsights = true;
}
$giSelect = $hasGeneralInsights ? "ar.GeneralInsights" : "NULL AS GeneralInsights";

try {
    $query = "
        SELECT
            a.AssessmentID,
            a.Status,
            a.SubmittedAt,
            a.StartedAt,
            GREATEST(0, IFNULL(TIMESTAMPDIFF(SECOND, a.StartedAt, a.SubmittedAt), 0)) AS DurationSeconds,
            pi.FirstName,
            pi.LastName,
            pi.MiddleName,
            pi.Strand,
            pi.GradeLevel,
            pi.Gender,
            pi.Age,
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
            $giSelect,
            cf_counselor.Action AS CounselorAction,
            cf_counselor.FeedbackNotes AS CounselorNotes,
            cf_counselor.ReviewedAt AS CounselorReviewedAt,
            cf_pm.FeedbackNotes AS PsychometricianNotes,
            cf_pm.AiRating AS PsychometricianAiRating,
            cf_pm.ReviewedAt AS PsychometricianReviewedAt
        FROM assessments a
        JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        JOIN students s ON s.StudentID = a.StudentID
        LEFT JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
        LEFT JOIN counselor_feedback cf_counselor ON cf_counselor.AssessmentID = a.AssessmentID AND cf_counselor.ReviewerRole = 'guidance_counselor'
        LEFT JOIN counselor_feedback cf_pm ON cf_pm.AssessmentID = a.AssessmentID AND cf_pm.ReviewerRole = 'psychometrician'
        LEFT JOIN rse_results rse ON rse.AssessmentID = a.AssessmentID
        LEFT JOIN cdses_results cdses ON cdses.AssessmentID = a.AssessmentID
        WHERE $whereClause
        ORDER BY a.SubmittedAt DESC
    ";

    if (!empty($params)) {
        $stmt = $conn->prepare($query);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $result = $stmt->get_result();
    } else {
        $result = $conn->query($query);
    }

$records = [];
while ($row = $result->fetch_assoc()) {
    $recommendations = [];
    if (!empty($row['ResultID'])) {
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
        while ($r = $recResult->fetch_assoc()) {
            $r['shapWeights'] = !empty($r['ShapWeights']) ? json_decode($r['ShapWeights'], true) : null;
            unset($r['ShapWeights']);
            $recommendations[] = $r;
        }
        $rec->close();
    }

    $rse = $conn->prepare("SELECT Score, Level FROM rse_results WHERE AssessmentID = ?");
    $rse->bind_param("i", $row['AssessmentID']);
    $rse->execute();
    $rseRow = $rse->get_result()->fetch_assoc();
    $rse->close();

    $cdses = $conn->prepare("SELECT SA_Score, OI_Score, GS_Score, PL_Score, PS_Score, TotalScore, SelfEfficacyLevel FROM cdses_results WHERE AssessmentID = ?");
    $cdses->bind_param("i", $row['AssessmentID']);
    $cdses->execute();
    $cdsesRow = $cdses->get_result()->fetch_assoc();
    $cdses->close();

    // Read pre-computed XGBoost + SHAP cluster recommendations from MySQL cache
    $clusterRecommendations = !empty($row['ClusterRecommendations']) ? json_decode($row['ClusterRecommendations'], true) : null;

    $records[] = [
        "assessmentId"   => $row['AssessmentID'],
        "studentId"      => $row['StudentID'],
        "studentName"    => trim($row['FirstName'] . ' ' . ($row['MiddleName'] ? $row['MiddleName'] . ' ' : '') . $row['LastName']),
        "strand"         => $row['Strand'],
        "gradeLevel"     => $row['GradeLevel'],
        "gender"         => $row['Gender'],
        "age"            => $row['Age'],
        "status"         => $row['Status'],
        "submittedAt"    => $row['SubmittedAt'],
        "durationSeconds" => (int)($row['DurationSeconds'] ?? 0),
        "primaryType"    => $row['PrimaryType'],
        "secondaryType"  => $row['SecondaryType'],
        "tertiaryType"   => $row['TertiaryType'],
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
        "counselorAction" => $row['CounselorAction'],
        "feedbackNotes"   => $row['CounselorNotes'] ?? null,
        "counselorNotes"  => $row['CounselorNotes'],
        "reviewedAt"      => $row['CounselorReviewedAt'],
        "psychometricianNotes" => $row['PsychometricianNotes'],
        "psychometricianAiRating" => $row['PsychometricianAiRating'] !== null ? (int)$row['PsychometricianAiRating'] : null,
        "psychometricianReviewedAt" => $row['PsychometricianReviewedAt']
    ];
}

    echo json_encode([
        "status"  => "success",
        "records" => $records,
        "total"   => count($records)
    ]);
} catch (Throwable $e) {
    echo json_encode([
        "status"  => "error",
        "message" => $e->getMessage(),
        "records" => [],
        "total"   => 0
    ]);
}

$conn->close();
?>
