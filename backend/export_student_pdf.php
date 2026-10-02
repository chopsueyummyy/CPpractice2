<?php
// export_student_pdf.php - Individual Student Assessment Report Generator
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

$strandMapping = [
    'STEM' => 'Science, Technology, Engineering, and Mathematics',
    'ABM' => 'Accountancy, Business, and Management',
    'HUMSS' => 'Humanities and Social Sciences',
    'GAS' => 'General Academic Strand',
    'TVL' => 'Technical-Vocational-Livelihood',
    'ICT' => 'Information and Communication Technology',
    'Arts and Design' => 'Arts and Design Track'
];

$strandFull = $strandMapping[$data['Strand'] ?? ''] ?? ($data['Strand'] ?? 'N/A');
$studentName = trim(($data['FirstName'] ?? '') . ' ' . (!empty($data['MiddleName']) ? $data['MiddleName'] . ' ' : '') . ($data['LastName'] ?? ''));

// PDF Class Definition
class StudentAssessmentPDF extends FPDF {
    function Header() {
        $this->SetFont('Arial', 'B', 14);
        $this->SetTextColor(90, 34, 139); // Deep Purple
        $this->Cell(0, 7, 'COURSEALIGN - INDIVIDUAL STUDENT ASSESSMENT REPORT', 0, 1, 'C');
        $this->SetFont('Arial', 'I', 9);
        $this->SetTextColor(100, 100, 100);
        $this->Cell(0, 5, 'Guidance & Career Pathing Assessment Profile', 0, 1, 'C');
        $this->SetDrawColor(90, 34, 139);
        $this->SetLineWidth(0.6);
        $this->Line(10, 22, 200, 22);
        $this->Ln(5);
    }

    function Footer() {
        $this->SetY(-15);
        $this->SetFont('Arial', 'I', 8);
        $this->SetTextColor(120, 120, 120);
        $this->Cell(0, 10, 'Page ' . $this->PageNo() . '/{nb} | Confidential Student Guidance Document | CourseAlign System', 0, 0, 'C');
    }

    function ChapterTitle($label) {
        $this->SetFont('Arial', 'B', 11);
        $this->SetFillColor(240, 235, 248); // Light purple tint
        $this->SetTextColor(90, 34, 139);
        $this->Cell(0, 7, '   ' . mb_strtoupper($label, 'UTF-8'), 0, 1, 'L', true);
        $this->Ln(3);
    }
}

$pdf = new StudentAssessmentPDF('P', 'mm', 'A4');
$pdf->AliasNbPages();
$pdf->AddPage();
$pdf->SetAutoPageBreak(true, 18);

// SECTION: STUDENT PROFILE
$pdf->ChapterTitle('1. Student Demographic & Assessment Info');
$pdf->SetFont('Arial', '', 9.5);
$pdf->SetTextColor(40, 40, 40);

$pdf->SetFillColor(250, 250, 250);
$pdf->SetDrawColor(220, 220, 220);

