<?php
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$data = json_decode(file_get_contents("php://input"), true);
$email = $data['email'] ?? '';
$otp   = $data['otp']   ?? '';

if (empty($email) || empty($otp)) {
    die(json_encode(["status" => "error", "message" => "Missing email or code."]));
}

// 1. Find user and check OTP
$stmt = $conn->prepare("
    SELECT AdminID, FirstName, LastName, RoleID, OTP_Code, OTP_Expiry 
    FROM admins 
    WHERE Email = ? 
    LIMIT 1
");
$stmt->bind_param("s", $email);
$stmt->execute();
$res = $stmt->get_result();

if ($res->num_rows === 1) {
    $user = $res->fetch_assoc();
    
    // 2. Check Expiry
    if (strtotime($user['OTP_Expiry']) < time()) {
        die(json_encode(["status" => "error", "message" => "Code has expired. Please log in again."]));
    }
    
    // 3. Verify Code
    if ($user['OTP_Code'] === $otp) {
        // Clear OTP after success and Update LastLogin
        $clear = $conn->prepare("UPDATE admins SET OTP_Code = NULL, OTP_Expiry = NULL, LastLogin = NOW() WHERE AdminID = ?");
        $clear->bind_param("i", $user['AdminID']);
        $clear->execute();
        
        // Determine role string
        $roleStr = ($user['RoleID'] == 4) ? 'super_admin' : 'admin';
        
        echo json_encode([
            "status"    => "success",
            "role"      => $roleStr,
            "adminId"   => $user['AdminID'],
            "firstName" => $user['FirstName'],
            "lastName"  => $user['LastName']
        ]);
    } else {
        echo json_encode(["status" => "error", "message" => "Invalid verification code."]);
    }
} else {
    echo json_encode(["status" => "error", "message" => "Login session expired."]);
}

$conn->close();
?>
