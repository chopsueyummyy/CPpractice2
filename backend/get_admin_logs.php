<?php
// get_admin_logs.php
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

$adminId = $_GET['adminId'] ?? null;
if (!$adminId) {
    die(json_encode(["status" => "error", "message" => "Unauthorized Citadel access."]));
}

// Fetch latest 50 logs with admin details
$sql = "
    SELECT l.*, a.FirstName, a.LastName 
    FROM system_logs l
    JOIN admins a ON a.AdminID = l.AdminID
    ORDER BY l.CreatedAt DESC
    LIMIT 50
";

$res = $conn->query($sql);
$logs = [];

if ($res) {
    while ($row = $res->fetch_assoc()) {
        $logs[] = $row;
    }
    echo json_encode(["status" => "success", "data" => $logs]);
} else {
    echo json_encode(["status" => "error", "message" => "Failed to fetch logs: " . $conn->error]);
}

$conn->close();
?>
