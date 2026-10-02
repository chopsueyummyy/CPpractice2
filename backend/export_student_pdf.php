<?php
// export_student_pdf.php - Individual Student Assessment Report Generator (Single Page Optimized)
error_reporting(E_ALL);
ini_set('display_errors', 0);
require_once 'cors.php';
require_once 'db_connect.php';
require_once __DIR__ . '/vendor/fpdf/fpdf.php';

$assessmentId = (int)($_GET['assessmentId'] ?? 0);

if (empty($assessmentId)) {
    die("Error: Missing or invalid Assessment ID.");
}

// 1. Fetch complete student assessment data
$query = "
    SELECT 
        a.AssessmentID, a.StudentID, a.Status, a.SubmittedAt,
        pi.FirstName, pi.LastName, pi.MiddleName, pi.Strand, pi.GradeLevel, pi.Age, pi.Gender,
        ar.PrimaryType, ar.SecondaryType, ar.TertiaryType,
        ar.R_Percentage, ar.I_Percentage, ar.A_Percentage,
        ar.S_Percentage, ar.E_Percentage, ar.C_Percentage,
        ar.ClusterRecommendations,
        rse.Score as RSE_Score, rse.Level as RSE_Level,
        cdses.SA_Score, cdses.OI_Score, cdses.GS_Score, cdses.PL_Score, cdses.PS_Score,
        cdses.TotalScore as CDSES_TotalScore, cdses.SelfEfficacyLevel as CDSES_Level,
        cf.Action as CounselorAction, cf.FeedbackNotes, cf.ReviewedAt
    FROM assessments a
    JOIN students s ON s.StudentID = a.StudentID
    LEFT JOIN personal_information pi ON pi.PI_ID = a.PI_ID
    LEFT JOIN assessment_results ar ON ar.AssessmentID = a.AssessmentID
    LEFT JOIN rse_results rse ON rse.AssessmentID = a.AssessmentID
    LEFT JOIN cdses_results cdses ON cdses.AssessmentID = a.AssessmentID
    LEFT JOIN counselor_feedback cf ON cf.AssessmentID = a.AssessmentID
    WHERE a.AssessmentID = ?
";

$stmt = $conn->prepare($query);
$stmt->bind_param("i", $assessmentId);
$stmt->execute();
$data = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$data) {
    die("Error: Assessment record not found.");
}

$strandAbbr = trim($data['Strand'] ?? 'N/A');
$studentName = trim(($data['FirstName'] ?? '') . ' ' . (!empty($data['MiddleName']) ? $data['MiddleName'] . ' ' : '') . ($data['LastName'] ?? ''));

// PDF Class Definition
class StudentAssessmentPDF extends FPDF {
    function Header() {
        $this->SetY(6);
        $this->SetFont('Arial', 'B', 13);
        $this->SetTextColor(90, 34, 139); // Deep Purple
        $this->Cell(0, 5, 'COURSEALIGN - INDIVIDUAL STUDENT ASSESSMENT REPORT', 0, 1, 'C');
        $this->SetFont('Arial', 'I', 8.5);
        $this->SetTextColor(100, 100, 100);
        $this->Cell(0, 4, 'Guidance & Career Pathing Assessment Profile', 0, 1, 'C');
        $this->SetDrawColor(90, 34, 139);
        $this->SetLineWidth(0.5);
        $this->Line(10, 16, 200, 16);
        $this->Ln(3);
    }

    function Footer() {
        $this->SetY(-10);
        $this->SetFont('Arial', 'I', 7.5);
        $this->SetTextColor(120, 120, 120);
        $this->Cell(0, 5, 'Page ' . $this->PageNo() . '/{nb} | Confidential Student Guidance Document | CourseAlign System', 0, 0, 'C');
    }

    function ChapterTitle($label) {
        $this->SetFont('Arial', 'B', 9.5);
        $this->SetFillColor(240, 235, 248); // Light purple tint
        $this->SetTextColor(90, 34, 139);
        $this->Cell(0, 5, '  ' . mb_strtoupper($label, 'UTF-8'), 0, 1, 'L', true);
        $this->Ln(2);
    }
}

