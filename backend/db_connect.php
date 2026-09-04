<?php
// Quiet Shield: Prevent PHP from sending HTML errors that break the Flutter JSON
// Production Shield: Optimized for Flutter JSON communication
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(0);
date_default_timezone_set('Asia/Manila');
header("Content-Type: application/json"); 

// --- STEP 1: LOAD .ENV MANUALLY ---
function loadEnv($path) {
    if (!file_exists($path)) return;
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as $line) {
        if (strpos(trim($line), '#') === 0) continue;
        list($name, $value) = explode('=', $line, 2);
        putenv(trim($name) . "=" . trim($value));
    }
}
loadEnv(__DIR__ . '/.env');

// Disable mysqli throwing exceptions (we handle errors with die() for the Flutter app)
mysqli_report(MYSQLI_REPORT_OFF);

// Helper to get environment variables from any source (DigitalOcean can vary)
function get_env_var($key, $default) {
    $val = getenv($key);
    if ($val === false) $val = $_ENV[$key] ?? null;
    if ($val === null)  $val = $_SERVER[$key] ?? null;
    return ($val !== null && $val !== "") ? $val : $default;
}

$host = get_env_var('DB_HOST', "db");
$db   = get_env_var('DB_NAME', "riasec_db");
$user = get_env_var('DB_USER', "riasec_user");
$pass = get_env_var('DB_PASS', "riasec_password");
$port = get_env_var('DB_PORT', "3306");

$conn = mysqli_init();
if (!$conn) {
    die(json_encode(["status" => "error", "message" => "mysqli_init failed"]));
}

// DigitalOcean managed databases REQUIRE SSL.
@mysqli_ssl_set($conn, NULL, NULL, NULL, NULL, NULL);

if (!@mysqli_real_connect($conn, $host, $user, $pass, $db, $port, NULL, MYSQLI_CLIENT_SSL)) {
    $error = mysqli_connect_error();
    die(json_encode([
        "status" => "error",
        "message" => "Connection Error: $error. (Host: $host, Port: $port). Please check your DO Trusted Sources and VPC settings."
    ]));
}

@mysqli_set_charset($conn, "utf8mb4");
@mysqli_query($conn, "SET time_zone = '+08:00'");
?>
