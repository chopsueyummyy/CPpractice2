<?php
require_once 'db_connect.php';

header("Content-Type: application/json");

// Disable strict key check for dump importing
mysqli_query($conn, "SET SESSION sql_require_primary_key = 0");

$sqlFile = __DIR__ . '/../assets/riasec_db.sql';
if (!file_exists($sqlFile)) {
    $sqlFile = __DIR__ . '/riasec_db.sql';
}

if (!file_exists($sqlFile)) {
    die(json_encode(["status" => "error", "message" => "riasec_db.sql file not found."]));
}

$sql = file_get_contents($sqlFile);

if ($conn->multi_query($sql)) {
    do {
        if ($result = $conn->store_result()) {
            $result->free();
        }
    } while ($conn->next_result());
    
    echo json_encode([
        "status" => "success",
        "message" => "Database tables and catalog initialized successfully!"
    ]);
} else {
    echo json_encode([
        "status" => "error",
        "message" => "Error executing schema: " . $conn->error
    ]);
}
?>
