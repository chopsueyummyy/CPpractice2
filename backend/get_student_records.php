<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$status       = $_GET['status']       ?? 'all'; 
$gradeLevel   = $_GET['gradeLevel']   ?? 'all';
$strand       = $_GET['strand']       ?? 'all';
$dominantType = $_GET['dominantType'] ?? 'all'; 
$rseLevel     = $_GET['rseLevel']     ?? 'all';
$mbiStatus    = $_GET['mbiStatus']    ?? 'all';
$dateFrom     = $_GET['dateFrom']     ?? '';
$dateTo       = $_GET['dateTo']       ?? '';
$search       = $_GET['search']       ?? '';

$where = ["1=1"];
$params = [];
$types  = "";

if ($status !== 'all') {
    $where[] = "a.Status = ?";
    $params[] = $status;
    $types   .= "s";
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
if ($mbiStatus !== 'all') {
    $where[] = "mbi.BurnoutStatus = ?";
    $params[] = $mbiStatus;
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
    $where[] = "(pi.FirstName LIKE ? OR pi.LastName LIKE ? OR s.StudentID LIKE ?)";
    $params[] = "%$search%";
    $params[] = "%$search%";
    $params[] = "%$search%";
    $types   .= "sss";
}

$whereClause = implode(" AND ", $where);

$query = "
    SELECT
        a.AssessmentID,
        a.Status,
        a.SubmittedAt,
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
        cf.Action AS CounselorAction,
        cf.FeedbackNotes,
        cf.ReviewedAt
    FROM assessments a
    JOIN personal_information pi ON pi.PI_ID = a.PI_ID
    JOIN students s ON s.StudentID = a.StudentID
    LEFT JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
    LEFT JOIN counselor_feedback cf ON cf.AssessmentID = a.AssessmentID
    LEFT JOIN rse_results rse ON rse.AssessmentID = a.AssessmentID
    LEFT JOIN mbi_results mbi ON mbi.AssessmentID = a.AssessmentID
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

    $mbi = $conn->prepare("SELECT EX_Score, CY_Score, EF_Score, EX_Level, CY_Level, EF_Level, BurnoutStatus FROM mbi_results WHERE AssessmentID = ?");
    $mbi->bind_param("i", $row['AssessmentID']);
    $mbi->execute();
    $mbiRow = $mbi->get_result()->fetch_assoc();
    $mbi->close();

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
        ] : null,
        "counselorAction" => $row['CounselorAction'],
        "feedbackNotes"   => $row['FeedbackNotes'],
        "reviewedAt"      => $row['ReviewedAt']
    ];
}

echo json_encode([
    "status"  => "success",
    "records" => $records,
    "total"   => count($records)
]);

$conn->close();
?>
