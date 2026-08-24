<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
include 'cors.php';
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$data           = json_decode(file_get_contents("php://input"), true);
$assessmentId   = $data['assessmentId']   ?? '';
$counselorId    = $data['counselorId']    ?? '';
$action         = $data['action']         ?? ''; // approved, declined, modified
$feedbackNotes  = $data['feedbackNotes']  ?? null;
$modifiedCourseId = $data['modifiedCourseId'] ?? null;

if (empty($assessmentId) || empty($counselorId) || empty($action)) {
    echo json_encode(["status" => "error", "message" => "Missing required fields"]);
    exit();
}

if (!in_array($action, ['approved', 'declined', 'modified'])) {
    echo json_encode(["status" => "error", "message" => "Invalid action"]);
    exit();
}

$stmt = $conn->prepare("
    INSERT INTO counselor_feedback (AssessmentID, CounselorID, Action, ModifiedCourseID, FeedbackNotes)
    VALUES (?, ?, ?, ?, ?)
");
$stmt->bind_param("iisis", $assessmentId, $counselorId, $action, $modifiedCourseId, $feedbackNotes);

if ($stmt->execute()) {
    $newStatus = $action === 'modified' ? 'approved' : $action;
    $upd = $conn->prepare("UPDATE assessments SET Status = ? WHERE AssessmentID = ?");
    $upd->bind_param("si", $newStatus, $assessmentId);
    $upd->execute();

    echo json_encode(["status" => "success", "message" => "Feedback submitted successfully"]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to submit feedback"]);
}

$conn->close();
?>
