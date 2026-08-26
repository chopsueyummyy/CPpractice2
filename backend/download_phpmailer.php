<?php
$url = "https://github.com/PHPMailer/PHPMailer/archive/refs/heads/master.zip";
$zipPath = __DIR__ . "/phpmailer.zip";
$vendorPath = __DIR__ . "/vendor";

file_put_contents($zipPath, file_get_contents($url));
$zip = new ZipArchive;
if ($zip->open($zipPath) === TRUE) {
    $zip->extractTo($vendorPath . '/');
    $zip->close();
    rename($vendorPath . '/PHPMailer-master', $vendorPath . '/PHPMailer');
    unlink($zipPath);
    echo "PHPMailer installed successfully.";
} else {
    echo "Failed to install PHPMailer.";
}
?>
