<?php
// cors.php - Restrict cross-origin headers to local development environments
if (isset($_SERVER['HTTP_ORIGIN'])) {
    $origin = $_SERVER['HTTP_ORIGIN'];
    if (preg_match('/^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/', $origin)) {
        header("Access-Control-Allow-Origin: $origin");
    }
}
header("Access-Control-Allow-Credentials: true");
?>
