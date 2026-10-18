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
require_once __DIR__ . '/services/CacheService.php';

$data         = json_decode(file_get_contents("php://input"), true);
$assessmentId = (int)($data['assessmentId'] ?? 0);
$action       = $data['action'] ?? ''; 
$counselorId  = (int)($data['counselorId'] ?? 0);
$notes        = $data['notes'] ?? '';
$aiRating     = isset($data['aiRating']) ? (int)$data['aiRating'] : null;

$validActions = ['endorse', 'approved', 'rejected', 'declined'];
if (!$assessmentId || !in_array($action, $validActions) || !$counselorId) {
    echo json_encode(["status" => "error", "message" => "Missing or invalid required fields"]);
    exit();
}

$isEndorsement = ($action === 'endorse');
$reviewerRole = $isEndorsement ? 'psychometrician' : 'guidance_counselor';
$isStudentVisible = $isEndorsement ? 0 : 1;

if ($isEndorsement) {
    $targetAssessmentStatus = 'pending_counselor';
    $feedbackAction = 'modified';
} else {
    $feedbackAction = ($action === 'rejected' || $action === 'declined') ? 'declined' : 'approved';
    $targetAssessmentStatus = $feedbackAction;
}

// 1. Update Assessment Status
$upd = $conn->prepare("UPDATE assessments SET Status = ? WHERE AssessmentID = ?");
$upd->bind_param("si", $targetAssessmentStatus, $assessmentId);
if (!$upd->execute()) {
    echo json_encode(["status" => "error", "message" => "Failed to update assessment status"]);
    exit();
}
$upd->close();

// 2. Optional: Calibrate Cluster Recommendations if modified by Psychometrician
if (!empty($data['clusterRecommendations'])) {
    $clusterJson = is_string($data['clusterRecommendations']) 
        ? $data['clusterRecommendations'] 
        : json_encode($data['clusterRecommendations']);
    $updRec = $conn->prepare("UPDATE assessment_results SET ClusterRecommendations = ? WHERE AssessmentID = ?");
    if ($updRec) {
        $updRec->bind_param("si", $clusterJson, $assessmentId);
        $updRec->execute();
        $updRec->close();
    }
}

// 3. Insert or Update Reviewer Feedback Record
$checkFb = $conn->prepare("SELECT FeedbackID FROM counselor_feedback WHERE AssessmentID = ? AND ReviewerRole = ? ORDER BY FeedbackID DESC LIMIT 1");
$checkFb->bind_param("is", $assessmentId, $reviewerRole);
$checkFb->execute();
$fbRow = $checkFb->get_result()->fetch_assoc();
$checkFb->close();

if ($fbRow) {
    $fb = $conn->prepare("
        UPDATE counselor_feedback 
        SET CounselorID = ?, Action = ?, FeedbackNotes = ?, ReviewedAt = NOW(), IsStudentVisible = ?, AiRating = ? 
        WHERE FeedbackID = ?
    ");
    $fb->bind_param("issiii", $counselorId, $feedbackAction, $notes, $isStudentVisible, $aiRating, $fbRow['FeedbackID']);
    $fb->execute();
    $fb->close();
} else {
    $fb = $conn->prepare("
        INSERT INTO counselor_feedback (AssessmentID, CounselorID, Action, FeedbackNotes, ReviewedAt, ReviewerRole, IsStudentVisible, AiRating) 
        VALUES (?, ?, ?, ?, NOW(), ?, ?, ?)
    ");
    $fb->bind_param("iisssii", $assessmentId, $counselorId, $feedbackAction, $notes, $reviewerRole, $isStudentVisible, $aiRating);
    $fb->execute();
    $fb->close();
}

// Flush dashboard stats cache
CacheService::flush();

// 4. Return immediately if this was an endorsement (no student email sent yet)
if ($isEndorsement) {
    echo json_encode([
        "status" => "success", 
        "message" => "Assessment successfully endorsed to Guidance Counselor with diagnostic notes."
    ]);
    $conn->close();
    exit();
}

// 5. Send notification email to student on final approval / release
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
    $mailResult = false;
    try {
        $mailResult = sendAssessmentEmail($stuRow['Email'], $stuRow['FirstName'], $feedbackAction, $notes, 'sam.bandayanon@jmc.edu.ph');
    } catch (Throwable $e) {
        error_log("CRITICAL MAILER FAILURE: " . $e->getMessage());
    }

    if ($mailResult) {
        echo json_encode(["status" => "success", "message" => "Assessment $feedbackAction successfully and email sent."]);
    } else {
        echo json_encode([
            "status" => "success", 
            "message" => "Assessment $feedbackAction, but email notification failed (likely blocked by server).",
            "email_error" => true
        ]);
    }
} else {
    echo json_encode(["status" => "success", "message" => "Assessment $feedbackAction successfully."]);
}

$conn->close();
?>
