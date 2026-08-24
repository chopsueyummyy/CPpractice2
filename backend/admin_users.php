<?php
header("Content-Type: application/json");
include 'cors.php';
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Admin-Pin");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$headers = getallheaders();
$pin = $headers['X-Admin-Pin'] ?? $_SERVER['HTTP_X_ADMIN_PIN'] ?? '';
$envPin = getenv('ADMIN_PIN') ?: '1234567';

if ($pin !== $envPin) {
    echo json_encode(["status" => "error", "message" => "Unauthorized access. Invalid Admin PIN."]);
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    $students = [];
    $sRes = $conn->query("SELECT StudentID as ID, FirstName, LastName, Email, CreatedAt, IsBlocked, 'student' as Role FROM students");
    while($r = $sRes->fetch_assoc()) $students[] = $r;

    $counselors = [];
    $cRes = $conn->query("SELECT CounselorID as ID, FirstName, LastName, Email, CreatedAt, IsBlocked, 'counselor' as Role FROM counselors");
    while($r = $cRes->fetch_assoc()) $counselors[] = $r;

    echo json_encode(["status" => "success", "students" => $students, "counselors" => $counselors]);

} elseif ($method === 'POST') {
    $data = json_decode(file_get_contents("php://input"), true);
    $role = $data['role'] ?? 'student';
    $fname = $data['firstName'] ?? '';
    $lname = $data['lastName'] ?? '';
    $email = $data['email'] ?? '';
    $pass = password_hash($data['password'] ?? 'password123', PASSWORD_DEFAULT);

    if (empty($fname) || empty($email)) {
        echo json_encode(["status" => "error", "message" => "Missing required fields"]);
        exit();
    }

    if ($role === 'student') {
        $id = $data['id'] ?? null;
        if (!$id) {
            $idRes = $conn->query("SELECT MAX(StudentID) as maxId FROM students");
            $id = ($idRes->fetch_assoc()['maxId'] ?? 2024000) + 1;
        }
        $stmt = $conn->prepare("INSERT INTO students (StudentID, FirstName, LastName, Email, Password) VALUES (?, ?, ?, ?, ?)");
        $stmt->bind_param("issss", $id, $fname, $lname, $email, $pass);
    } else {
        $stmt = $conn->prepare("INSERT INTO counselors (FirstName, LastName, Email, Password) VALUES (?, ?, ?, ?)");
        $stmt->bind_param("ssss", $fname, $lname, $email, $pass);
    }
    
    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => ucfirst($role) . " registered successfully"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to register. Email might be in use."]);
    }

} elseif ($method === 'PUT') {
    $data = json_decode(file_get_contents("php://input"), true);
    $role = $data['role'] ?? 'student';
    $id = (int)($data['id'] ?? 0);
    $action = $data['action'] ?? 'update_profile';
    
    $table = $role === 'student' ? 'students' : 'counselors';
    $idCol = $role === 'student' ? 'StudentID' : 'CounselorID';
    
    if ($action === 'toggle_block') {
        $blocked = (int)($data['isBlocked'] ?? 0);
        $stmt = $conn->prepare("UPDATE $table SET IsBlocked=? WHERE $idCol=?");
        $stmt->bind_param("ii", $blocked, $id);
    } else {
        $fname = $data['firstName'] ?? '';
        $lname = $data['lastName'] ?? '';
        $email = $data['email'] ?? '';
        $pass = $data['password'] ?? '';
        
        if ($pass) {
            $phash = password_hash($pass, PASSWORD_DEFAULT);
            $stmt = $conn->prepare("UPDATE $table SET FirstName=?, LastName=?, Email=?, Password=? WHERE $idCol=?");
            $stmt->bind_param("ssssi", $fname, $lname, $email, $phash, $id);
        } else {
            $stmt = $conn->prepare("UPDATE $table SET FirstName=?, LastName=?, Email=? WHERE $idCol=?");
            $stmt->bind_param("sssi", $fname, $lname, $email, $id);
        }
    }
    
    if ($stmt->execute()) {
         echo json_encode(["status" => "success", "message" => "User updated"]);
    } else {
         echo json_encode(["status" => "error", "message" => "Failed to update"]);
    }

} elseif ($method === 'DELETE') {
    $data = json_decode(file_get_contents("php://input"), true);
    $role = $data['role'] ?? 'student';
    $id = (int)($data['id'] ?? 0);
    
    if ($role === 'student') {
        $stmtDelLive = $conn->prepare("DELETE FROM live_sessions WHERE StudentID = ?");
        if ($stmtDelLive) {
            $stmtDelLive->bind_param("i", $id);
            $stmtDelLive->execute();
            $stmtDelLive->close();
        }
        $stmtAss = $conn->prepare("SELECT AssessmentID FROM assessments WHERE StudentID = ?");
        if ($stmtAss) {
            $stmtAss->bind_param("i", $id);
            $stmtAss->execute();
            $assRes = $stmtAss->get_result();
            
            $stmtDelAns = $conn->prepare("DELETE FROM assessment_answers WHERE AssessmentID = ?");
            $stmtDelRec = $conn->prepare("DELETE FROM riasec_recommendations WHERE ResultID IN (SELECT ResultID FROM assessment_results WHERE AssessmentID = ?)");
            $stmtDelRes = $conn->prepare("DELETE FROM assessment_results WHERE AssessmentID = ?");
            $stmtDelFeed = $conn->prepare("DELETE FROM counselor_feedback WHERE AssessmentID = ?");
            $stmtDelAs = $conn->prepare("DELETE FROM assessments WHERE AssessmentID = ?");
            
            while ($r = $assRes->fetch_assoc()) {
                $aId = $r['AssessmentID'];
                if ($stmtDelAns) {
                    $stmtDelAns->bind_param("i", $aId);
                    $stmtDelAns->execute();
                }
                if ($stmtDelRec) {
                    $stmtDelRec->bind_param("i", $aId);
                    $stmtDelRec->execute();
                }
                if ($stmtDelRes) {
                    $stmtDelRes->bind_param("i", $aId);
                    $stmtDelRes->execute();
                }
                if ($stmtDelFeed) {
                    $stmtDelFeed->bind_param("i", $aId);
                    $stmtDelFeed->execute();
                }
                if ($stmtDelAs) {
                    $stmtDelAs->bind_param("i", $aId);
                    $stmtDelAs->execute();
                }
            }
            if ($stmtDelAns) $stmtDelAns->close();
            if ($stmtDelRec) $stmtDelRec->close();
            if ($stmtDelRes) $stmtDelRes->close();
            if ($stmtDelFeed) $stmtDelFeed->close();
            if ($stmtDelAs) $stmtDelAs->close();
            $stmtAss->close();
        }
        $stmtDelInfo = $conn->prepare("DELETE FROM personal_information WHERE StudentID = ?");
        if ($stmtDelInfo) {
            $stmtDelInfo->bind_param("i", $id);
            $stmtDelInfo->execute();
            $stmtDelInfo->close();
        }
        $stmt = $conn->prepare("DELETE FROM students WHERE StudentID = ?");
    } else {
        $stmtDelFeed = $conn->prepare("DELETE FROM counselor_feedback WHERE CounselorID = ?");
        if ($stmtDelFeed) {
            $stmtDelFeed->bind_param("i", $id);
            $stmtDelFeed->execute();
            $stmtDelFeed->close();
        }
        $stmt = $conn->prepare("DELETE FROM counselors WHERE CounselorID = ?");
    }
    
    $stmt->bind_param("i", $id);
    if ($stmt->execute()) {
        echo json_encode(["status" => "success", "message" => "User deleted completely"]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to delete user"]);
    }
}

$conn->close();
?>