// Row 1
$pdf->Cell(30, 6, 'Student Name:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 9.5);
$pdf->Cell(65, 6, $studentName, 1, 0, 'L');
$pdf->SetFont('Arial', '', 9.5);
$pdf->Cell(30, 6, 'Student ID:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 9.5);
$pdf->Cell(65, 6, $data['StudentID'] ?? 'N/A', 1, 1, 'L');

// Row 2
$pdf->SetFont('Arial', '', 9.5);
$pdf->Cell(30, 6, 'SHS Strand:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 9.5);
$pdf->Cell(65, 6, $data['Strand'] . ' (' . $strandFull . ')', 1, 0, 'L');
$pdf->SetFont('Arial', '', 9.5);
$pdf->Cell(30, 6, 'Grade Level:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 9.5);
$pdf->Cell(65, 6, $data['GradeLevel'] ?? 'N/A', 1, 1, 'L');

// Row 3
$pdf->SetFont('Arial', '', 9.5);
$pdf->Cell(30, 6, 'Age / Gender:', 1, 0, 'L', true);
$pdf->Cell(65, 6, ($data['Age'] ?? 'N/A') . ' yrs old / ' . ucfirst($data['Gender'] ?? 'N/A'), 1, 0, 'L');
$pdf->Cell(30, 6, 'Date Submitted:', 1, 0, 'L', true);
$pdf->Cell(65, 6, $data['SubmittedAt'] ?? 'N/A', 1, 1, 'L');

// Row 4
$pdf->Cell(30, 6, 'Review Status:', 1, 0, 'L', true);
$pdf->SetFont('Arial', 'B', 9.5);
if ($data['Status'] === 'approved') {
    $pdf->SetTextColor(34, 139, 34); // Green
    $statusText = 'APPROVED BY GUIDANCE COUNSELOR';
} else {
    $pdf->SetTextColor(200, 100, 0); // Orange
    $statusText = strtoupper($data['Status'] ?? 'PENDING REVIEW');
}
$pdf->Cell(160, 6, $statusText, 1, 1, 'L');
$pdf->SetTextColor(40, 40, 40);

$pdf->Ln(6);

// SECTION 2: RIASEC PROFILE
$pdf->ChapterTitle('2. Career Interests Profile (RIASEC)');
$pdf->SetFont('Arial', '', 9);

// Top 3 Types Box
$pdf->SetFont('Arial', 'B', 9.5);
$pdf->Cell(40, 6, 'Top 3 Holland Codes: ', 0, 0, 'L');
$pdf->SetFillColor(90, 34, 139);
$pdf->SetTextColor(255, 255, 255);
$pdf->Cell(20, 6, '1st: ' . ($data['PrimaryType'] ?? '-'), 0, 0, 'C', true);
$pdf->Cell(3, 6, '', 0, 0);
$pdf->SetFillColor(120, 80, 160);
$pdf->Cell(20, 6, '2nd: ' . ($data['SecondaryType'] ?? '-'), 0, 0, 'C', true);
$pdf->Cell(3, 6, '', 0, 0);
$pdf->SetFillColor(150, 120, 180);
$pdf->Cell(20, 6, '3rd: ' . ($data['TertiaryType'] ?? '-'), 0, 1, 'C', true);
$pdf->SetTextColor(40, 40, 40);
$pdf->Ln(3);

// RIASEC Breakdown Table
$pdf->SetFont('Arial', 'B', 8.5);
$pdf->SetFillColor(245, 245, 245);
$pdf->Cell(50, 5, 'RIASEC Category', 1, 0, 'L', true);
$pdf->Cell(30, 5, 'Match Percentage', 1, 0, 'C', true);
$pdf->Cell(110, 5, 'Category Interest Description', 1, 1, 'L', true);

$riasecData = [
    'R' => ['Realistic', (float)$data['R_Percentage'], 'Practical, hands-on, mechanical, and technical activities'],
    'I' => ['Investigative', (float)$data['I_Percentage'], 'Analytical, scientific, problem-solving, and research activities'],
    'A' => ['Artistic', (float)$data['A_Percentage'], 'Creative, intuitive, imaginative, and expressive activities'],
    'S' => ['Social', (float)$data['S_Percentage'], 'Helping, teaching, advising, and communicating with people'],
    'E' => ['Enterprising', (float)$data['E_Percentage'], 'Leadership, business, persuasion, and entrepreneurial tasks'],
    'C' => ['Conventional', (float)$data['C_Percentage'], 'Structured, detail-oriented, administrative, and organizational tasks']
];

$pdf->SetFont('Arial', '', 8.5);
foreach ($riasecData as $code => $info) {
    $isTop = in_array($code, [$data['PrimaryType'], $data['SecondaryType'], $data['TertiaryType']]);
    if ($isTop) {
        $pdf->SetFont('Arial', 'B', 8.5);
    } else {
        $pdf->SetFont('Arial', '', 8.5);
    }
    $pdf->Cell(50, 5, $code . ' - ' . $info[0], 1, 0, 'L');
    $pdf->Cell(30, 5, number_format($info[1], 1) . '%', 1, 0, 'C');
    $pdf->Cell(110, 5, $info[2], 1, 1, 'L');
}

$pdf->Ln(6);

// SECTION 3: PSYCHOMETRIC PROFILES (RSE & CDSES)
$pdf->ChapterTitle('3. Psychometric Self-Assessment Profiles');
$pdf->SetFont('Arial', '', 9);

// RSE Card
$pdf->SetFont('Arial', 'B', 9);
$pdf->Cell(92, 5, 'Rosenberg Self-Esteem Scale (RSE)', 0, 0, 'L');
$pdf->Cell(6, 5, '', 0, 0);
$pdf->Cell(92, 5, 'Career Decision Self-Efficacy Scale (CDSES-SF)', 0, 1, 'L');

$pdf->SetFont('Arial', '', 8.5);

// RSE Details
$pdf->SetFillColor(250, 250, 250);
$rseText = "Score: " . ($data['RSE_Score'] ?? 'N/A') . " / 30 (" . ($data['RSE_Level'] ?? 'N/A') . ")";
$pdf->Cell(92, 6, $rseText, 1, 0, 'L', true);

$pdf->Cell(6, 6, '', 0, 0);

// CDSES Details
$cdsesText = "Total Score: " . ($data['CDSES_TotalScore'] ?? 'N/A') . " / 125 (" . ($data['CDSES_Level'] ?? 'N/A') . ")";
$pdf->Cell(92, 6, $cdsesText, 1, 1, 'L', true);

$pdf->Ln(3);

// CDSES Subscale Table
$pdf->SetFont('Arial', 'B', 8);
$pdf->Cell(190, 4, 'CDSES-SF Subscale Average Scores (Scale 1.0 - 5.0):', 0, 1, 'L');

$pdf->SetFont('Arial', '', 8);
$pdf->Cell(38, 5, 'Self-Appraisal: ' . number_format((float)($data['SA_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 5, 'Occupational Info: ' . number_format((float)($data['OI_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 5, 'Goal Selection: ' . number_format((float)($data['GS_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 5, 'Planning: ' . number_format((float)($data['PL_Score'] ?? 0), 2), 1, 0, 'C');
$pdf->Cell(38, 5, 'Problem Solving: ' . number_format((float)($data['PS_Score'] ?? 0), 2), 1, 1, 'C');

$pdf->Ln(6);

// SECTION 4: XGBOOST AI RECOMMENDED COURSE CLUSTERS
$pdf->ChapterTitle('4. AI-Driven Recommended Course Clusters (XGBoost + SHAP Explainability)');

if (!empty($data['ClusterRecommendations'])) {
    $clusters = json_decode($data['ClusterRecommendations'], true);
    if (is_array($clusters) && !empty($clusters)) {
        foreach ($clusters as $idx => $cluster) {
            $rankName = ['Primary Recommendation', 'Alternative Recommendation', 'Additional Recommendation'][$idx] ?? ('Rank ' . ($idx + 1));
            $cName = $cluster['cluster_name'] ?? ($cluster['cluster'] ?? 'Cluster');
            $prob = isset($cluster['match_percentage']) ? round($cluster['match_percentage'], 1) . '%' : 'N/A';

            $pdf->SetFont('Arial', 'B', 9);
            $pdf->SetFillColor(245, 240, 252);
            $pdf->SetTextColor(90, 34, 139);
            $pdf->Cell(190, 6, "  [$rankName] $cName ($prob Predicted Probability)", 1, 1, 'L', true);
            $pdf->SetTextColor(40, 40, 40);

            // SHAP explanations
            $pdf->SetFont('Arial', 'I', 8);
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
            $pdf->MultiCell(190, 4, $shapText, 'LR', 'L');

            // Courses
            $pdf->SetFont('Arial', '', 8);
            $coursesText = "  Programs to explore: ";
            if (!empty($cluster['explore_courses']) && is_array($cluster['explore_courses'])) {
                $coursesText .= implode(', ', $cluster['explore_courses']);
            } else {
                $coursesText .= "N/A";
            }
            $pdf->MultiCell(190, 4, $coursesText, 'LBR', 'L');
            $pdf->Ln(2);
        }
    }
} else {
    $pdf->SetFont('Arial', 'I', 8.5);
    $pdf->Cell(190, 6, 'No cluster recommendations generated.', 1, 1, 'C');
}

$pdf->Ln(4);

// SECTION 5: COUNSELOR NOTES & OFFICIAL SIGN-OFF
$pdf->ChapterTitle('5. Guidance Counselor Notes & Endorsement');
$pdf->SetFont('Arial', '', 9);

$notes = !empty($data['FeedbackNotes']) ? $data['FeedbackNotes'] : 'No written counselor notes attached.';
$reviewedAt = !empty($data['ReviewedAt']) ? $data['ReviewedAt'] : ($data['SubmittedAt'] ?? 'N/A');

$pdf->SetFillColor(250, 250, 250);
$pdf->SetFont('Arial', 'I', 9);
$pdf->MultiCell(190, 5, "Counselor Guidance Notes (Reviewed on $reviewedAt):\n\"$notes\"", 1, 'L', true);

$pdf->Ln(8);

// Signature Section
$pdf->SetFont('Arial', 'B', 9);
$pdf->Cell(110, 4, '', 0, 0);
$pdf->Cell(80, 4, 'OFFICIAL ENDORSEMENT:', 0, 1, 'L');

$pdf->Ln(8);
$pdf->Cell(110, 4, '', 0, 0);
$pdf->Cell(80, 4, '__________________________________', 0, 1, 'L');
$pdf->SetFont('Arial', '', 8.5);
$pdf->Cell(110, 4, '', 0, 0);
$pdf->Cell(80, 4, 'Guidance Counselor Signature / Date', 0, 1, 'L');

// Output PDF
$pdf->Output('I', 'Student_Assessment_Report_' . ($data['StudentID'] ?? '000') . '.pdf');
$conn->close();
?>
