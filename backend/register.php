<?php
include 'db_connect.php';

// Production Registration API
header("Content-Type: application/json");
include 'cors.php';
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Get POST data
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    if (!$data) {
        throw new Exception("Invalid request data");
    }

    $studentId = trim($data['student_id'] ?? '');
    $email     = trim($data['email'] ?? '');
    $password  = $data['password'] ?? '';

    // Basic Validation
    if (empty($studentId) || empty($email) || empty($password)) {
        throw new Exception("ID Number, Email, and Password are all required.");
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL, FILTER_FLAG_EMAIL_UNICODE)) {
        throw new Exception("Please provide a valid email address.");
    }

    // Hash Password
    $hashedPassword = password_hash($password, PASSWORD_DEFAULT);
    
    // Check if ID or Email already exists
    $checkStmt = $conn->prepare("SELECT StudentID FROM students WHERE StudentID = ? OR Email = ? LIMIT 1");
    $checkStmt->bind_param("is", $studentId, $email);
    $checkStmt->execute();
    $checkResult = $checkStmt->get_result();
    
    if ($checkResult->num_rows > 0) {
        throw new Exception("An account with this ID Number or Email already exists.");
    }

    // RoleID for Student is 1
    $roleId = 1;
    
    // Note: FirstName and LastName are initialized as empty strings
    // They will be updated during the assessment 'Fill-up Form' phase.
    $firstName = ""; 
    $lastName  = "";

    $stmt = $conn->prepare("INSERT INTO students (StudentID, RoleID, FirstName, LastName, Email, Password) VALUES (?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("isssss", $studentId, $roleId, $firstName, $lastName, $email, $hashedPassword);
    
    if ($stmt->execute()) {
        echo json_encode([
            "status"  => "success",
            "message" => "Account created successfully! You can now log in."
        ]);
    } else {
        throw new Exception("Registration failed: " . $conn->error);
    }

} catch (Exception $e) {
    echo json_encode([
        "status"  => "error",
        "message" => $e->getMessage()
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>
