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

    $ip_address = $_SERVER['REMOTE_ADDR'] ?? '127.0.0.1';

    // Helper to log a failed attempt
    $recordFailedAttempt = function($conn, $identifier, $ip) {
        if (empty($identifier)) return;
        $stmt = $conn->prepare("INSERT INTO login_attempts (identifier, ip_address, attempt_time) VALUES (?, ?, NOW())");
        if ($stmt) {
            $stmt->bind_param("ss", $identifier, $ip);
            $stmt->execute();
        }
    };

    // Helper to clear failed attempts on successful login
    $clearLoginAttempts = function($conn, $identifier, $ip) {
        if (empty($identifier)) return;
        $stmt = $conn->prepare("DELETE FROM login_attempts WHERE identifier = ? OR ip_address = ?");
        if ($stmt) {
            $stmt->bind_param("ss", $identifier, $ip);
            $stmt->execute();
        }
    };

    // Ensure login_attempts table exists
    @$conn->query("CREATE TABLE IF NOT EXISTS login_attempts (
        id INT AUTO_INCREMENT PRIMARY KEY,
        identifier VARCHAR(100) NOT NULL,
        ip_address VARCHAR(45) NOT NULL,
        attempt_time DATETIME NOT NULL,
        INDEX idx_ident (identifier),
        INDEX idx_ip (ip_address),
        INDEX idx_time (attempt_time)
    )");

    // Clean up attempts older than 5 minutes
    @$conn->query("DELETE FROM login_attempts WHERE attempt_time < NOW() - INTERVAL 5 MINUTE");

    // Determine user identifier based on role
    $identifier = '';
    if ($role === 'student' || $role === 'student_role') {
        $identifier = $data['student_id'] ?? '';
    } else {
        $identifier = $data['email'] ?? '';
    }

    // Check rate limiting
    if (!empty($identifier)) {
        $check_stmt = $conn->prepare("SELECT COUNT(*) AS failure_count, MAX(attempt_time) AS last_attempt FROM login_attempts WHERE (identifier = ? OR ip_address = ?) AND attempt_time >= NOW() - INTERVAL 3 MINUTE");
        if ($check_stmt) {
            $check_stmt->bind_param("ss", $identifier, $ip_address);
            $check_stmt->execute();
            $rate_res = $check_stmt->get_result()->fetch_assoc();
            $failures = (int)($rate_res['failure_count'] ?? 0);
            
            if ($failures >= 5 && !empty($rate_res['last_attempt'])) {
                $last_time = strtotime($rate_res['last_attempt']);
                $now = time();
                $elapsed = $now - $last_time;
                $cooldown = 60; // 60 seconds lock
                
                if ($elapsed < $cooldown) {
                    $remaining = $cooldown - $elapsed;
                    http_response_code(429);
                    die(json_encode([
                        "status"           => "error",
                        "error_type"       => "rate_limit",
                        "message"          => "Too many failed login attempts. Please wait {$remaining} seconds before trying again.",
                        "remainingSeconds" => $remaining
                    ]));
                }
            }
        }
    }

    if ($role === 'student' || $role === 'student_role') {
        $student_id = $data['student_id'] ?? '';
        if (empty($student_id)) {
            die(json_encode(["status" => "error", "message" => "Student ID is required"]));
        }

        $stmt = $conn->prepare("SELECT StudentID, FirstName, LastName, Password, IsBlocked FROM students WHERE StudentID = ? LIMIT 1");
        if (!$stmt) {
            die(json_encode(["status" => "error", "message" => "Database Search Error (S1)."]));
        }

        $stmt->bind_param("s", $student_id);
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result->num_rows === 1) {
            $user = $result->fetch_assoc();
            if (isset($user['IsBlocked']) && (int) $user['IsBlocked'] === 1) {
                die(json_encode(["status" => "error", "message" => "Account has been suspended by an Admin."]));
            }
            if (password_verify($password, $user['Password'])) {
                $clearLoginAttempts($conn, $student_id, $ip_address);

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
                $recordFailedAttempt($conn, $student_id, $ip_address);
                echo json_encode(["status" => "error", "message" => "Invalid credentials (password mismatch)"]);
            }
        } else {
            $recordFailedAttempt($conn, $student_id, $ip_address);
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
                $clearLoginAttempts($conn, $email, $ip_address);
                echo json_encode([
                    "status" => "success",
                    "role" => "guidance_counselor",
                    "counselorId" => $user['CounselorID'],
                    "firstName" => $user['FirstName'],
                    "lastName" => $user['LastName']
                ]);
            } else {
                $recordFailedAttempt($conn, $email, $ip_address);
                echo json_encode(["status" => "error", "message" => "Invalid credentials (password mismatch)"]);
            }
        } else {
            $recordFailedAttempt($conn, $email, $ip_address);
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
                $clearLoginAttempts($conn, $email, $ip_address);
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
            } else {
                $recordFailedAttempt($conn, $email, $ip_address);
                echo json_encode(["status" => "error", "message" => "Invalid credentials (password mismatch)"]);
            }
        } else {
            $recordFailedAttempt($conn, $email, $ip_address);
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
