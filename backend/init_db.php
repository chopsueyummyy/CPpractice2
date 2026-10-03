<?php
require_once 'db_connect.php';

header("Content-Type: application/json");

// Disable strict key check for dump importing
mysqli_query($conn, "SET SESSION sql_require_primary_key = 0");

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

// 0. Schema Parity Auto-Migrations
$conn->query("ALTER TABLE assessments ADD COLUMN IF NOT EXISTS AgreedToDisclaimer tinyint(1) NOT NULL DEFAULT 1;");
$conn->query("ALTER TABLE admins ADD COLUMN IF NOT EXISTS CreatedAt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP;");
$conn->query("ALTER TABLE assessment_results ADD COLUMN IF NOT EXISTS ClusterRecommendations text DEFAULT NULL;");
$conn->query("ALTER TABLE riasec_recommendations ADD COLUMN IF NOT EXISTS ShapWeights text DEFAULT NULL;");

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
    "message" => "All 21 database tables initialized & " . $adminMsg
]);
?>
