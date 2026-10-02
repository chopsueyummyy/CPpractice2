<?php
// populate_cluster_cache.php - One-time cache migration script for XGBoost recommendations
error_reporting(E_ALL);
ini_set('display_errors', 1);
header("Content-Type: application/json");
require_once 'db_connect.php';

// 1. Safely add ClusterRecommendations column if it doesn't exist
$checkCol = $conn->query("SHOW COLUMNS FROM assessment_results LIKE 'ClusterRecommendations'");
if ($checkCol && $checkCol->num_rows === 0) {
    $conn->query("ALTER TABLE assessment_results ADD COLUMN ClusterRecommendations LONGTEXT NULL");
}

// 2. Fetch all completed/pending assessments
$query = "
    SELECT
        a.AssessmentID,
        a.StudentID,
        pi.Strand,
        ar.PrimaryType, ar.SecondaryType, ar.TertiaryType,
        ar.R_Percentage, ar.I_Percentage, ar.A_Percentage,
        ar.S_Percentage, ar.E_Percentage, ar.C_Percentage,
        rse.Score as RSE_Score,
        cdses.TotalScore as CDSES_TotalScore
    FROM assessments a
    JOIN students s ON s.StudentID = a.StudentID
    LEFT JOIN (
        SELECT pi1.* FROM personal_information pi1
        INNER JOIN (
            SELECT MAX(PI_ID) as max_id FROM personal_information GROUP BY StudentID
        ) pi2 ON pi1.PI_ID = pi2.max_id
    ) pi ON pi.StudentID = s.StudentID
    LEFT JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
    LEFT JOIN rse_results rse ON rse.AssessmentID = a.AssessmentID
    LEFT JOIN cdses_results cdses ON cdses.AssessmentID = a.AssessmentID
    WHERE a.Status != 'in_progress'
";

$res = $conn->query($query);
if (!$res) {
    echo json_encode(["status" => "error", "message" => $conn->error]);
    exit();
}

$updatedCount = 0;
$errors = [];

$predictScript = __DIR__ . '/predict_shap.py';
$descriptors = [
    0 => ["pipe", "r"],
    1 => ["pipe", "w"],
    2 => ["pipe", "w"]
];

while ($row = $res->fetch_assoc()) {
    $assessmentId = (int)$row['AssessmentID'];
    
    $inputPayload = json_encode([
        'SHS_Strand' => $row['Strand'] ?? 'STEM',
        'Realistic_Score' => (float)($row['R_Percentage'] ?? 0),
        'Investigative_Score' => (float)($row['I_Percentage'] ?? 0),
        'Artistic_Score' => (float)($row['A_Percentage'] ?? 0),
        'Social_Score' => (float)($row['S_Percentage'] ?? 0),
        'Enterprising_Score' => (float)($row['E_Percentage'] ?? 0),
        'Conventional_Score' => (float)($row['C_Percentage'] ?? 0),
        'RSE_Score_Likert' => isset($row['RSE_Score']) ? (float)$row['RSE_Score'] : 25.0,
        'CDSES_Total_Score' => isset($row['CDSES_TotalScore']) ? (float)$row['CDSES_TotalScore'] : 75.0
    ]);

    $cmd = "python3 " . escapeshellarg($predictScript);
    $process = proc_open($cmd, $descriptors, $pipes);

    if (is_resource($process)) {
        fwrite($pipes[0], $inputPayload);
        fclose($pipes[0]);

        $output = stream_get_contents($pipes[1]);
        fclose($pipes[1]);
        fclose($pipes[2]);
        proc_close($process);

        $mlData = json_decode($output, true);
        if (isset($mlData['status']) && $mlData['status'] === 'success') {
            $clusterRecsJson = json_encode($mlData['recommendations']);
            
            $upd = $conn->prepare("UPDATE assessment_results SET ClusterRecommendations = ? WHERE AssessmentID = ?");
            $upd->bind_param("si", $clusterRecsJson, $assessmentId);
            if ($upd->execute()) {
                $updatedCount++;
            } else {
                $errors[] = "Failed to update AssessmentID $assessmentId: " . $upd->error;
            }
            $upd->close();
        } else {
            $errors[] = "ML script failed for AssessmentID $assessmentId: " . ($output ?: 'No output');
        }
    }
}

echo json_encode([
    "status" => "success",
    "updatedCount" => $updatedCount,
    "errors" => $errors
]);

$conn->close();
?>
