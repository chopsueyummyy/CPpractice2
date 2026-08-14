<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$data           = json_decode(file_get_contents("php://input"), true);
$assessmentId   = $data['assessmentId']   ?? '';
$currentQuestion = $data['currentQuestion'] ?? 1;
$duration       = $data['duration']       ?? 0;

if (empty($assessmentId)) {
    echo json_encode(["status" => "error", "message" => "Missing assessmentId"]);
    exit();
}

$stmt = $conn->prepare("
    UPDATE live_sessions SET CurrentQuestion = ?, Duration = ?, TotalQuestions = 77
    WHERE AssessmentID = ? AND IsActive = TRUE
");
$stmt->bind_param("iii", $currentQuestion, $duration, $assessmentId);
$stmt->execute();

echo json_encode(["status" => "success"]);
$conn->close();
?>
