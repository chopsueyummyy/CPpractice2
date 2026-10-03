<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

try {
    require_once 'db_connect.php';

    $data      = json_decode(file_get_contents("php://input"), true);
    $studentId = $data['studentId'] ?? '';
    $piId      = $data['piId']      ?? '';
    $agreed    = $data['agreed']    ?? true; // Default to true if invoked from instructions screen

    if (empty($studentId)) {
        echo json_encode(["status" => "error", "message" => "Student ID is required."]);
        exit();
    }

    // Auto-fallback 1: If PI_ID is missing or zero, try to find existing profile
    if (empty($piId) || (int)$piId === 0) {
        $piCheck = $conn->prepare("SELECT PI_ID FROM personal_information WHERE StudentID = ? ORDER BY PI_ID DESC LIMIT 1");
        if ($piCheck) {
            $piCheck->bind_param("s", $studentId);
            $piCheck->execute();
            $res = $piCheck->get_result();
            if ($res && $res->num_rows > 0) {
                $piId = (int)$res->fetch_assoc()['PI_ID'];
            }
        }
    }

    // Auto-fallback 2: If still no PI_ID, auto-create a default personal_information record
    if (empty($piId) || (int)$piId === 0) {
        $stCheck = $conn->prepare("SELECT FirstName, LastName FROM students WHERE StudentID = ? LIMIT 1");
        $fn = "Student";
        $ln = $studentId;
        if ($stCheck) {
            $stCheck->bind_param("s", $studentId);
            $stCheck->execute();
            $stRes = $stCheck->get_result();
            if ($stRes && $stRes->num_rows > 0) {
                $stData = $stRes->fetch_assoc();
                $fn = $stData['FirstName'] ?: "Student";
                $ln = $stData['LastName'] ?: $studentId;
            }
        }

        $insPi = $conn->prepare("INSERT INTO personal_information (StudentID, FirstName, LastName, Birthdate, Age, Gender, Strand, GradeLevel) VALUES (?, ?, ?, '2005-01-01', 18, 'Unspecified', 'STEM', 'Grade 12')");
        if ($insPi) {
            $insPi->bind_param("sss", $studentId, $fn, $ln);
            if ($insPi->execute()) {
                $piId = $conn->insert_id;
            }
        }
    }

    if (empty($piId)) {
        echo json_encode(["status" => "error", "message" => "Could not initialize personal information profile."]);
        exit();
    }

    // Check for active or in-progress assessment to resume safely
    $check = $conn->prepare("SELECT AssessmentID, Status FROM assessments WHERE StudentID = ? AND Status IN ('in_progress', 'pending_review', 'approved') ORDER BY StartedAt DESC LIMIT 1");
    $check->bind_param("s", $studentId);
    $check->execute();
    $guardianResult = $check->get_result();

    if ($guardianResult && $guardianResult->num_rows > 0) {
        $existing = $guardianResult->fetch_assoc();
        if ($existing['Status'] === 'in_progress') {
            echo json_encode(["status" => "resume", "assessmentId" => (int)$existing['AssessmentID']]);
            exit();
        } else {
            echo json_encode(["status" => "error", "message" => "You already have a completed or pending assessment."]);
            exit();
        }
    }

    $agreedVal = (!empty($agreed) && $agreed !== false && $agreed !== 'false') ? 1 : 0;

    $stmt = $conn->prepare("INSERT INTO assessments (StudentID, PI_ID, Status, AgreedToDisclaimer) VALUES (?, ?, 'in_progress', ?)");
    if (!$stmt) {
        $stmt = $conn->prepare("INSERT INTO assessments (StudentID, PI_ID, Status) VALUES (?, ?, 'in_progress')");
        if (!$stmt) {
            echo json_encode(["status" => "error", "message" => "SQL Prepare Error: " . $conn->error]);
            exit();
        }
        $stmt->bind_param("si", $studentId, $piId);
    } else {
        $stmt->bind_param("sii", $studentId, $piId, $agreedVal);
    }

    if ($stmt->execute()) {
        $assessmentId = $conn->insert_id;

        $live = $conn->prepare("INSERT INTO live_sessions (AssessmentID, StudentID, PI_ID, CurrentQuestion, TotalQuestions, IsActive) VALUES (?, ?, ?, 1, 77, TRUE)");
        if ($live) {
            $live->bind_param("isi", $assessmentId, $studentId, $piId);
            @$live->execute();
        }

        echo json_encode(["status" => "success", "assessmentId" => $assessmentId]);
    } else {
        echo json_encode(["status" => "error", "message" => "Failed to create assessment record: " . $conn->error]);
    }

    $conn->close();
} catch (Exception $e) {
    echo json_encode(["status" => "error", "message" => "Server Error: " . $e->getMessage()]);
}
?>
