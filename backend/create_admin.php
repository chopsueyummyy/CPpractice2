<?php
/**
 * CLI Account Seeder Script
 * Usage: php create_admin.php <role> <email> <password> <firstName> <lastName>
 * Roles supported: super_admin, admin, counselor
 * 
 * Example:
 * php create_admin.php super_admin admin@school.com MyStrongPassword123! Super Admin
 * php create_admin.php counselor counselor@school.com CounselorPassword123! Maria Santos
 */

if (php_sapi_name() !== 'cli') {
    die("Access denied. This script can only be run via CLI.\n");
}

require_once __DIR__ . '/db_connect.php';

$role      = strtolower($argv[1] ?? '');
$email     = trim($argv[2] ?? '');
$password  = $argv[3] ?? '';
$firstName = trim($argv[4] ?? 'System');
$lastName  = trim($argv[5] ?? 'User');

if (empty($role) || empty($email) || empty($password)) {
    echo "========================================================\n";
    echo " CourseAlign - Secure Account Seeder Utility\n";
    echo "========================================================\n";
    echo "Usage:\n";
    echo "  php create_admin.php <role> <email> <password> [firstName] [lastName]\n\n";
    echo "Roles:\n";
    echo "  - super_admin  : Full system administrator (RoleID: 4)\n";
    echo "  - admin        : Standard administrator (RoleID: 3)\n";
    echo "  - counselor    : Guidance counselor (RoleID: 2)\n\n";
    echo "Examples:\n";
    echo "  php create_admin.php super_admin admin@school.com Pass123! Super Admin\n";
    echo "  php create_admin.php counselor counselor@school.com Pass123! Maria Santos\n";
    echo "========================================================\n";
    exit(1);
}

$passwordHash = password_hash($password, PASSWORD_BCRYPT);

if ($role === 'super_admin' || $role === 'admin') {
    $roleID = ($role === 'super_admin') ? 4 : 3;

    // Check if table exists
    $conn->query("CREATE TABLE IF NOT EXISTS `admins` (
      `AdminID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
      `RoleID` bigint(20) NOT NULL DEFAULT 3,
      `FirstName` varchar(100) NOT NULL,
      `LastName` varchar(100) NOT NULL,
      `Email` varchar(150) NOT NULL UNIQUE,
      `Password` varchar(255) NOT NULL,
      `OTP_Code` varchar(20) DEFAULT NULL,
      `OTP_Expiry` datetime DEFAULT NULL,
      `IsBlocked` tinyint(1) NOT NULL DEFAULT 0,
      `LastLogin` datetime DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

    $stmt = $conn->prepare("SELECT AdminID FROM admins WHERE Email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $updateStmt = $conn->prepare("UPDATE admins SET Password = ?, RoleID = ?, FirstName = ?, LastName = ? WHERE Email = ?");
        $updateStmt->bind_param("sisss", $passwordHash, $roleID, $firstName, $lastName, $email);
        if ($updateStmt->execute()) {
            echo "SUCCESS: Existing Admin account ('$email') updated with new password and details.\n";
        } else {
            echo "ERROR: Failed to update admin account: " . $conn->error . "\n";
        }
    } else {
        $insertStmt = $conn->prepare("INSERT INTO admins (RoleID, FirstName, LastName, Email, Password) VALUES (?, ?, ?, ?, ?)");
        $insertStmt->bind_param("issss", $roleID, $firstName, $lastName, $email, $passwordHash);
        if ($insertStmt->execute()) {
            echo "SUCCESS: Created new " . strtoupper($role) . " account ('$email') successfully!\n";
        } else {
            echo "ERROR: Failed to insert admin account: " . $conn->error . "\n";
        }
    }
} else if ($role === 'counselor') {
    $roleID = 2;

    $stmt = $conn->prepare("SELECT CounselorID FROM counselors WHERE Email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $updateStmt = $conn->prepare("UPDATE counselors SET Password = ?, FirstName = ?, LastName = ? WHERE Email = ?");
        $updateStmt->bind_param("ssss", $passwordHash, $firstName, $lastName, $email);
        if ($updateStmt->execute()) {
            echo "SUCCESS: Existing Counselor account ('$email') updated with new password.\n";
        } else {
            echo "ERROR: Failed to update counselor account: " . $conn->error . "\n";
        }
    } else {
        $insertStmt = $conn->prepare("INSERT INTO counselors (RoleID, FirstName, LastName, Email, Password) VALUES (?, ?, ?, ?, ?)");
        $insertStmt->bind_param("issss", $roleID, $firstName, $lastName, $email, $passwordHash);
        if ($insertStmt->execute()) {
            echo "SUCCESS: Created new Counselor account ('$email') successfully!\n";
        } else {
            echo "ERROR: Failed to insert counselor account: " . $conn->error . "\n";
        }
    }
} else {
    echo "ERROR: Invalid role '$role'. Supported roles: super_admin, admin, counselor.\n";
    exit(1);
}

$conn->close();
