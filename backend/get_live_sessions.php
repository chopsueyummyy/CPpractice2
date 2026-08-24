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
        ls.SessionID,
        ls.AssessmentID,
        ls.CurrentQuestion,
        ls.TotalQuestions,
        ls.Duration,
        ls.StartedAt,
        pi.FirstName,
        pi.LastName,
        pi.Strand,
        pi.GradeLevel,
        s.StudentID
    FROM live_sessions ls
    JOIN assessments a ON a.AssessmentID = ls.AssessmentID
    JOIN personal_information pi ON pi.PI_ID = ls.PI_ID
    JOIN students s ON s.StudentID = ls.StudentID
    WHERE ls.IsActive = TRUE AND a.Status = 'in_progress'
    ORDER BY ls.StartedAt DESC
");

$sessions = [];
while ($row = $result->fetch_assoc()) {
    $sessions[] = [
        "sessionId"       => $row['SessionID'],
        "assessmentId"    => $row['AssessmentID'],
        "studentId"       => $row['StudentID'],
        "studentName"     => $row['FirstName'] . ' ' . $row['LastName'],
        "strand"          => $row['Strand'],
        "gradeLevel"      => $row['GradeLevel'],
        "currentQuestion" => (int)$row['CurrentQuestion'],
        "totalQuestions"  => (int)$row['TotalQuestions'],
        "progress"        => round($row['CurrentQuestion'] / $row['TotalQuestions'], 2),
        "duration"        => (int)$row['Duration'],
        "startedAt"       => $row['StartedAt']
    ];
}

$completedToday = $conn->query("
    SELECT COUNT(*) as count FROM assessments
    WHERE DATE(SubmittedAt) = CURDATE() AND Status != 'in_progress'
")->fetch_assoc()['count'];

echo json_encode([
    "status"         => "success",
    "activeSessions" => $sessions,
    "completedToday" => (int)$completedToday,
    "inProgress"     => count($sessions)
]);

$conn->close();
?>
