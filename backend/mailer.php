<?php
function sendOTPEmail($toEmail, $firstName, $otpCode) {
    $subject = "Your RIASEC Account Verification Code";
    $body = "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e1e1e1; border-radius: 8px; overflow: hidden;'>
            <div style='background-color: #6c5ce7; color: white; padding: 20px; text-align: center;'>
                <h1 style='margin:0;'>Project Citadel</h1>
                <p style='margin:0;'>Secure Admin Access</p>
            </div>
            <div style='padding: 30px; line-height: 1.6; color: #333;'>
                <h2>Hello $firstName,</h2>
                <p>You are attempting to log in to the RIASEC Admin System. Please use the following verification code to complete your login:</p>
                <div style='background-color: #f8f9fa; border: 2px dashed #6c5ce7; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0;'>
                    <span style='font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #6c5ce7;'>$otpCode</span>
                </div>
                <p>This code will expire in 10 minutes. If you did not request this code, please ignore this email or contact your system administrator.</p>
                <br>
                <p style='color: #636e72; font-size: 12px;'>Protected by RIASEC Security Suite • Project Citadel</p>
            </div>
        </div>
    ";
    return sendGenericEmail($toEmail, $firstName, $subject, $body);
}

function sendAssessmentEmail($toEmail, $studentName, $status, $notes, $adminEmail = null) {
    if (!$adminEmail) $adminEmail = getenv('SMTP_USER');

    $isApproved = (strtolower($status) === 'approved');
    $subject = $isApproved 
        ? 'Your RIASEC Assessment has been Approved' 
        : 'Action Required: Your RIASEC Assessment Needs Revision';

    $statusTitle = $isApproved ? '✅ Assessment Approved' : '⚠️ Action Required: Retake Permitted';
    $statusBgColor = $isApproved ? '#E8F8F5' : '#FDEDEC';
    $statusBorderColor = $isApproved ? '#27AE60' : '#E74C3C';
    $statusTextColor = $isApproved ? '#1E8449' : '#C0392B';
    $badgeText = $isApproved ? 'APPROVED' : 'RETURNED FOR REVISION';

    $notesHeaderColor = $isApproved ? '#27AE60' : '#E74C3C';
    $notesBgColor = '#f8f9fa';

    $introMessage = $isApproved
        ? 'Great news! Your recent RIASEC Career Assessment has been reviewed and officially <strong>APPROVED</strong> by your Guidance Counselor.'
        : 'Your recent RIASEC Career Assessment has been reviewed by your Guidance Counselor and <strong>RETURNED FOR REVISION</strong>.';

    $nextStepsText = $isApproved
        ? 'Your personalized career recommendations, Holland Code breakdown, and course compatibility reports are now unlocked on your student dashboard.'
        : 'The <strong>Retake Assessment</strong> button is now active on your Student Portal. Please log in, review the counselor guidance notes above, and submit a new assessment.';

    $notesSection = '';
    if (!empty($notes)) {
        $cleanNotes = nl2br(htmlspecialchars($notes));
        $notesSection = "
            <div style='margin-top: 20px; margin-bottom: 20px;'>
                <div style='font-size: 13px; font-weight: bold; color: #2d3436; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px;'>
                    💬 Counselor Notes & Guidance:
                </div>
                <div style='background-color: {$notesBgColor}; padding: 16px; border-left: 4px solid {$notesHeaderColor}; border-radius: 4px; font-size: 14px; color: #2d3436; line-height: 1.5;'>
                    {$cleanNotes}
                </div>
            </div>
        ";
    }

    $body = "
        <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #e1e1e1; border-radius: 10px; overflow: hidden; background-color: #ffffff;'>
            <!-- Header Banner -->
            <div style='background-color: #6c5ce7; color: #ffffff; padding: 24px; text-align: center;'>
                <div style='font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; opacity: 0.9;'>Jose Maria College</div>
                <h2 style='margin: 4px 0 0 0; font-size: 22px; font-weight: bold;'>Guidance & Counseling Office</h2>
            </div>

            <!-- Content Area -->
            <div style='padding: 30px; color: #2d3436; line-height: 1.6;'>
                <h3 style='margin-top: 0; font-size: 18px; color: #2d3436;'>Hello {$studentName},</h3>
                
                <p style='font-size: 15px; color: #4a4a4a;'>{$introMessage}</p>

                <!-- Status Card -->
                <div style='background-color: {$statusBgColor}; border: 1.5px solid {$statusBorderColor}; border-radius: 8px; padding: 16px; margin: 20px 0;'>
                    <div style='font-size: 16px; font-weight: bold; color: {$statusTextColor};'>
                        {$statusTitle}
                    </div>
                    <div style='font-size: 13px; color: #555555; margin-top: 4px;'>
                        Status: <strong>{$badgeText}</strong>
                    </div>
                </div>

                {$notesSection}

                <!-- Next Steps -->
                <div style='margin-top: 20px; padding: 16px; background-color: #f1f2f6; border-radius: 6px;'>
                    <div style='font-size: 14px; font-weight: bold; color: #2d3436; margin-bottom: 4px;'>📌 Next Steps:</div>
                    <div style='font-size: 14px; color: #4a4a4a;'>{$nextStepsText}</div>
                </div>

                <div style='margin-top: 30px; font-size: 14px; color: #2d3436;'>
                    Thank you,<br>
                    <strong>Guidance Office</strong>
                </div>
            </div>
        </div>
    ";

    return sendGenericEmail($toEmail, $studentName, $subject, $body);
}

/**
 * Core mailing logic using .env credentials
 */
function sendGenericEmail($toEmail, $recipientName, $subject, $htmlBody) {
    // PHPMailer requirements
    $exceptionPath = __DIR__ . '/vendor/PHPMailer/src/Exception.php';
    $mailerPath    = __DIR__ . '/vendor/PHPMailer/src/PHPMailer.php';
    $smtpPath      = __DIR__ . '/vendor/PHPMailer/src/SMTP.php';

    if (!file_exists($exceptionPath) || !file_exists($mailerPath) || !file_exists($smtpPath)) {
        error_log("SKIPPING EMAIL: PHPMailer files not found in vendor.");
        return true; 
    }

    require_once $exceptionPath;
    require_once $mailerPath;
    require_once $smtpPath;

    $mail = new PHPMailer\PHPMailer\PHPMailer(true);

    try {
        $mail->isSMTP();
        $mail->Host       = getenv('SMTP_HOST') ?: 'smtp.gmail.com';
        $mail->SMTPAuth   = true;
        $mail->Username   = getenv('SMTP_USER');
        $mail->Password   = getenv('SMTP_PASS');
        $mail->SMTPSecure = (getenv('SMTP_SECURE') === 'tls' ? PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS : PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_SMTPS);
        $mail->Port       = (int)(getenv('SMTP_PORT') ?: 587);
        
        $mail->Timeout    = 7;
        $mail->SMTPConnectTimeout = 5;

        $mail->setFrom($mail->Username, 'RIASEC Assessment System');
        $mail->addAddress($toEmail, $recipientName);

        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body    = $htmlBody;
        $mail->AltBody = strip_tags($htmlBody);

        $mail->send();
        $safeToEmail = preg_replace('/[\r\n]/', '', $toEmail);
        error_log("SUCCESS: Email sent to $safeToEmail");
        return true;
    } catch (Exception $e) {
        $safeToEmail = preg_replace('/[\r\n]/', '', $toEmail);
        error_log("MAILER ERROR (Email to $safeToEmail): {$mail->ErrorInfo}");
        return false;
    }
}
?>
