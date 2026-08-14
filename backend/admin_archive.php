<?php
// admin_archive.php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

include 'db_connect.php';

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET' && isset($_GET['exportCsv'])) {
    $adminId = $_GET['adminId'] ?? null;
    $roleId = $_GET['roleId'] ?? null;
    
    if ($adminId === null || $adminId === '') {
        die("Unauthorized Citadel access.");
    }
    
    // Strand name lookup for official reporting
    $strandMapping = [
        'STEM' => 'Science, Technology, Engineering, and Mathematics',
        'ABM' => 'Accountancy, Business, and Management',
        'HUMSS' => 'Humanities and Social Sciences',
        'GAS' => 'General Academic Strand',
        'TVL' => 'Technical-Vocational-Livelihood',
        'ICT' => 'Information and Communication Technology',
        'Arts and Design' => 'Arts and Design Track'
    ];
    
    // We export the completed assessments for Archiving / Analysis
    // Sub-join on personal_information ensures we only get the latest profile per student
    $res = $conn->query("
        SELECT a.AssessmentID, a.StudentID, s.FirstName, s.LastName, 
               pi.Strand, pi.GradeLevel,
               r.PrimaryType, r.SecondaryType, r.TertiaryType,
               r.R_Score, r.I_Score, r.A_Score, r.S_Score, r.E_Score, r.C_Score,
               rse.Score as RSES_Score, rse.Level as RSES_Level,
               cdses.TotalScore as CDSES_Score, cdses.SelfEfficacyLevel as CDSES_Level,
               a.AgreedToDisclaimer,
               a.Status, 
               DATE_FORMAT(a.SubmittedAt, '%Y-%m-%d %H:%i:%s') as DateSubmitted,
               (SELECT GROUP_CONCAT(c.CourseName SEPARATOR '; ') 
                FROM riasec_recommendations rec 
                JOIN riasec_courses c ON c.CourseID = rec.CourseID 
                WHERE rec.ResultID = r.ResultID 
                ORDER BY rec.Rank ASC) as RecommendedCourses
        FROM assessments a
        JOIN students s ON s.StudentID = a.StudentID
        LEFT JOIN (
            SELECT pi1.* FROM personal_information pi1
            INNER JOIN (
                SELECT MAX(PI_ID) as max_id FROM personal_information GROUP BY StudentID
            ) pi2 ON pi1.PI_ID = pi2.max_id
        ) pi ON pi.StudentID = s.StudentID
        LEFT JOIN assessment_results r ON r.AssessmentID = a.AssessmentID
        LEFT JOIN rse_results rse ON rse.AssessmentID = a.AssessmentID
        LEFT JOIN cdses_results cdses ON cdses.AssessmentID = a.AssessmentID
        WHERE a.Status != 'in_progress'
        ORDER BY a.SubmittedAt DESC
    ");
    
    $filename = "citadel_assessment_export_" . date('Y-m-d') . ".csv";
    
    // Stream direct CSV response
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename='. $filename);
    
    $output = fopen('php://output', 'w');
    
    // Add UTF-8 BOM to force Excel to read the file with correct encoding (fixes characters like ñ)
    fwrite($output, "\xEF\xBB\xBF");
    
    fputcsv($output, array(
        'Assessment ID', 
        'Student ID', 
        'First Name', 
        'Last Name', 
        'Strand', 
        'Grade Level', 
        'Recommended Courses', 
        'Primary Type', 
        'Secondary Type', 
        'Tertiary Type', 
        'R Score',
        'I Score',
        'A Score',
        'S Score',
        'E Score',
        'C Score',
        'RSES Score',
        'RSES Level',
        'CDSES-SF Score',
        'CDSES-SF Level',
        'Disclaimer Agreed',
        'Status', 
        'Date Submitted'
    ));
    
    while ($row = $res->fetch_assoc()) {
        $strand = $row['Strand'] ?? 'Unknown';
        if (isset($strandMapping[$strand])) {
            $strand = $strandMapping[$strand];
        }
        
        $disclaimerAgreed = ($row['AgreedToDisclaimer'] == 1 || $row['AgreedToDisclaimer'] === '1' || $row['AgreedToDisclaimer'] === true)
            ? 'Yes (Agreed)'
            : 'No';
        
        fputcsv($output, [
            $row['AssessmentID'],
            $row['StudentID'],
            $row['FirstName'],
            $row['LastName'],
            $strand,
            $row['GradeLevel'],
            $row['RecommendedCourses'] ?? 'N/A',
            $row['PrimaryType'] ?? 'N/A',
            $row['SecondaryType'] ?? 'N/A',
            $row['TertiaryType'] ?? 'N/A',
            $row['R_Score'] ?? 0,
            $row['I_Score'] ?? 0,
            $row['A_Score'] ?? 0,
            $row['S_Score'] ?? 0,
            $row['E_Score'] ?? 0,
            $row['C_Score'] ?? 0,
            $row['RSES_Score'] ?? 'N/A',
            $row['RSES_Level'] ?? 'N/A',
            $row['CDSES_Score'] ?? 'N/A',
            $row['CDSES_Level'] ?? 'N/A',
            $disclaimerAgreed,
            $row['Status'],
            $row['DateSubmitted']
        ]);
    }
    fclose($output);
    exit();
}

$conn->close();
?>
