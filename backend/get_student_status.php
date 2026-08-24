<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
include 'cors.php';
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
    SELECT a.AssessmentID, a.Status
    FROM assessments a
    WHERE a.StudentID = ?
    ORDER BY a.StartedAt DESC
    LIMIT 1
");
$stmt->bind_param("s", $studentId);
$stmt->execute();
$row = $stmt->get_result()->fetch_assoc();

if (!$row) {
    echo json_encode(["status" => "success", "assessmentStatus" => null, "assessmentId" => null]);
} else {
    echo json_encode([
        "status"           => "success",
        "assessmentStatus" => $row['Status'],
        "assessmentId"     => (int)$row['AssessmentID']
    ]);
}
$conn->close();
?>
