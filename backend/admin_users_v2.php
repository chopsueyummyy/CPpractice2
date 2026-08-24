<?php
// admin_users_v2.php
header("Content-Type: application/json");
include 'cors.php';
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$method = $_SERVER['REQUEST_METHOD'];

// helper for logging
function logActivity($conn, $adminId, $action, $targetType, $targetId = null, $details = null) {
    $stmt = $conn->prepare("INSERT INTO system_logs (AdminID, Action, TargetType, TargetID, Details) VALUES (?, ?, ?, ?, ?)");
    $stmt->bind_param("issis", $adminId, $action, $targetType, $targetId, $details);
    $stmt->execute();
}

// Fetch All Users
if ($method === 'GET') {
    // We expect the frontend to pass the AdminID and RoleID as query params for tracking
    $adminId = $_GET['adminId'] ?? null;
    $roleId = $_GET['roleId'] ?? null;
    
    if (!$adminId) {
        die(json_encode(["status" => "error", "message" => "Unauthorized access."]));
    }
    
    $response = [
        "admins" => [],
        "counselors" => [],
        "students" => []
    ];
    
    // Only SuperAdmin (4) can view other Admins
    if ((int)$roleId === 4) {
        $res = $conn->query("SELECT AdminID as id, FirstName as firstName, LastName as lastName, Email as email, RoleID as roleId, IsBlocked as isBlocked FROM admins ORDER BY RoleID DESC");
        while ($row = $res->fetch_assoc()) {
            $response['admins'][] = $row;
        }
    }
    
    $res = $conn->query("SELECT CounselorID as id, FirstName as firstName, LastName as lastName, Email as email, IsBlocked as isBlocked FROM counselors");
    while ($row = $res->fetch_assoc()) {
        $response['counselors'][] = $row;
    }
    
    $res = $conn->query("SELECT StudentID as id, FirstName as firstName, LastName as lastName, Email as email, IsBlocked as isBlocked FROM students");
    while ($row = $res->fetch_assoc()) {
        $response['students'][] = $row;
    }
    
    echo json_encode(["status" => "success", "data" => $response]);
    exit();
}

