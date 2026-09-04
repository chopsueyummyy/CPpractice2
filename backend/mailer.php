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

    $subject = 'Your RIASEC Assessment has been ' . ucfirst($status);
    $body = "<h2>Hello $studentName,</h2>";
    $body .= "<p>Your recent RIASEC Assessment has been marked as <strong>" . ucfirst($status) . "</strong> by the counselor.</p>";
    if (!empty($notes)) {
        $body .= "<div style='background-color:#f8f9fa; padding:15px; border-left:4px solid #6c5ce7; margin:20px 0;'>
                    <strong>Counselor Notes:</strong><br>" . nl2br(htmlspecialchars($notes)) . "
                  </div>";
    }
    $body .= "<br><p>Thank you,</p><p>Guidance Office</p>";

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
