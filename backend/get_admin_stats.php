<?php
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, X-Admin-Pin");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$stats = [];

// 1. Total Counselors
$stats['total_counselors'] = (int)$conn->query("SELECT COUNT(*) FROM counselors")->fetch_row()[0];

// 2. Total Students
$stats['total_students'] = (int)$conn->query("SELECT COUNT(*) FROM students")->fetch_row()[0];

// 3. Completed Assessments (Approved or Declined)
$stats['completed_assessments'] = (int)$conn->query("SELECT COUNT(*) FROM assessments WHERE Status IN ('approved', 'declined')")->fetch_row()[0];

// 4. Total Results Generated
$stats['total_results'] = (int)$conn->query("SELECT COUNT(*) FROM assessment_results")->fetch_row()[0];

// 5. Currently active sessions
$stats['active_sessions'] = (int)$conn->query("SELECT COUNT(*) FROM live_sessions WHERE IsActive = TRUE")->fetch_row()[0];

echo json_encode(["status" => "success", "data" => $stats]);

$conn->close();
?>
