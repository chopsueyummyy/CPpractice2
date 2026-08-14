<?php
// export_pdf_summary.php - General / School Summary PDF Report Generator
error_reporting(0);
ini_set('display_errors', 0);
date_default_timezone_set('Asia/Manila');

include 'db_connect.php';
require_once __DIR__ . '/vendor/fpdf/fpdf.php';

$adminId = $_GET['adminId'] ?? null;
$roleId  = $_GET['roleId']  ?? null;

if ($adminId === null || $adminId === '') {
    die("Unauthorized Citadel access.");
}

// Helper to convert full strand strings into clean, short codes
function getStrandCode($strand) {
    if (empty($strand)) return 'Unassigned';
    $str = strtoupper(trim($strand));
    if (strpos($str, 'STEM') !== false || strpos($str, 'SCIENCE') !== false) return 'STEM';
    if (strpos($str, 'ABM') !== false || strpos($str, 'ACCOUNTANCY') !== false) return 'ABM';
    if (strpos($str, 'HUMSS') !== false || strpos($str, 'HUMANITIES') !== false) return 'HUMSS';
    if (strpos($str, 'GAS') !== false || strpos($str, 'GENERAL') !== false) return 'GAS';
    if (strpos($str, 'TVL') !== false || strpos($str, 'TECHNICAL') !== false) return 'TVL';
    if (strpos($str, 'ICT') !== false || strpos($str, 'INFORMATION') !== false) return 'ICT';
    if (strpos($str, 'ARTS') !== false) return 'Arts & Design';
    if (strpos($str, '(') !== false) {
        $parts = explode('(', $strand);
        return trim($parts[0]);
    }
    return mb_substr(trim($strand), 0, 10);
}

// 1. FETCH EXECUTIVE STATS
$totalAssessments = (int)($conn->query("SELECT COUNT(*) as c FROM assessments WHERE Status != 'in_progress'")->fetch_assoc()['c'] ?? 0);
$approvedCount    = (int)($conn->query("SELECT COUNT(*) as c FROM assessments WHERE Status = 'approved'")->fetch_assoc()['c'] ?? 0);
$pendingCount     = (int)($conn->query("SELECT COUNT(*) as c FROM assessments WHERE Status = 'pending_review'")->fetch_assoc()['c'] ?? 0);
$declinedCount    = (int)($conn->query("SELECT COUNT(*) as c FROM assessments WHERE Status = 'declined'")->fetch_assoc()['c'] ?? 0);
$approvalRate     = ($totalAssessments > 0) ? round(($approvedCount / $totalAssessments) * 100, 1) : 0;

