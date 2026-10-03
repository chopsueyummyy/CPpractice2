<?php
require_once 'db_connect.php';

header("Content-Type: application/json");

// Query all tables and columns in the active database
$sql = "
    SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_KEY
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
    ORDER BY TABLE_NAME, ORDINAL_POSITION
";

$result = $conn->query($sql);

$schema = [];
if ($result) {
    while ($row = $result->fetch_assoc()) {
        $tableName = $row['TABLE_NAME'];
        if (!isset($schema[$tableName])) {
            $schema[$tableName] = [];
        }
        $schema[$tableName][] = [
            "column"  => $row['COLUMN_NAME'],
            "type"    => $row['COLUMN_TYPE'],
            "null"    => $row['IS_NULLABLE'],
            "default" => $row['COLUMN_DEFAULT'],
            "key"     => $row['COLUMN_KEY']
        ];
    }
}

echo json_encode([
    "status" => "success",
    "total_tables" => count($schema),
    "tables" => $schema
], JSON_PRETTY_PRINT);
?>
