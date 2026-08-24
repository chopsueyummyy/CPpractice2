<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
include 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

// Fetch RIASEC questions
$riasecResult = $conn->query("SELECT QuestionID, QuestionText, RIASECCategory FROM riasec_questions ORDER BY QuestionID");
$riasec = [];
while ($row = $riasecResult->fetch_assoc()) {
    $riasec[] = [
        "id"       => (int)$row['QuestionID'],
        "question" => $row['QuestionText'],
        "category" => $row['RIASECCategory']
    ];
}

// Fetch RSE questions
$rseResult = $conn->query("SELECT QuestionID, QuestionText, IsNegative FROM rse_questions ORDER BY QuestionID");
$rse = [];
while ($row = $rseResult->fetch_assoc()) {
    $rse[] = [
        "id"         => (int)$row['QuestionID'],
        "question"   => $row['QuestionText'],
        "isNegative" => (int)$row['IsNegative']
    ];
}

// Fetch CDSES questions
$cdsesResult = $conn->query("SELECT QuestionID, QuestionText, Subscale FROM cdses_questions ORDER BY QuestionID");
$cdses = [];
while ($row = $cdsesResult->fetch_assoc()) {
    $cdses[] = [
        "id"       => (int)$row['QuestionID'],
        "question" => $row['QuestionText'],
        "subscale" => $row['Subscale']
    ];
}

echo json_encode([
    "status" => "success",
    "riasec" => $riasec,
    "rse"    => $rse,
    "cdses"  => $cdses
]);

$conn->close();
?>
