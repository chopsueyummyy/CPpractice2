<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$data = json_decode(file_get_contents("php://input"), true);

$studentId  = $data['studentId']  ?? '';
$firstName  = $data['firstName']  ?? '';
$lastName   = $data['lastName']   ?? '';
$middleName = $data['middleName'] ?? null;
$suffix     = $data['suffix']     ?? null;
$birthdate  = $data['birthdate']  ?? '';
$age        = $data['age']        ?? 0;
$gender     = $data['gender']     ?? '';
$strand     = $data['strand']     ?? '';
$gradeLevel = $data['gradeLevel'] ?? '';

if (empty($studentId) || empty($firstName) || empty($lastName) || empty($birthdate) || empty($gender) || empty($strand) || empty($gradeLevel)) {
    echo json_encode(["status" => "error", "message" => "Missing required fields"]);
    exit();
}

$check = $conn->prepare("
    SELECT pi.PI_ID FROM personal_information pi
    JOIN assessments a ON a.PI_ID = pi.PI_ID
    WHERE pi.StudentID = ? AND a.Status = 'in_progress' LIMIT 1
");
$check->bind_param("s", $studentId);
$check->execute();
$existing = $check->get_result();

if ($existing->num_rows > 0) {
    $row = $existing->fetch_assoc();
    echo json_encode(["status" => "success", "piId" => $row['PI_ID'], "message" => "Existing record found"]);
    exit();
}

$stmt = $conn->prepare("
    INSERT INTO personal_information (StudentID, FirstName, LastName, MiddleName, Suffix, Birthdate, Age, Gender, Strand, GradeLevel)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
");
$stmt->bind_param("ssssssisss", $studentId, $firstName, $lastName, $middleName, $suffix, $birthdate, $age, $gender, $strand, $gradeLevel);

if ($stmt->execute()) {
    $piId = $conn->insert_id;
    
    // SYNC: Update main students table with these names for Admin visibility
    $sync = $conn->prepare("UPDATE students SET FirstName = ?, LastName = ? WHERE StudentID = ?");
    $sync->bind_param("sss", $firstName, $lastName, $studentId);
    $sync->execute();
    
    echo json_encode(["status" => "success", "piId" => $piId]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to save personal information"]);
}

$conn->close();
?>
