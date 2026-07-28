<?php
error_reporting(E_ALL);
ini_set('display_errors', 0);
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        echo json_encode(["status" => "error", "message" => "PHP Fatal: " . $error['message'] . " on line " . $error['line']]);
    }
});

include 'db_connect.php';

$data         = json_decode(file_get_contents("php://input"), true);
$assessmentId = (int)($data['assessmentId'] ?? 0);
$answers      = $data['answers'] ?? []; // RIASEC answers
$rseAnswers   = $data['rseAnswers'] ?? [];
$mbiAnswers   = $data['mbiAnswers'] ?? [];

$rseSum = 20; // Default fallback raw sum
$mbiSum = 30; // Default fallback raw sum

if (empty($assessmentId) || empty($answers)) {
    echo json_encode(["status" => "error", "message" => "Missing assessmentId or RIASEC answers"]);
    exit();
}

// 1. SCORING RIASEC (Agree = 1, Disagree = 0)
// Max score is the number of questions per category
$maxScores = ['R' => 9, 'I' => 7, 'A' => 6, 'S' => 6, 'E' => 7, 'C' => 7];
$rawScores = ['R' => 0,  'I' => 0,  'A' => 0,  'S' => 0,  'E' => 0,  'C' => 0];

foreach ($answers as $answer) {
    $questionId = (int)$answer['questionId'];
    $score      = max(0, min(1, (int)$answer['score'])); // Clamp score to 0 or 1 (binary)

    $q = $conn->prepare("SELECT RIASECCategory FROM riasec_questions WHERE QuestionID = ?");
    $q->bind_param("i", $questionId);
    $q->execute();
    $qResult  = $q->get_result()->fetch_assoc();
    $category = $qResult['RIASECCategory'] ?? null;
    if (!$category) continue;

    $rawScores[$category] += $score;

    $ins = $conn->prepare("INSERT INTO assessment_answers (AssessmentID, QuestionID, Score) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE Score=VALUES(Score)");
    $ins->bind_param("iii", $assessmentId, $questionId, $score);
    $ins->execute();
}

$percentages = [];
foreach ($rawScores as $cat => $score) {
    $percentages[$cat] = round(($score / $maxScores[$cat]) * 100, 2);
}

arsort($percentages);
$top3          = array_keys(array_slice($percentages, 0, 3, true));
$primaryType   = $top3[0] ?? null;
$secondaryType = $top3[1] ?? null;
$tertiaryType  = $top3[2] ?? null;

$rScore = (int)$rawScores['R']; $iScore = (int)$rawScores['I'];
$aScore = (int)$rawScores['A']; $sScore = (int)$rawScores['S'];
$eScore = (int)$rawScores['E']; $cScore = (int)$rawScores['C'];

$rPct = (float)$percentages['R']; $iPct = (float)$percentages['I'];
$aPct = (float)$percentages['A']; $sPct = (float)$percentages['S'];
$ePct = (float)$percentages['E']; $cPct = (float)$percentages['C'];

