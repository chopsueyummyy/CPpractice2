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

$data           = json_decode(file_get_contents("php://input"), true);
$assessmentId   = $data['assessmentId']   ?? '';
$counselorId    = $data['counselorId']    ?? '';
$action         = $data['action']         ?? ''; // approved, declined, modified
$feedbackNotes  = $data['feedbackNotes']  ?? null;
$modifiedCourseId = $data['modifiedCourseId'] ?? null;

$curatedRecommendations = $data['curatedRecommendations'] ?? null;
$generalInsights        = $data['generalInsights']        ?? null;

if (empty($assessmentId) || empty($counselorId) || empty($action)) {
    echo json_encode(["status" => "error", "message" => "Missing required fields"]);
    exit();
}

if ($action === 'rejected') {
    $action = 'declined';
}

$validActions = ['approved', 'declined', 'modified', 'endorse'];
if (!in_array($action, $validActions)) {
    echo json_encode(["status" => "error", "message" => "Invalid action"]);
    exit();
}

$isEndorse = ($action === 'endorse' || $action === 'modified');
$reviewerRole = $data['reviewerRole'] ?? ($isEndorse ? 'psychometrician' : 'guidance_counselor');
$isStudentVisible = ($reviewerRole === 'psychometrician') ? 0 : 1;

if ($reviewerRole === 'psychometrician') {
    $newStatus = 'pending_counselor';
    $dbAction = 'modified';
} else {
    $dbAction = ($action === 'declined') ? 'declined' : 'approved';
    $newStatus = $dbAction;
}

$checkFb = $conn->prepare("SELECT FeedbackID FROM counselor_feedback WHERE AssessmentID = ? AND ReviewerRole = ? ORDER BY FeedbackID DESC LIMIT 1");
$checkFb->bind_param("is", $assessmentId, $reviewerRole);
$checkFb->execute();
$fbRow = $checkFb->get_result()->fetch_assoc();
$checkFb->close();

if ($fbRow) {
    $stmt = $conn->prepare("UPDATE counselor_feedback SET CounselorID = ?, Action = ?, ModifiedCourseID = ?, FeedbackNotes = ?, ReviewedAt = NOW(), IsStudentVisible = ? WHERE FeedbackID = ?");
    $stmt->bind_param("isisii", $counselorId, $dbAction, $modifiedCourseId, $feedbackNotes, $isStudentVisible, $fbRow['FeedbackID']);
} else {
    $stmt = $conn->prepare("INSERT INTO counselor_feedback (AssessmentID, CounselorID, Action, ModifiedCourseID, FeedbackNotes, ReviewedAt, ReviewerRole, IsStudentVisible) VALUES (?, ?, ?, ?, ?, NOW(), ?, ?)");
    $stmt->bind_param("iisissi", $assessmentId, $counselorId, $dbAction, $modifiedCourseId, $feedbackNotes, $reviewerRole, $isStudentVisible);
}

if ($stmt->execute()) {
    $upd = $conn->prepare("UPDATE assessments SET Status = ? WHERE AssessmentID = ?");
    $upd->bind_param("si", $newStatus, $assessmentId);
    $upd->execute();
    $upd->close();

    // If customized / calibrated recommended courses under clusters, update assessment_results
    if (!empty($curatedRecommendations)) {
        $jsonCurated = is_string($curatedRecommendations) ? $curatedRecommendations : json_encode($curatedRecommendations);
        $updRes = $conn->prepare("UPDATE assessment_results SET ClusterRecommendations = ? WHERE AssessmentID = ?");
        $updRes->bind_param("si", $jsonCurated, $assessmentId);
        $updRes->execute();
        $updRes->close();
    }

    // If customized General Assessment Insights & Summary provided, update assessment_results
    if (!empty($generalInsights)) {
        $jsonInsights = is_string($generalInsights) ? $generalInsights : json_encode($generalInsights);
        $updIns = $conn->prepare("UPDATE assessment_results SET GeneralInsights = ? WHERE AssessmentID = ?");
        $updIns->bind_param("si", $jsonInsights, $assessmentId);
        $updIns->execute();
        $updIns->close();
    }

    CacheService::flush();

    if ($reviewerRole === 'guidance_counselor') {
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
            try {
                sendAssessmentEmail($stuRow['Email'], $stuRow['FirstName'], $dbAction, $feedbackNotes, 'sam.bandayanon@jmc.edu.ph');
            } catch (Throwable $e) {
                error_log("CRITICAL MAILER FAILURE in submit_feedback: " . $e->getMessage());
            }
        }
        $stuQuery->close();
    }

    $msg = ($reviewerRole === 'psychometrician')
        ? "Assessment successfully endorsed to Guidance Counselor."
        : ($dbAction === 'approved' 
            ? "Assessment successfully approved and released to student." 
            : "Assessment declined and student notified to retake.");
    echo json_encode(["status" => "success", "message" => $msg]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to submit feedback"]);
}

$conn->close();
?>