if ($method === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);
    $action = $data['action'] ?? '';
    
    $adminId = $data['reqAdminId'] ?? null;
    $roleId = (int)($data['reqRoleId'] ?? 0);
    
    if (!$adminId || $roleId < 3) {
        die(json_encode(["status" => "error", "message" => "Unauthorized Citadel transaction."]));
    }

    if ($action === 'create') {
        $targetType = $data['targetType']; // admin, counselor, student
        $email = $data['email'];
        $password = password_hash($data['password'], PASSWORD_DEFAULT);
        $fn = $data['firstName'];
        $ln = $data['lastName'];
        
        if ($targetType === 'admin') {
            if ($roleId !== 4) die(json_encode(["status" => "error", "message" => "Only Super Admins can create Admins."]));
            $stmt = $conn->prepare("INSERT INTO admins (RoleID, FirstName, LastName, Email, Password) VALUES (3, ?, ?, ?, ?)");
            $stmt->bind_param("ssss", $fn, $ln, $email, $password);
            
        } elseif ($targetType === 'counselor') {
            $stmt = $conn->prepare("INSERT INTO counselors (RoleID, FirstName, LastName, Email, Password) VALUES (2, ?, ?, ?, ?)");
            $stmt->bind_param("ssss", $fn, $ln, $email, $password);
            
        } elseif ($targetType === 'student') {
            $studentId = $data['studentId'] ?? null;
            if (!$studentId) die(json_encode(["status" => "error", "message" => "Student ID is required."]));
            
            // Explicit checks to provide better UI feedback
            $stmtCheckId = $conn->prepare("SELECT StudentID FROM students WHERE StudentID = ?");
            if ($stmtCheckId) {
                $stmtCheckId->bind_param("s", $studentId);
                $stmtCheckId->execute();
                $checkId = $stmtCheckId->get_result();
                if ($checkId->num_rows > 0) {
                    $stmtCheckId->close();
                    die(json_encode(["status" => "error", "message" => "Student ID $studentId already exists."]));
                }
                $stmtCheckId->close();
            }
            
            $stmtCheckEmail = $conn->prepare("SELECT Email FROM students WHERE Email = ?");
            if ($stmtCheckEmail) {
                $stmtCheckEmail->bind_param("s", $email);
                $stmtCheckEmail->execute();
                $checkEmail = $stmtCheckEmail->get_result();
                if ($checkEmail->num_rows > 0) {
                    $stmtCheckEmail->close();
                    die(json_encode(["status" => "error", "message" => "Email $email is already registered."]));
                }
                $stmtCheckEmail->close();
            }

            $conn->begin_transaction();
            try {
                $strand = $data['strand'] ?? 'STEM';
                $grade = $data['gradeLevel'] ?? 'Grade 11';
                $sex = $data['sex'] ?? 'Male';
                $age = $data['age'] ?? 16;
                $fn = $fn ?? '';
                $ln = $ln ?? '';
                
                $stmt = $conn->prepare("INSERT INTO students (StudentID, FirstName, LastName, Email, Password) VALUES (?, ?, ?, ?, ?)");
                $stmt->bind_param("sssss", $studentId, $fn, $ln, $email, $password);
                $stmt->execute();
                
                $pi = $conn->prepare("INSERT INTO personal_information (StudentID, FirstName, LastName, Birthdate, Age, Gender, Strand, GradeLevel) VALUES (?, ?, ?, '2000-01-01', ?, ?, ?, ?)");
                $pi->bind_param("sssisss", $studentId, $fn, $ln, $age, $sex, $strand, $grade);
                $pi->execute();
                
                $conn->commit();
                logActivity($conn, $adminId, 'CREATE_USER', 'student', $studentId, "Created student: $email");
                echo json_encode(["status" => "success", "message" => "Student created successfully."]);
                exit();
            } catch (Exception $e) {
                $conn->rollback();
                die(json_encode(["status" => "error", "message" => "Critical failure: " . $e->getMessage()]));
            }
        }
        
        if (isset($stmt) && $stmt->execute()) {
            $newId = $conn->insert_id;
            logActivity($conn, $adminId, 'CREATE_USER', $targetType, $newId, "Created $targetType: $email");
            echo json_encode(["status" => "success", "message" => ucfirst($targetType) . " created successfully."]);
        } else {
            echo json_encode(["status" => "error", "message" => "Failed to create user or email already exists."]);
        }
        exit();
    }

    if ($action === 'toggle_block' || $action === 'delete' || $action === 'change_password') {
        $targetType = $data['targetType']; // admin, counselor
        $targetId = $data['targetId'];
        
        if ($targetType === 'admin' && $roleId !== 4) {
            die(json_encode(["status" => "error", "message" => "Only Super Admins can alter Admin accounts."]));
        }
        
        $table = ($targetType === 'admin') ? 'admins' : (($targetType === 'student') ? 'students' : 'counselors');
        $idCol = ($targetType === 'admin') ? 'AdminID' : (($targetType === 'student') ? 'StudentID' : 'CounselorID');
        
        if ($action === 'toggle_block') {
            $status = (int)$data['isBlocked'];
            $stmt = $conn->prepare("UPDATE $table SET IsBlocked = ? WHERE $idCol = ?");
            $stmt->bind_param("ii", $status, $targetId);
            $stmt->execute();
            logActivity($conn, $adminId, ($status === 1 ? 'BLOCK_USER' : 'UNBLOCK_USER'), $targetType, $targetId);
            echo json_encode(["status" => "success", "message" => "Account status updated."]);
            
        } elseif ($action === 'delete') {
            $conn->begin_transaction();
            try {
                if ($targetType === 'student') {
                    // Stepwise purge of all student-related telemetry
                    $stmt1 = $conn->prepare("DELETE FROM riasec_recommendations WHERE ResultID IN (SELECT ResultID FROM assessment_results WHERE AssessmentID IN (SELECT AssessmentID FROM assessments WHERE StudentID = ?))");
                    if ($stmt1) {
                        $stmt1->bind_param("s", $targetId);
                        $stmt1->execute();
                        $stmt1->close();
                    }
                    $stmt2 = $conn->prepare("DELETE FROM assessment_results WHERE AssessmentID IN (SELECT AssessmentID FROM assessments WHERE StudentID = ?)");
                    if ($stmt2) {
                        $stmt2->bind_param("s", $targetId);
                        $stmt2->execute();
                        $stmt2->close();
                    }
                    $stmt3 = $conn->prepare("DELETE FROM assessment_answers WHERE AssessmentID IN (SELECT AssessmentID FROM assessments WHERE StudentID = ?)");
                    if ($stmt3) {
                        $stmt3->bind_param("s", $targetId);
                        $stmt3->execute();
                        $stmt3->close();
                    }
                    $stmt4 = $conn->prepare("DELETE FROM counselor_feedback WHERE AssessmentID IN (SELECT AssessmentID FROM assessments WHERE StudentID = ?)");
                    if ($stmt4) {
                        $stmt4->bind_param("s", $targetId);
                        $stmt4->execute();
                        $stmt4->close();
                    }
                    $stmt5 = $conn->prepare("DELETE FROM live_sessions WHERE StudentID = ?");
                    if ($stmt5) {
                        $stmt5->bind_param("s", $targetId);
                        $stmt5->execute();
                        $stmt5->close();
                    }
                    $stmt6 = $conn->prepare("DELETE FROM assessments WHERE StudentID = ?");
                    if ($stmt6) {
                        $stmt6->bind_param("s", $targetId);
                        $stmt6->execute();
                        $stmt6->close();
                    }
                    $stmt7 = $conn->prepare("DELETE FROM personal_information WHERE StudentID = ?");
                    if ($stmt7) {
                        $stmt7->bind_param("s", $targetId);
                        $stmt7->execute();
                        $stmt7->close();
                    }
                    $stmt = $conn->prepare("DELETE FROM students WHERE StudentID = ?");
                } else {
                    $stmt = $conn->prepare("DELETE FROM $table WHERE $idCol = ?");
                }
                
                $stmt->bind_param("s", $targetId);
                $stmt->execute();
                
                $conn->commit();
                logActivity($conn, $adminId, 'DELETE_USER', $targetType, $targetId);
                echo json_encode(["status" => "success", "message" => "Account permanently deleted."]);
            } catch (Exception $e) {
                $conn->rollback();
                echo json_encode(["status" => "error", "message" => "Transaction failed: " . $e->getMessage()]);
            }
            
        } elseif ($action === 'change_password') {
            $password = password_hash($data['newPassword'], PASSWORD_DEFAULT);
            $stmt = $conn->prepare("UPDATE $table SET Password = ? WHERE $idCol = ?");
            $stmt->bind_param("si", $password, $targetId);
            $stmt->execute();
            logActivity($conn, $adminId, 'PASSWORD_RESET', $targetType, $targetId);
            echo json_encode(["status" => "success", "message" => "Keys rotated successfully."]);
        }
        exit();
    }
}
$conn->close();
?>
