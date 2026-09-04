<?php
error_reporting(E_ALL);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$data = json_decode(file_get_contents("php://input"), true);
$assessmentId = (int)($data['assessmentId'] ?? 0);

if ($assessmentId > 0) {
    $stmt1 = $conn->prepare("DELETE FROM live_sessions WHERE AssessmentID = ?");
    if ($stmt1) {
        $stmt1->bind_param("i", $assessmentId);
        $stmt1->execute();
        $stmt1->close();
    }
    $stmt2 = $conn->prepare("DELETE FROM assessment_answers WHERE AssessmentID = ?");
    if ($stmt2) {
        $stmt2->bind_param("i", $assessmentId);
        $stmt2->execute();
        $stmt2->close();
    }
    $stmt3 = $conn->prepare("DELETE FROM assessments WHERE AssessmentID = ?");
    if ($stmt3) {
        $stmt3->bind_param("i", $assessmentId);
        $stmt3->execute();
        $stmt3->close();
    }
    
    echo json_encode(["status" => "success", "message" => "Ghost Session Deleted."]);
} else {
    echo json_encode(["status" => "error", "message" => "Invalid assessmentId"]);
}
$conn->close();
?>
