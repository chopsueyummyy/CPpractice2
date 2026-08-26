<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';
require_once 'mailer.php';

$data         = json_decode(file_get_contents("php://input"), true);
$assessmentId = (int)($data['assessmentId'] ?? 0);
$action       = $data['action'] ?? ''; 
$counselorId  = (int)($data['counselorId'] ?? 0);
$notes        = $data['notes'] ?? '';

if (!$assessmentId || !in_array($action, ['approved', 'rejected']) || !$counselorId) {
    echo json_encode(["status" => "error", "message" => "Missing required fields"]);
    exit();
}

$dbAction = ($action === 'rejected') ? 'rejected' : $action;

$upd = $conn->prepare("UPDATE assessments SET Status = ? WHERE AssessmentID = ?");
$upd->bind_param("si", $dbAction, $assessmentId);
if (!$upd->execute()) {
    echo json_encode(["status" => "error", "message" => "Failed to update status"]);
    exit();
}

$fb = $conn->prepare("
    INSERT INTO counselor_feedback (AssessmentID, CounselorID, Action, FeedbackNotes, ReviewedAt)
    VALUES (?, ?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE Action = VALUES(Action), FeedbackNotes = VALUES(FeedbackNotes), ReviewedAt = NOW()
");
$fb->bind_param("iiss", $assessmentId, $counselorId, $dbAction, $notes);
$fb->execute();

$stuQuery = $conn->prepare("
    SELECT s.Email, s.FirstName 
    FROM assessments a
    JOIN students s ON a.StudentID = s.StudentID
    WHERE a.AssessmentID = ?
");
$stuQuery->bind_param("i", $assessmentId);
$stuQuery->execute();
$stuRes = $stuQuery->get_result();
    if ($stuRow = $stuRes->fetch_assoc()) {
        // We call the mailer but ensure it doesn't break the response if it fails or slows down
        $mailResult = false;
        try {
            $mailResult = sendAssessmentEmail($stuRow['Email'], $stuRow['FirstName'], $action, $notes, 'sam.bandayanon@jmc.edu.ph');
        } catch (Throwable $e) {
            error_log("CRITICAL MAILER FAILURE: " . $e->getMessage());
        }

        if ($mailResult) {
            echo json_encode(["status" => "success", "message" => "Assessment $action successfully and email sent."]);
        } else {
            // We still return success for the assessment update, but note the email skip
            echo json_encode([
                "status" => "success", 
                "message" => "Assessment $action, but email notification failed (likely blocked by server).",
                "email_error" => true
            ]);
        }
    } else {
        // Fallback if student info missing but DB update was successful
        echo json_encode(["status" => "success", "message" => "Assessment $action successfully, but student email info could not be found."]);
    }

$conn->close();
?>
