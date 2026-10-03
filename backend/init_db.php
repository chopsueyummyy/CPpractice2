<?php
require_once 'db_connect.php';

header("Content-Type: application/json");

// Disable strict key check for dump importing
mysqli_query($conn, "SET SESSION sql_require_primary_key = 0");

$migrationLogs = [];

// Helper function to safely add columns across all MySQL / MariaDB versions
function addColumnIfNotExists($conn, $table, $column, $definition, &$logs) {
    $check = $conn->query("SHOW COLUMNS FROM `$table` LIKE '$column'");
    if ($check) {
        if ($check->num_rows === 0) {
            $alter = $conn->query("ALTER TABLE `$table` ADD COLUMN `$column` $definition");
            if ($alter) {
                $logs[] = "ADDED `$column` to `$table` successfully.";
            } else {
                $logs[] = "FAILED adding `$column` to `$table`: " . $conn->error;
            }
        } else {
            $logs[] = "`$column` already exists in `$table`.";
        }
    } else {
        $logs[] = "SHOW COLUMNS failed for `$table`: " . $conn->error;
    }
}

// 0. Schema Parity Auto-Migrations
addColumnIfNotExists($conn, 'assessments', 'AgreedToDisclaimer', 'tinyint(1) NOT NULL DEFAULT 1', $migrationLogs);
addColumnIfNotExists($conn, 'admins', 'CreatedAt', 'timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP', $migrationLogs);
addColumnIfNotExists($conn, 'assessment_results', 'ClusterRecommendations', 'text DEFAULT NULL', $migrationLogs);
addColumnIfNotExists($conn, 'riasec_recommendations', 'ShapWeights', 'text DEFAULT NULL', $migrationLogs);


$filesToImport = [
    __DIR__ . '/../assets/riasec_db.sql',
    __DIR__ . '/riasec_db.sql',
    __DIR__ . '/add_assessments.sql'
];

foreach ($filesToImport as $sqlFile) {
    if (file_exists($sqlFile)) {
        $sql = file_get_contents($sqlFile);
        if ($conn->multi_query($sql)) {
            do {
                if ($result = $conn->store_result()) {
                    $result->free();
                }
            } while ($conn->next_result());
        }
    }
}

// 1. Ensure admins table exists
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

// 2. Ensure login_attempts table exists
$conn->query("CREATE TABLE IF NOT EXISTS login_attempts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(100) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    attempt_time DATETIME NOT NULL,
    INDEX idx_ident (identifier),
    INDEX idx_ip (ip_address),
    INDEX idx_time (attempt_time)
);");

// 3. Ensure system_logs table exists
$conn->query("CREATE TABLE IF NOT EXISTS system_logs (
    LogID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    AdminID bigint(20) DEFAULT NULL,
    Action varchar(100) NOT NULL,
    TargetType varchar(50) NOT NULL,
    TargetID varchar(100) DEFAULT NULL,
    Details text DEFAULT NULL,
    CreatedAt timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

// 4. Seed Super Admin Account
$email = "sam.bandayanon@jmc.edu.ph";
$passwordHash = password_hash("C0U10R5123", PASSWORD_BCRYPT);
$firstName = "Sam";
$lastName = "Bandayanon";
$roleID = 4; // Super Admin

$stmt = $conn->prepare("SELECT AdminID FROM admins WHERE Email = ?");
$stmt->bind_param("s", $email);
$stmt->execute();
$res = $stmt->get_result();

if ($res->num_rows > 0) {
    $upd = $conn->prepare("UPDATE admins SET Password = ?, RoleID = ?, FirstName = ?, LastName = ? WHERE Email = ?");
    $upd->bind_param("sisss", $passwordHash, $roleID, $firstName, $lastName, $email);
    $upd->execute();
    $adminMsg = "Super Admin account updated successfully!";
} else {
    $ins = $conn->prepare("INSERT INTO admins (RoleID, FirstName, LastName, Email, Password) VALUES (?, ?, ?, ?, ?)");
    $ins->bind_param("issss", $roleID, $firstName, $lastName, $email, $passwordHash);
    $ins->execute();
    $adminMsg = "Super Admin account created successfully!";
}

echo json_encode([
    "status" => "success",
    "message" => "All 21 database tables initialized & " . $adminMsg,
    "migration_logs" => $migrationLogs
]);
?>