$res = $conn->prepare("
    INSERT INTO assessment_results
    (AssessmentID, R_Score, I_Score, A_Score, S_Score, E_Score, C_Score,
    R_Percentage, I_Percentage, A_Percentage, S_Percentage, E_Percentage, C_Percentage,
    PrimaryType, SecondaryType, TertiaryType)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
    R_Score=VALUES(R_Score), I_Score=VALUES(I_Score), A_Score=VALUES(A_Score), 
    S_Score=VALUES(S_Score), E_Score=VALUES(E_Score), C_Score=VALUES(C_Score),
    R_Percentage=VALUES(R_Percentage), I_Percentage=VALUES(I_Percentage), A_Percentage=VALUES(A_Percentage),
    S_Percentage=VALUES(S_Percentage), E_Percentage=VALUES(E_Percentage), C_Percentage=VALUES(C_Percentage),
    PrimaryType=VALUES(PrimaryType), SecondaryType=VALUES(SecondaryType), TertiaryType=VALUES(TertiaryType)
");
$res->bind_param(
    "iiiiiiiddddddsss",
    $assessmentId,
    $rScore, $iScore, $aScore, $sScore, $eScore, $cScore,
    $rPct,   $iPct,   $aPct,   $sPct,   $ePct,   $cPct,
    $primaryType, $secondaryType, $tertiaryType
);

if (!$res->execute()) {
    echo json_encode(["status" => "error", "message" => "Failed to save RIASEC results: " . $res->error]);
    exit();
}
$resultId = (int)$conn->insert_id;


// Legacy RIASEC recommendations loop removed. Predictions are generated below using the XGBoost & SHAP model.


// 2. SCORING ROSENBERG SELF-ESTEEM SCALE (RSE)
if (!empty($rseAnswers)) {
    // Delete old answers if exist
    $conn->query("DELETE FROM rse_answers WHERE AssessmentID = $assessmentId");
    
    $rseScore = 0;
    $rseSum = 0; // Reset default fallback
    foreach ($rseAnswers as $ans) {
        $qId = (int)$ans['questionId'];
        $scoreVal = (int)$ans['score']; // 1 to 4: 1=Strongly Agree, 2=Agree, 3=Disagree, 4=Strongly Disagree

        // Accumulate raw sum for ML model
        $rseSum += $scoreVal;

        // Check if question is negative
        $rseQ = $conn->prepare("SELECT IsNegative FROM rse_questions WHERE QuestionID = ?");
        $rseQ->bind_param("i", $qId);
        $rseQ->execute();
        $rseQRes = $rseQ->get_result()->fetch_assoc();
        $isNegative = (int)($rseQRes['IsNegative'] ?? 0);

        // Convert options to scores (0-3 scale):
        // Positive: 1 (Strongly Agree) -> 3, 2 (Agree) -> 2, 3 (Disagree) -> 1, 4 (Strongly Disagree) -> 0
        // Negative: 1 (Strongly Agree) -> 0, 2 (Agree) -> 1, 3 (Disagree) -> 2, 4 (Strongly Disagree) -> 3
        if ($isNegative === 0) {
            $convertedScore = 4 - $scoreVal;
        } else {
            $convertedScore = $scoreVal - 1;
        }
        $rseScore += $convertedScore;

        $insRse = $conn->prepare("INSERT INTO rse_answers (AssessmentID, QuestionID, Score) VALUES (?, ?, ?)");
        $insRse->bind_param("iii", $assessmentId, $qId, $scoreVal);
        $insRse->execute();
    }

    $rseLevel = ($rseScore < 15) ? 'Low Self-Esteem' : 'Normal Self-Esteem';
    $rseRes = $conn->prepare("
        INSERT INTO rse_results (AssessmentID, Score, Level)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE Score=VALUES(Score), Level=VALUES(Level)
    ");
    $rseRes->bind_param("iis", $assessmentId, $rseScore, $rseLevel);
    $rseRes->execute();
}

// 3. SCORING MASLACH BURNOUT INVENTORY (MBI-SS)
if (!empty($mbiAnswers)) {
    // Delete old answers if exist
    $conn->query("DELETE FROM mbi_answers WHERE AssessmentID = $assessmentId");

    $exSum = 0; $exCount = 0;
    $cySum = 0; $cyCount = 0;
    $efSum = 0; $efCount = 0;
    $mbiSum = 0; // Reset default fallback

    foreach ($mbiAnswers as $ans) {
        $qId = (int)$ans['questionId'];
        $scoreVal = (int)$ans['score']; // 0 to 6

        // Accumulate raw sum for ML model
        $mbiSum += $scoreVal;

        // Check subscale
        $mbiQ = $conn->prepare("SELECT Subscale FROM mbi_questions WHERE QuestionID = ?");
        $mbiQ->bind_param("i", $qId);
        $mbiQ->execute();
        $mbiQRes = $mbiQ->get_result()->fetch_assoc();
        $subscale = $mbiQRes['Subscale'] ?? '';

        if ($subscale === 'EX') {
            $exSum += $scoreVal;
            $exCount++;
        } elseif ($subscale === 'CY') {
            $cySum += $scoreVal;
            $cyCount++;
        } elseif ($subscale === 'EF') {
            $efSum += $scoreVal;
            $efCount++;
        }

        $insMbi = $conn->prepare("INSERT INTO mbi_answers (AssessmentID, QuestionID, Score) VALUES (?, ?, ?)");
        $insMbi->bind_param("iii", $assessmentId, $qId, $scoreVal);
        $insMbi->execute();
    }

    $exMean = $exCount > 0 ? round($exSum / $exCount, 2) : 0.00;
    $cyMean = $cyCount > 0 ? round($cySum / $cyCount, 2) : 0.00;
    $efMean = $efCount > 0 ? round($efSum / $efCount, 2) : 0.00;

    // EX: Low < 2.00, Moderate 2.00-2.80, High > 2.80
    $exLevel = 'Low';
    if ($exMean > 2.80) {
        $exLevel = 'High';
    } elseif ($exMean >= 2.00) {
        $exLevel = 'Moderate';
    }

    // CY: Low < 0.50, Moderate 0.50-1.50, High > 1.50
    $cyLevel = 'Low';
    if ($cyMean > 1.50) {
        $cyLevel = 'High';
    } elseif ($cyMean >= 0.50) {
        $cyLevel = 'Moderate';
    }

    // EF: Low risk > 4.50, Moderate risk 3.83-4.50, High risk < 3.83
    $efLevel = 'Low';
    if ($efMean < 3.83) {
        $efLevel = 'High';
    } elseif ($efMean <= 4.50) {
        $efLevel = 'Moderate';
    }

    // Overall Burnout Status
    if ($exLevel === 'High' && $cyLevel === 'High' && $efLevel === 'High') {
        $burnoutStatus = 'High Burnout Risk';
    } elseif ($exLevel === 'Low' && $cyLevel === 'Low' && $efLevel === 'Low') {
        $burnoutStatus = 'Low Burnout Risk';
    } else {
        $burnoutStatus = 'Moderate Burnout Risk';
    }

    $mbiRes = $conn->prepare("
        INSERT INTO mbi_results (AssessmentID, EX_Score, CY_Score, EF_Score, EX_Level, CY_Level, EF_Level, BurnoutStatus)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE 
            EX_Score=VALUES(EX_Score), CY_Score=VALUES(CY_Score), EF_Score=VALUES(EF_Score),
            EX_Level=VALUES(EX_Level), CY_Level=VALUES(CY_Level), EF_Level=VALUES(EF_Level),
            BurnoutStatus=VALUES(BurnoutStatus)
    ");
    $mbiRes->bind_param("idddssss", $assessmentId, $exMean, $cyMean, $efMean, $exLevel, $cyLevel, $efLevel, $burnoutStatus);
    $mbiRes->execute();
}

// 4. GENERATING RECOMMENDATIONS VIA XGBOOST & SHAP MODEL
// Fetch student's SHS strand
$stmt = $conn->prepare("SELECT StudentID FROM assessments WHERE AssessmentID = ?");
$stmt->bind_param("i", $assessmentId);
$stmt->execute();
$asm = $stmt->get_result()->fetch_assoc();
$studentId = $asm['StudentID'] ?? 0;

$pi = $conn->prepare("SELECT Strand FROM personal_information WHERE StudentID = ? ORDER BY CreatedAt DESC LIMIT 1");
$pi->bind_param("i", $studentId);
$pi->execute();
$piRow = $pi->get_result()->fetch_assoc();
$strand = $piRow['Strand'] ?? 'STEM';

// Map RIASEC Agree/Disagree (0/1) raw scores to original Likert (1-5) scale sums
$payload = [
    "R" => $rawScores['R'] * 4 + 9,
    "I" => $rawScores['I'] * 4 + 7,
    "A" => $rawScores['A'] * 4 + 6,
    "S" => $rawScores['S'] * 4 + 6,
    "E" => $rawScores['E'] * 4 + 7,
    "C" => $rawScores['C'] * 4 + 7,
    "RSES" => $rseSum,
    "MBI" => $mbiSum,
    "Strand" => $strand
];

// Clear previous recommendations for this ResultID if any
$conn->query("DELETE FROM riasec_recommendations WHERE ResultID = $resultId");

$recommendationsSaved = false;

try {
    $url = 'http://host.docker.internal:8001/recommend';
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: application/json'));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 5); // 5 second timeout
    $output = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode === 200 && $output) {
        $response = json_decode($output, true);
        if (isset($response['status']) && $response['status'] === 'success') {
            foreach ($response['recommendations'] as $rec) {
                $cCode = $rec['course_code'];
                $mScore = (float)($rec['probability'] * 100);
                $explanation = $rec['explanation'];
                $rank = (int)$rec['rank'];
                
                // Find CourseID from the CourseCode
                $cStmt = $conn->prepare("SELECT CourseID FROM riasec_courses WHERE CourseCode = ? LIMIT 1");
                $cStmt->bind_param("s", $cCode);
                $cStmt->execute();
                $cRow = $cStmt->get_result()->fetch_assoc();
                
                if ($cRow) {
                    $courseId = (int)$cRow['CourseID'];
                    $recStmt = $conn->prepare("
                        INSERT INTO riasec_recommendations (ResultID, CourseID, MatchScore, Explanation, `Rank`)
                        VALUES (?, ?, ?, ?, ?)
                    ");
                    $recStmt->bind_param("iidsi", $resultId, $courseId, $mScore, $explanation, $rank);
                    $recStmt->execute();
                }
            }
            $recommendationsSaved = true;
        }
    }
} catch (Exception $e) {
    // Suppress and fallback
}

// Fallback: If recommendation microservice fails, generate safe default recommendations using RIASEC top categories
if (!$recommendationsSaved) {
    $rank = 1;
    foreach ($top3 as $type) {
        $courses = $conn->prepare("
            SELECT CourseID, Description FROM riasec_courses
            WHERE RIASECCategory = ? ORDER BY RAND() LIMIT 1
        ");
        $courses->bind_param("s", $type);
        $courses->execute();
        $courseResult = $courses->get_result();

        while ($course = $courseResult->fetch_assoc()) {
            if ($rank > 3) break;
            
            $matchScore = (float)$percentages[$type];
            
            // Detailed explanation fallback mimicking SHAP
            $interestName = [
                'R' => 'Realistic (practical, hands-on activities)',
                'I' => 'Investigative (analytical, problem-solving, and scientific thinking)',
                'A' => 'Artistic (creative expression, design, and innovation)',
                'S' => 'Social (communication, helping others, and social interaction)',
                'E' => 'Enterprising (leadership, entrepreneurship, and persuasive communication)',
                'C' => 'Conventional (detail-oriented, organized, and structured approach to tasks)'
            ][$type] ?? $type;
            
            $explanation = "Your senior high school academic strand ($strand) provides a highly compatible foundation for this program. Your strong interest in $interestName aligns perfectly with this field.";
            if ($rseSum >= 15) {
                $explanation .= " Your positive self-esteem and confidence in your academic capabilities support your readiness to excel in this course.";
            }

            $recStmt = $conn->prepare("
                INSERT INTO riasec_recommendations (ResultID, CourseID, MatchScore, Explanation, `Rank`)
                VALUES (?, ?, ?, ?, ?)
            ");
            $recStmt->bind_param("iidsi", $resultId, $course['CourseID'], $matchScore, $explanation, $rank);
            $recStmt->execute();
            $rank++;
        }
    }
}

$upd = $conn->prepare("UPDATE assessments SET Status = 'pending_review', SubmittedAt = NOW() WHERE AssessmentID = ?");
$upd->bind_param("i", $assessmentId);
$upd->execute();

$cls = $conn->prepare("UPDATE live_sessions SET IsActive = FALSE WHERE AssessmentID = ?");
$cls->bind_param("i", $assessmentId);
$cls->execute();

echo json_encode([
    "status"        => "success",
    "resultId"      => $resultId,
    "primaryType"   => $primaryType,
    "secondaryType" => $secondaryType,
    "tertiaryType"  => $tertiaryType,
    "percentages"   => $percentages
]);

$conn->close();
?>
