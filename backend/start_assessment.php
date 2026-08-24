<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
include 'cors.php';
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$data      = json_decode(file_get_contents("php://input"), true);
$studentId = $data['studentId'] ?? '';
$piId      = $data['piId']      ?? '';
$agreed    = $data['agreed']    ?? false;

if (empty($studentId) || empty($piId)) {
    echo json_encode(["status" => "error", "message" => "Missing studentId or piId"]);
    exit();
}

if (!$agreed) {
    echo json_encode(["status" => "error", "message" => "You must acknowledge and agree to the terms to proceed."]);
    exit();
}

$check = $conn->prepare("SELECT AssessmentID, Status FROM assessments WHERE StudentID = ? AND Status IN ('in_progress', 'pending_review', 'approved') ORDER BY StartedAt DESC LIMIT 1");
$check->bind_param("s", $studentId);
$check->execute();
$guardianResult = $check->get_result();

if ($guardianResult && $guardianResult->num_rows > 0) {
    $existing = $guardianResult->fetch_assoc();
    if ($existing['Status'] === 'in_progress') {
        // Safe to Resume
        echo json_encode(["status" => "resume", "assessmentId" => (int)$existing['AssessmentID']]);
    } else {
        // Truly blocked (already submitted or approved)
        echo json_encode(["status" => "error", "message" => "Multi-tab exploit blocked: You already have a completed or pending assessment."]);
    }
    exit();
}

$stmt = $conn->prepare("
    INSERT INTO assessments (StudentID, PI_ID, Status, AgreedToDisclaimer) VALUES (?, ?, 'in_progress', 1)
");
$stmt->bind_param("si", $studentId, $piId);

if ($stmt->execute()) {
    $assessmentId = $conn->insert_id;

    $live = $conn->prepare("
        INSERT INTO live_sessions (AssessmentID, StudentID, PI_ID, CurrentQuestion, TotalQuestions, IsActive)
        VALUES (?, ?, ?, 1, 77, TRUE)
    ");
    $live->bind_param("isi", $assessmentId, $studentId, $piId);
    $live->execute();

    echo json_encode(["status" => "success", "assessmentId" => $assessmentId]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to start assessment"]);
}

$conn->close();
?>
