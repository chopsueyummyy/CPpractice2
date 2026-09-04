<?php
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Disable default PHP 8.1+ mysqli exceptions (prevent silent crashes)
@mysqli_report(MYSQLI_REPORT_OFF);

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    require_once 'db_connect.php';

    $data = json_decode(file_get_contents("php://input"), true);
    $role = $data['role'] ?? '';
    $password = $data['password'] ?? '';

    if (empty($role) || empty($password)) {
        die(json_encode(["status" => "error", "message" => "Fields cannot be empty"]));
    }

    if ($role === 'student' || $role === 'student_role') {
        $student_id = $data['student_id'] ?? '';
        if (empty($student_id)) {
            die(json_encode(["status" => "error", "message" => "Student ID is required"]));
        }

        $stmt = $conn->prepare("SELECT StudentID, FirstName, LastName, Password, IsBlocked FROM students WHERE StudentID = ? LIMIT 1");
        if (!$stmt) {
            die(json_encode(["status" => "error", "message" => "Database Search Error (S1). Please check if 'students' table exists."]));
        }

        $stmt->bind_param("s", $student_id);
        if (!$stmt->execute()) {
            die(json_encode(["status" => "error", "message" => "Database Execution Error (S2)"]));
        }
        $result = $stmt->get_result();

        if ($result->num_rows === 1) {
            $user = $result->fetch_assoc();
            if (isset($user['IsBlocked']) && (int) $user['IsBlocked'] === 1) {
                die(json_encode(["status" => "error", "message" => "Account has been suspended by an Admin."]));
            }
            if (password_verify($password, $user['Password'])) {
                // Check for latest assessment status
                $assessmentStatus = null;
                $statusQuery = $conn->prepare("SELECT Status FROM assessments WHERE StudentID = ? ORDER BY CreatedAt DESC LIMIT 1");
                if ($statusQuery) {
                    $statusQuery->bind_param("s", $student_id);
                    $statusQuery->execute();
                    $statusRow = $statusQuery->get_result()->fetch_assoc();
                    $assessmentStatus = $statusRow['Status'] ?? null;
                }

                echo json_encode([
                    "status" => "success",
                    "role" => "student",
                    "studentId" => $user['StudentID'],
                    "firstName" => $user['FirstName'],
                    "lastName" => $user['LastName'],
                    "assessmentStatus" => $assessmentStatus
                ]);
            } else {
                echo json_encode(["status" => "error", "message" => "Invalid credentials (password mismatch)"]);
            }
        } else {
            echo json_encode(["status" => "error", "message" => "Invalid credentials (user not found)"]);
        }

    } elseif ($role === 'guidance_counselor') {
        $email = $data['email'] ?? '';
        if (empty($email)) {
            die(json_encode(["status" => "error", "message" => "Email is required"]));
        }

        $stmt = $conn->prepare("SELECT CounselorID, FirstName, LastName, Password, IsBlocked FROM counselors WHERE Email = ? LIMIT 1");
        if (!$stmt) {
            die(json_encode(["status" => "error", "message" => "Database Search Error (G1)."]));
        }

        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 1) {
            $user = $result->fetch_assoc();
            if (isset($user['IsBlocked']) && (int) $user['IsBlocked'] === 1) {
                die(json_encode(["status" => "error", "message" => "Counselor account suspended by Admin."]));
            }
            if (password_verify($password, $user['Password'])) {
                echo json_encode([
                    "status" => "success",
                    "role" => "guidance_counselor",
                    "counselorId" => $user['CounselorID'],
                    "firstName" => $user['FirstName'],
                    "lastName" => $user['LastName']
                ]);
            } else {
                echo json_encode(["status" => "error", "message" => "Invalid credentials (password mismatch)"]);
            }
        } else {
            echo json_encode(["status" => "error", "message" => "Invalid credentials (counselor not found)"]);
        }

    } elseif ($role === 'admin') {
        $email = $data['email'] ?? '';
        if (empty($email)) {
            die(json_encode(["status" => "error", "message" => "Email is required"]));
        }

        $stmt = $conn->prepare("SELECT AdminID, FirstName, LastName, Password, IsBlocked, RoleID FROM admins WHERE Email = ? LIMIT 1");
        if (!$stmt) {
            die(json_encode(["status" => "error", "message" => "Database Search Error (A1)."]));
        }

        $stmt->bind_param("s", $email);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 1) {
            $user = $result->fetch_assoc();
            if (isset($user['IsBlocked']) && (int) $user['IsBlocked'] === 1) {
                die(json_encode(["status" => "error", "message" => "Account suspended by Super Admin."]));
            }
            if (password_verify($password, $user['Password'])) {
                // --- CITADEL V2: 2-STEP AUTH FOR ADMINS ONLY ---
                $otp = sprintf("%06d", random_int(100000, 999999));
                $expiry = date("Y-m-d H:i:s", strtotime("+10 minutes"));
                
                $upd = $conn->prepare("UPDATE admins SET OTP_Code = ?, OTP_Expiry = ? WHERE AdminID = ?");
                $upd->bind_param("ssi", $otp, $expiry, $user['AdminID']);
                
                if ($upd->execute()) {
                    require_once 'mailer.php';
                    $adminID = (int) $user['AdminID'];
                    error_log("OTP code generated for Admin ID: {$adminID}");
                    if (sendOTPEmail($email, $user['FirstName'], $otp)) {
                        echo json_encode([
                            "status"   => "otp_pending",
                            "message"  => "Verification code sent to your email.",
                            "email"    => $email,
                            "adminId"  => $user['AdminID']
                        ]);
                    } else {
                        $safeEmail = preg_replace('/[\r\n]/', '', $email);
                        error_log("Failed to send OTP to $safeEmail - check Mailtrap or Gmail settings.");
                        echo json_encode([
                            "status"   => "error",
                            "message"  => "Failed to send OTP email. Port might be blocked."
                        ]);
                    }
                } else {
                    echo json_encode(["status" => "error", "message" => "Failed to generate security code."]);
                }
                // ------------------------------------
            } else {
                echo json_encode(["status" => "error", "message" => "Invalid credentials (password mismatch)"]);
            }
        } else {
            echo json_encode(["status" => "error", "message" => "Invalid credentials (admin not found)"]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "Invalid role selected."]);
    }

    if (isset($conn)) {
        @$conn->close();
    }

} catch (Exception $e) {
    echo json_encode([
        "status" => "error",
        "message" => "PHP Runtime Error: " . $e->getMessage()
    ]);
}
?>
