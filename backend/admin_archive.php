<?php
// admin_archive.php
header("Content-Type: application/json");
require_once 'cors.php';
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(200); exit(); }

require_once 'db_connect.php';

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

    // Filter Parameters
    $idsFilter          = $_GET['ids'] ?? '';
    $statusFilter       = $_GET['status'] ?? 'all';
    $strandFilter       = $_GET['strand'] ?? 'all';
    $gradeLevelFilter   = $_GET['gradeLevel'] ?? 'all';
    $dominantTypeFilter = $_GET['dominantType'] ?? 'all';
    $rseLevelFilter     = $_GET['rseLevel'] ?? 'all';
    $cdsesLevelFilter   = $_GET['cdsesLevel'] ?? 'all';
    $searchFilter       = trim($_GET['search'] ?? '');
    $dateFromFilter     = $_GET['dateFrom'] ?? '';
    $dateToFilter       = $_GET['dateTo'] ?? '';

    $whereClauses = ["a.Status != 'in_progress'"];
    $params = [];
    $types = "";

    if (!empty($idsFilter)) {
        $rawIds = explode(',', $idsFilter);
        $cleanIds = array_map('intval', array_filter($rawIds, 'is_numeric'));
        if (!empty($cleanIds)) {
            $whereClauses[] = "a.AssessmentID IN (" . implode(',', $cleanIds) . ")";
        }
    }

    if (!empty($statusFilter) && $statusFilter !== 'all') {
        if ($statusFilter === 'declined' || $statusFilter === 'rejected') {
            $whereClauses[] = "(a.Status = 'declined' OR a.Status = 'rejected')";
        } else {
            $whereClauses[] = "a.Status = ?";
            $params[] = $statusFilter;
            $types .= "s";
        }
    }

    if (!empty($strandFilter) && $strandFilter !== 'all') {
        $whereClauses[] = "pi.Strand LIKE ?";
        $params[] = "%" . $strandFilter . "%";
        $types .= "s";
    }

    if (!empty($gradeLevelFilter) && $gradeLevelFilter !== 'all') {
        $whereClauses[] = "pi.GradeLevel LIKE ?";
        $params[] = "%" . $gradeLevelFilter . "%";
        $types .= "s";
    }

    if (!empty($dominantTypeFilter) && $dominantTypeFilter !== 'all') {
        $whereClauses[] = "r.PrimaryType = ?";
        $params[] = $dominantTypeFilter;
        $types .= "s";
    }

    if (!empty($rseLevelFilter) && $rseLevelFilter !== 'all') {
        $whereClauses[] = "rse.Level = ?";
        $params[] = $rseLevelFilter;
        $types .= "s";
    }

    if (!empty($cdsesLevelFilter) && $cdsesLevelFilter !== 'all') {
        $whereClauses[] = "cdses.SelfEfficacyLevel = ?";
        $params[] = $cdsesLevelFilter;
        $types .= "s";
    }

    if (!empty($dateFromFilter)) {
        $whereClauses[] = "DATE(a.SubmittedAt) >= ?";
        $params[] = $dateFromFilter;
        $types .= "s";
    }

    if (!empty($dateToFilter)) {
        $whereClauses[] = "DATE(a.SubmittedAt) <= ?";
        $params[] = $dateToFilter;
        $types .= "s";
    }

    if (!empty($searchFilter)) {
        $whereClauses[] = "(s.StudentID LIKE ? OR pi.FirstName LIKE ? OR pi.LastName LIKE ? OR CONCAT(pi.FirstName, ' ', pi.LastName) LIKE ?)";
        $searchLike = "%" . $searchFilter . "%";
        $params[] = $searchLike;
        $params[] = $searchLike;
        $params[] = $searchLike;
        $params[] = $searchLike;
        $types .= "ssss";
    }

    $whereSql = "WHERE " . implode(" AND ", $whereClauses);

    $sql = "
        SELECT a.AssessmentID, a.StudentID, pi.FirstName, pi.LastName, 
               pi.Strand, pi.GradeLevel,
               r.PrimaryType, r.SecondaryType, r.TertiaryType,
               r.R_Score, r.I_Score, r.A_Score, r.S_Score, r.E_Score, r.C_Score,
               rse.Score as RSES_Score, rse.Level as RSES_Level,
               cdses.TotalScore as CDSES_Score, cdses.SelfEfficacyLevel as CDSES_Level,
               a.AgreedToDisclaimer,
               a.Status, 
               DATE_FORMAT(a.SubmittedAt, '%Y-%m-%d %H:%i:%s') as DateSubmitted,
               r.ClusterRecommendations
        FROM assessments a
        JOIN students s ON s.StudentID = a.StudentID
        LEFT JOIN personal_information pi ON pi.PI_ID = a.PI_ID
        LEFT JOIN assessment_results r ON r.AssessmentID = a.AssessmentID
        LEFT JOIN rse_results rse ON rse.AssessmentID = a.AssessmentID
        LEFT JOIN cdses_results cdses ON cdses.AssessmentID = a.AssessmentID
        $whereSql
        ORDER BY a.SubmittedAt DESC
    ";

    if (!empty($params)) {
        $stmt = $conn->prepare($sql);
        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $res = $stmt->get_result();
    } else {
        $res = $conn->query($sql);
    }
    
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
        'Recommended Course Cluster', 
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

        $recommendedClusters = 'N/A';
        if (!empty($row['ClusterRecommendations'])) {
            $clusters = json_decode($row['ClusterRecommendations'], true);
            if (is_array($clusters) && !empty($clusters)) {
                $clusterList = [];
                foreach ($clusters as $c) {
                    $cName = $c['cluster_name'] ?? ($c['cluster'] ?? '');
                    $pct = isset($c['match_percentage']) ? ' (' . round($c['match_percentage'], 1) . '%)' : '';
                    if (!empty($cName)) {
                        $clusterList[] = $cName . $pct;
                    }
                }
                if (!empty($clusterList)) {
                    $recommendedClusters = implode('; ', $clusterList);
                }
            }
        }
        
        fputcsv($output, [
            $row['AssessmentID'],
            $row['StudentID'],
            $row['FirstName'],
            $row['LastName'],
            $strand,
            $row['GradeLevel'],
            $recommendedClusters,
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