// 2. STRAND DISTRIBUTION
$strandRes = $conn->query("
    SELECT COALESCE(pi.Strand, 'Unassigned') as Strand, COUNT(*) as count 
    FROM assessments a 
    LEFT JOIN personal_information pi ON pi.StudentID = a.StudentID 
    WHERE a.Status != 'in_progress' 
    GROUP BY pi.Strand
");
$strandStats = ['STEM' => 0, 'ABM' => 0, 'HUMSS' => 0, 'GAS' => 0, 'TVL' => 0, 'ICT' => 0];
while ($row = $strandRes->fetch_assoc()) {
    $code = getStrandCode($row['Strand']);
    $count = (int)$row['count'];
    if (isset($strandStats[$code])) {
        $strandStats[$code] += $count;
    } else {
        $strandStats[$code] = $count;
    }
}

// 3. RIASEC INTEREST DISTRIBUTION
$riasecRes = $conn->query("
    SELECT r.PrimaryType, COUNT(*) as count 
    FROM assessments a 
    JOIN assessment_results r ON r.AssessmentID = a.AssessmentID 
    WHERE a.Status != 'in_progress' AND r.PrimaryType IS NOT NULL 
    GROUP BY r.PrimaryType
");
$riasecStats = ['R' => 0, 'I' => 0, 'A' => 0, 'S' => 0, 'E' => 0, 'C' => 0];
while ($row = $riasecRes->fetch_assoc()) {
    $type = strtoupper(trim($row['PrimaryType']));
    if (isset($riasecStats[$type])) {
        $riasecStats[$type] = (int)$row['count'];
    }
}

// 4. PSYCHOMETRIC BENCHMARKS
$rseRes = $conn->query("
    SELECT rse.Level, COUNT(*) as count 
    FROM assessments a 
    JOIN rse_results rse ON rse.AssessmentID = a.AssessmentID 
    WHERE a.Status != 'in_progress' 
    GROUP BY rse.Level
");
$rseStats = [];
while ($row = $rseRes->fetch_assoc()) {
    $rseStats[$row['Level']] = (int)$row['count'];
}

$cdsesRes = $conn->query("
    SELECT cdses.SelfEfficacyLevel, COUNT(*) as count 
    FROM assessments a 
    JOIN cdses_results cdses ON cdses.AssessmentID = a.AssessmentID 
    WHERE a.Status != 'in_progress' 
    GROUP BY cdses.SelfEfficacyLevel
");
$cdsesStats = [];
while ($row = $cdsesRes->fetch_assoc()) {
    $cdsesStats[$row['SelfEfficacyLevel']] = (int)$row['count'];
}

// 5. STUDENT RECORDS TABLE
$recordsRes = $conn->query("
    SELECT a.AssessmentID, a.StudentID, s.FirstName, s.LastName, 
           pi.Strand, pi.GradeLevel,
           r.PrimaryType, r.SecondaryType, r.TertiaryType,
           a.Status, 
           DATE_FORMAT(a.SubmittedAt, '%Y-%m-%d') as DateSubmitted
    FROM assessments a
    JOIN students s ON s.StudentID = a.StudentID
    LEFT JOIN (
        SELECT pi1.* FROM personal_information pi1
        INNER JOIN (
            SELECT MAX(PI_ID) as max_id FROM personal_information GROUP BY StudentID
        ) pi2 ON pi1.PI_ID = pi2.max_id
    ) pi ON pi.StudentID = s.StudentID
    LEFT JOIN assessment_results r ON r.AssessmentID = a.AssessmentID
    WHERE a.Status != 'in_progress'
    ORDER BY a.SubmittedAt DESC
");

// --- EXTENDED FPDF CLASS ---
class SummaryPDF extends FPDF {
    function Header() {
        $logoImg = __DIR__ . '/jmc_logo.png';
        if (file_exists($logoImg)) {
            // High-resolution crisp JMC Logo on top left (22mm x 22mm)
            $this->Image($logoImg, 10, 8, 22);
            $this->SetX(36);
        } else {
            $this->SetX(10);
        }

        $this->SetFont('Arial', 'B', 15);
        $this->SetTextColor(91, 33, 182); // AppTheme Primary Purple
        $this->Cell(0, 6, 'JOSE MARIA COLLEGE FOUNDATION, INC.', 0, 1, 'L');

        $this->SetX(file_exists($logoImg) ? 36 : 10);
        $this->SetFont('Arial', 'B', 9.5);
        $this->SetTextColor(80, 80, 100);
        $this->Cell(0, 5, 'CAREER GUIDANCE & COUNSELING CENTER', 0, 1, 'L');

        $this->SetX(file_exists($logoImg) ? 36 : 10);
        $this->SetFont('Arial', 'B', 10.5);
        $this->SetTextColor(30, 30, 46);
        $this->Cell(0, 5, 'GENERAL CAREER ASSESSMENT & GUIDANCE SUMMARY REPORT', 0, 1, 'L');

        $this->SetX(file_exists($logoImg) ? 36 : 10);
        $this->SetFont('Arial', 'I', 8.5);
        $this->SetTextColor(120, 120, 120);
        $this->Cell(0, 5, 'Generated On: ' . date('F j, Y - g:i A'), 0, 1, 'L');

        $this->Ln(4);
        $this->SetDrawColor(91, 33, 182);
        $this->SetLineWidth(0.6);
        $this->Line(10, $this->GetY(), 200, $this->GetY());
        $this->Ln(6);
    }

    function Footer() {
        $this->SetY(-15);
        $this->SetFont('Arial', 'I', 8);
        $this->SetTextColor(150, 150, 150);
        $this->Cell(0, 10, 'CourseAlign Career Assessment System  |  Page ' . $this->PageNo() . '/{nb}', 0, 0, 'C');
    }

    function SectionHeader($title) {
        $this->SetFont('Arial', 'B', 11);
        $this->SetFillColor(243, 244, 246);
        $this->SetTextColor(91, 33, 182); // Purple
        $this->Cell(0, 7, '  ' . mb_strtoupper($title), 0, 1, 'L', true);
        $this->Ln(2);
    }
}

$pdf = new SummaryPDF('P', 'mm', 'A4');
$pdf->AliasNbPages();
$pdf->SetMargins(10, 10, 10);
$pdf->SetAutoPageBreak(true, 20);
$pdf->AddPage();

// -----------------------------------------------------------------
// 1. SYSTEM EXECUTIVE SUMMARY
// -----------------------------------------------------------------
$pdf->SectionHeader('1. Executive System Overview');

$colWidth = 45;
$pdf->SetFont('Arial', '', 9);

// Row 1: KPI Cards
$pdf->SetFillColor(245, 243, 255); // Soft purple fill
$pdf->SetTextColor(76, 29, 149);
$pdf->Cell($colWidth, 12, " Total Completed: $totalAssessments", 1, 0, 'C', true);

$pdf->SetFillColor(240, 253, 244); // Soft green fill
$pdf->SetTextColor(22, 101, 52);
$pdf->Cell($colWidth, 12, " Approved: $approvedCount", 1, 0, 'C', true);

$pdf->SetFillColor(254, 252, 232); // Soft yellow fill
$pdf->SetTextColor(133, 77, 14);
$pdf->Cell($colWidth, 12, " Pending Review: $pendingCount", 1, 0, 'C', true);

$pdf->SetFillColor(240, 249, 255); // Soft blue fill
$pdf->SetTextColor(7, 89, 133);
$pdf->Cell($colWidth, 12, " Approval Rate: {$approvalRate}%", 1, 1, 'C', true);

$pdf->Ln(6);

// -----------------------------------------------------------------
// 2. STRAND & RIASEC DISTRIBUTIONS
// -----------------------------------------------------------------
$pdf->SectionHeader('2. Senior High School Strand & Personality Trends');

$pdf->SetFont('Arial', 'B', 9);
$pdf->SetTextColor(30, 30, 46);

// Table Columns (Side-by-Side: Strand on Left, RIASEC on Right)
$pdf->Cell(92, 6, 'SHS Strand Distribution', 0, 0, 'L');
$pdf->Cell(6, 6, '', 0, 0); // Spacer
$pdf->Cell(92, 6, 'Dominant RIASEC Personality Interest Trends', 0, 1, 'L');

$pdf->SetFont('Arial', '', 8.5);
$pdf->SetFillColor(250, 250, 252);

// Strand Details Column
$yStart = $pdf->GetY();
$pdf->SetY($yStart);

$strandList = [
    'STEM' => 'Science, Tech, Engineering, Math',
    'ABM'  => 'Accountancy, Business, Management',
    'HUMSS'=> 'Humanities and Social Sciences',
    'GAS'  => 'General Academic Strand',
    'TVL'  => 'Technical-Vocational-Livelihood',
    'ICT'  => 'Info & Comm Technology'
];

$pdf->SetX(10);
foreach ($strandList as $code => $name) {
    $count = $strandStats[$code] ?? 0;
    $pct = ($totalAssessments > 0) ? round(($count / $totalAssessments) * 100, 1) : 0;
    $pdf->Cell(30, 5.5, " $code", 1, 0, 'L', true);
    $pdf->Cell(62, 5.5, " $count student(s)  ({$pct}%)", 1, 1, 'L');
}

$yEndLeft = $pdf->GetY();

// RIASEC Details Column
$pdf->SetY($yStart);
$riasecNames = [
    'R' => 'Realistic (Practical / Hands-on)',
    'I' => 'Investigative (Analytical / Scientific)',
    'A' => 'Artistic (Creative / Expressive)',
    'S' => 'Social (Helping / Educational)',
    'E' => 'Enterprising (Leadership / Persuasive)',
    'C' => 'Conventional (Organized / Detail-oriented)'
];

foreach ($riasecNames as $code => $desc) {
    $pdf->SetX(108);
    $count = $riasecStats[$code] ?? 0;
    $pct = ($totalAssessments > 0) ? round(($count / $totalAssessments) * 100, 1) : 0;
    $pdf->Cell(25, 5.5, " $code", 1, 0, 'L', true);
    $pdf->Cell(67, 5.5, " $count student(s)  ({$pct}%)", 1, 1, 'L');
}

$yEndRight = $pdf->GetY();
$pdf->SetY(max($yEndLeft, $yEndRight) + 4);

// -----------------------------------------------------------------
// 3. PSYCHOMETRIC BENCHMARKS
// -----------------------------------------------------------------
$pdf->SectionHeader('3. Psychometric Self-Esteem & Self-Efficacy Benchmarks');

$pdf->SetFont('Arial', 'B', 9);
$pdf->Cell(92, 5.5, 'Rosenberg Self-Esteem Scale (RSES)', 0, 0, 'L');
$pdf->Cell(6, 5.5, '', 0, 0);
$pdf->Cell(92, 5.5, 'Career Decision Self-Efficacy (CDSES-SF)', 0, 1, 'L');

$pdf->SetFont('Arial', '', 8.5);

// RSES Table
$rseNormal = $rseStats['Normal Self-Esteem'] ?? 0;
$rseLow    = $rseStats['Low Self-Esteem'] ?? 0;
$rseNormPct = ($totalAssessments > 0) ? round(($rseNormal / $totalAssessments) * 100, 1) : 0;
$rseLowPct  = ($totalAssessments > 0) ? round(($rseLow / $totalAssessments) * 100, 1) : 0;

$yBenchStart = $pdf->GetY();
$pdf->SetX(10);
$pdf->Cell(45, 5.5, ' Normal Self-Esteem', 1, 0, 'L', true);
$pdf->Cell(47, 5.5, " $rseNormal student(s) ({$rseNormPct}%)", 1, 1, 'L');
$pdf->SetX(10);
$pdf->Cell(45, 5.5, ' Low Self-Esteem', 1, 0, 'L', true);
$pdf->Cell(47, 5.5, " $rseLow student(s) ({$rseLowPct}%)", 1, 1, 'L');

// CDSES Table
$pdf->SetY($yBenchStart);
$cdsesHigh = $cdsesStats['High Career Decision Self-Efficacy'] ?? 0;
$cdsesMod  = $cdsesStats['Moderate Career Decision Self-Efficacy'] ?? 0;
$cdsesLow  = $cdsesStats['Low Career Decision Self-Efficacy'] ?? 0;

$cdsesHighPct = ($totalAssessments > 0) ? round(($cdsesHigh / $totalAssessments) * 100, 1) : 0;
$cdsesModPct  = ($totalAssessments > 0) ? round(($cdsesMod / $totalAssessments) * 100, 1) : 0;
$cdsesLowPct  = ($totalAssessments > 0) ? round(($cdsesLow / $totalAssessments) * 100, 1) : 0;

$pdf->SetX(108);
$pdf->Cell(45, 5.5, ' High Self-Efficacy', 1, 0, 'L', true);
$pdf->Cell(47, 5.5, " $cdsesHigh student(s) ({$cdsesHighPct}%)", 1, 1, 'L');
$pdf->SetX(108);
$pdf->Cell(45, 5.5, ' Moderate Self-Efficacy', 1, 0, 'L', true);
$pdf->Cell(47, 5.5, " $cdsesMod student(s) ({$cdsesModPct}%)", 1, 1, 'L');

$pdf->Ln(6);

// -----------------------------------------------------------------
// 4. COMPLETED STUDENT RECORDS TABLE
// -----------------------------------------------------------------
$pdf->SectionHeader('4. Completed Student Assessment Records Summary');

$pdf->SetFont('Arial', 'B', 8);
$pdf->SetFillColor(91, 33, 182); // Primary Purple Header
$pdf->SetTextColor(255, 255, 255);

// Exact column widths: 18 + 48 + 24 + 20 + 22 + 22 + 36 = 190mm
$pdf->Cell(18, 6.5, 'ID', 1, 0, 'C', true);
$pdf->Cell(48, 6.5, 'Student Name', 1, 0, 'L', true);
$pdf->Cell(24, 6.5, 'Strand', 1, 0, 'C', true);
$pdf->Cell(20, 6.5, 'Grade', 1, 0, 'C', true);
$pdf->Cell(22, 6.5, 'Primary', 1, 0, 'C', true);
$pdf->Cell(22, 6.5, 'Secondary', 1, 0, 'C', true);
$pdf->Cell(38, 6.5, 'Date Taken', 1, 1, 'C', true);

$pdf->SetFont('Arial', '', 8);
$pdf->SetTextColor(30, 30, 46);

$fill = false;
while ($row = $recordsRes->fetch_assoc()) {
    $pdf->SetFillColor($fill ? 246 : 255, $fill ? 246 : 255, $fill ? 250 : 255);
    
    $studentName = mb_substr(trim($row['FirstName'] . ' ' . $row['LastName']), 0, 24);
    $strandCode  = getStrandCode($row['Strand'] ?? 'N/A');
    
    $pdf->Cell(18, 5.5, ' ' . $row['StudentID'], 1, 0, 'C', true);
    $pdf->Cell(48, 5.5, ' ' . $studentName, 1, 0, 'L', true);
    $pdf->Cell(24, 5.5, ' ' . $strandCode, 1, 0, 'C', true);
    $pdf->Cell(18, 5.5, ' ' . ($row['GradeLevel'] ?? 'Grade 12'), 1, 0, 'C', true);
    $pdf->Cell(22, 5.5, ' ' . ($row['PrimaryType'] ?? 'N/A'), 1, 0, 'C', true);
    $pdf->Cell(22, 5.5, ' ' . ($row['SecondaryType'] ?? 'N/A'), 1, 0, 'C', true);
    $pdf->Cell(38, 5.5, ' ' . ($row['DateSubmitted'] ?? 'N/A'), 1, 1, 'C', true);
    
    $fill = !$fill;
}

// OUTPUT STREAM DIRECTLY TO BROWSER
$filename = "CourseAlign_General_Summary_Report_" . date('Y-m-d') . ".pdf";
header('Content-Type: application/pdf');
header('Content-Disposition: inline; filename="' . $filename . '"');
header('Cache-Control: private, max-age=0, must-revalidate');
header('Pragma: public');

$pdf->Output('I', $filename);
$conn->close();
exit();
?>