$pdf = new StudentAssessmentPDF('P', 'mm', 'A4');
$pdf->SetMargins(10, 8, 10);
$pdf->AliasNbPages();
$pdf->AddPage();
$pdf->SetAutoPageBreak(false);

// SECTION 1: STUDENT PROFILE
$pdf->ChapterTitle('1. Student Demographic & Assessment Info');
$pdf->SetFont('Arial', '', 8.5);
$pdf->SetTextColor(40, 40, 40);

$pdf->SetFillColor(252, 252, 252);
$pdf->SetDrawColor(220, 220, 220);

// Row 1
$pdf->Cell(28, 5, 'Student Name:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 8.5);
$pdf->Cell(67, 5, $studentName, 1, 0, 'L');
$pdf->SetFont('Arial', '', 8.5);
$pdf->Cell(28, 5, 'Student ID:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 8.5);
$pdf->Cell(67, 5, $data['StudentID'] ?? 'N/A', 1, 1, 'L');

// Row 2
$pdf->SetFont('Arial', '', 8.5);
$pdf->Cell(28, 5, 'SHS Strand:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 8.5);
$pdf->Cell(67, 5, $strandAbbr, 1, 0, 'L');
$pdf->SetFont('Arial', '', 8.5);
$pdf->Cell(28, 5, 'Grade Level:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 8.5);
$pdf->Cell(67, 5, $data['GradeLevel'] ?? 'N/A', 1, 1, 'L');

// Row 3
$pdf->SetFont('Arial', '', 8.5);
$pdf->Cell(28, 5, 'Age / Gender:', 1, 0, 'L', true);
$pdf->Cell(67, 5, ($data['Age'] ?? 'N/A') . ' yrs old / ' . ucfirst($data['Gender'] ?? 'N/A'), 1, 0, 'L');
$pdf->Cell(28, 5, 'Date Submitted:', 1, 0, 'L', true);
$pdf->Cell(67, 5, $data['SubmittedAt'] ?? 'N/A', 1, 1, 'L');

// Row 4
$pdf->Cell(28, 5, 'Review Status:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 8.5);
if ($data['Status'] === 'approved') {
    $pdf->SetTextColor(34, 139, 34); // Green
    $statusText = 'APPROVED BY GUIDANCE COUNSELOR';
} else {
    $pdf->SetTextColor(200, 100, 0); // Orange
    $statusText = strtoupper($data['Status'] ?? 'PENDING REVIEW');
}
$pdf->Cell(162, 5, $statusText, 1, 1, 'L');
$pdf->SetTextColor(40, 40, 40);

$pdf->Ln(3);

// SECTION 2: RIASEC PROFILE
$pdf->ChapterTitle('2. Career Interests Profile (RIASEC)');

// Top 3 Types Box
$pdf->SetFont('Arial', 'B', 8.5);
$pdf->Cell(35, 5, 'Top 3 Holland Codes: ', 0, 0, 'L');
$pdf->SetFillColor(90, 34, 139);
$pdf->SetTextColor(255, 255, 255);
$pdf->Cell(18, 5, '1st: ' . ($data['PrimaryType'] ?? '-'), 0, 0, 'C', true);
$pdf->Cell(3, 5, '', 0, 0);
$pdf->SetFillColor(120, 80, 160);
$pdf->Cell(18, 5, '2nd: ' . ($data['SecondaryType'] ?? '-'), 0, 0, 'C', true);
$pdf->Cell(3, 5, '', 0, 0);
$pdf->SetFillColor(150, 120, 180);
$pdf->Cell(18, 5, '3rd: ' . ($data['TertiaryType'] ?? '-'), 0, 1, 'C', true);
$pdf->SetTextColor(40, 40, 40);
$pdf->Ln(2);

// RIASEC Breakdown Table
$pdf->SetFont('Arial', 'B', 8);
$pdf->SetFillColor(245, 245, 245);
$pdf->Cell(45, 4.5, 'RIASEC Category', 1, 0, 'L', true);
$pdf->Cell(28, 4.5, 'Match Percentage', 1, 0, 'C', true);
$pdf->Cell(117, 4.5, 'Category Interest Description', 1, 1, 'L', true);

$riasecData = [
    'R' => ['Realistic', (float)$data['R_Percentage'], 'Practical, hands-on, mechanical, and technical activities'],
    'I' => ['Investigative', (float)$data['I_Percentage'], 'Analytical, scientific, problem-solving, and research activities'],
    'A' => ['Artistic', (float)$data['A_Percentage'], 'Creative, intuitive, imaginative, and expressive activities'],
    'S' => ['Social', (float)$data['S_Percentage'], 'Helping, teaching, advising, and communicating with people'],
    'E' => ['Enterprising', (float)$data['E_Percentage'], 'Leadership, business, persuasion, and entrepreneurial tasks'],
    'C' => ['Conventional', (float)$data['C_Percentage'], 'Structured, detail-oriented, administrative, and organizational tasks']
];

foreach ($riasecData as $code => $info) {
    $isTop = in_array($code, [$data['PrimaryType'], $data['SecondaryType'], $data['TertiaryType']]);
    if ($isTop) {
        $pdf->SetFont('Arial', 'B', 8);
    } else {
        $pdf->SetFont('Arial', '', 8);
    }
    $pdf->Cell(45, 4.2, $code . ' - ' . $info[0], 1, 0, 'L');
    $pdf->Cell(28, 4.2, number_format($info[1], 1) . '%', 1, 0, 'C');
    $pdf->Cell(117, 4.2, $info[2], 1, 1, 'L');
}

$pdf->Ln(3);

// SECTION 3: PSYCHOMETRIC PROFILES (RSE & CDSES)
$pdf->ChapterTitle('3. Psychometric Self-Assessment Profiles');

$pdf->SetFont('Arial', 'B', 8.5);
$pdf->Cell(92, 4.5, 'Rosenberg Self-Esteem Scale (RSE)', 0, 0, 'L');
$pdf->Cell(6, 4.5, '', 0, 0);
$pdf->Cell(92, 4.5, 'Career Decision Self-Efficacy Scale (CDSES-SF)', 0, 1, 'L');

$pdf->SetFont('Arial', '', 8);
$pdf->SetFillColor(252, 252, 252);
$rseText = "Score: " . ($data['RSE_Score'] ?? 'N/A') . " / 30 (" . ($data['RSE_Level'] ?? 'N/A') . ")";
$pdf->Cell(92, 5, $rseText, 1, 0, 'L', true);

$pdf->Cell(6, 5, '', 0, 0);
$cdsesText = "Total Score: " . ($data['CDSES_TotalScore'] ?? 'N/A') . " / 125 (" . ($data['CDSES_Level'] ?? 'N/A') . ")";
$pdf->Cell(92, 5, $cdsesText, 1, 1, 'L', true);

$pdf->Ln(2);

// CDSES Subscale Table
$pdf->SetFont('Arial', 'B', 7.5);
$pdf->Cell(190, 4, 'CDSES-SF Subscale Average Scores (Scale 1.0 - 5.0):', 0, 1, 'L');

$pdf->SetFont('Arial', '', 7.5);
$pdf->Cell(38, 4.2, 'Self-Appraisal: ' . number_format((float)($data['SA_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 4.2, 'Occupational Info: ' . number_format((float)($data['OI_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 4.2, 'Goal Selection: ' . number_format((float)($data['GS_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 4.2, 'Planning: ' . number_format((float)($data['PL_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 4.2, 'Problem Solving: ' . number_format((float)($data['PS_Score'] ?? 0), 2), 1, 1, 'C');

$pdf->Ln(3);

// SECTION 4: RECOMMENDED COURSE CLUSTERS
$pdf->ChapterTitle('4. RECOMMENDED COURSE CLUSTERS');

if (!empty($data['ClusterRecommendations'])) {
    $clusters = json_decode($data['ClusterRecommendations'], true);
    if (is_array($clusters) && !empty($clusters)) {
        foreach ($clusters as $idx => $cluster) {
            $rankName = ['Primary Recommendation', 'Alternative Recommendation', 'Additional Recommendation'][$idx] ?? ('Rank ' . ($idx + 1));
            $cName = $cluster['cluster_name'] ?? ($cluster['cluster'] ?? 'Cluster');
            $prob = isset($cluster['match_percentage']) ? round($cluster['match_percentage'], 1) . '%' : 'N/A';

            $pdf->SetFont('Arial', 'B', 8.5);
            $pdf->SetFillColor(245, 240, 252);
            $pdf->SetTextColor(90, 34, 139);
            $pdf->Cell(190, 4.5, "  [$rankName] $cName ($prob Predicted Probability)", 1, 1, 'L', true);
            $pdf->SetTextColor(40, 40, 40);

            // SHAP explanations
            $pdf->SetFont('Arial', 'I', 7.5);
            $shapText = "  Why recommended: ";
            if (!empty($cluster['shap_explanations']) && is_array($cluster['shap_explanations'])) {
                $drivers = [];
                foreach ($cluster['shap_explanations'] as $s) {
                    $drivers[] = ($s['feature'] ?? '') . ' (+' . round(($s['impact_score'] ?? 0) * 100) . '% impact)';
                }
                $shapText .= implode(', ', $drivers);
            } else {
                $shapText .= "High feature alignment with SHS strand and RIASEC interest profile.";
            }
            $pdf->MultiCell(190, 3.5, $shapText, 'LR', 'L');

            // Courses
            $pdf->SetFont('Arial', '', 7.5);
            $coursesText = "  Programs to explore: ";
            if (!empty($cluster['explore_courses']) && is_array($cluster['explore_courses'])) {
                $coursesText .= implode(', ', $cluster['explore_courses']);
            } else {
                $coursesText .= "N/A";
            }
            $pdf->MultiCell(190, 3.5, $coursesText, 'LBR', 'L');
            $pdf->Ln(1.5);
        }
    }
} else {
    $pdf->SetFont('Arial', 'I', 8);
    $pdf->Cell(190, 5, 'No cluster recommendations generated.', 1, 1, 'C');
}

$pdf->Ln(2);

// SECTION 5: COUNSELOR NOTES & OFFICIAL SIGN-OFF
$pdf->ChapterTitle('5. Guidance Counselor Notes & Endorsement');

$notes = !empty($data['FeedbackNotes']) ? $data['FeedbackNotes'] : 'No written counselor notes attached.';
$reviewedAt = !empty($data['ReviewedAt']) ? $data['ReviewedAt'] : ($data['SubmittedAt'] ?? 'N/A');

$pdf->SetFillColor(252, 252, 252);
$pdf->SetFont('Arial', 'I', 8);
$pdf->MultiCell(190, 4, "Counselor Guidance Notes (Reviewed on $reviewedAt):\n\"$notes\"", 1, 'L', true);

$pdf->Ln(3);

// Signature Section (Compact)
$pdf->SetFont('Arial', 'B', 8.5);
$pdf->SetTextColor(90, 34, 139);
$pdf->Cell(95, 4, '', 0, 0);
$pdf->Cell(95, 4, 'OFFICIAL ENDORSEMENT:', 0, 1, 'L');
$pdf->SetTextColor(40, 40, 40);

$pdf->Ln(4);
$pdf->Cell(95, 4, '', 0, 0);
$pdf->Cell(95, 4, '________________________________________________', 0, 1, 'L');
$pdf->SetFont('Arial', '', 8);
$pdf->Cell(95, 4, '', 0, 0);
$pdf->Cell(95, 4, 'Guidance Counselor Signature / Date', 0, 1, 'L');

// Output PDF
$pdf->Output('I', 'Student_Assessment_Report_' . ($data['StudentID'] ?? '000') . '.pdf');
$conn->close();
?>
