-- Migration: Add Psychometrician Role and Two-Stage Assessment Workflow
-- Date: 2026-10-15

-- 1. Insert 'psychometrician' role into roles table
INSERT INTO `roles` (`RoleID`, `RoleName`) 
VALUES (5, 'psychometrician') 
ON DUPLICATE KEY UPDATE `RoleName` = 'psychometrician';

-- 2. Modify assessments Status enum to support the 2-stage workflow
ALTER TABLE `assessments` 
MODIFY COLUMN `Status` ENUM(
    'in_progress', 
    'pending_review', 
    'pending_psychometrician', 
    'pending_counselor', 
    'approved', 
    'declined'
) NOT NULL DEFAULT 'in_progress';

-- 3. Update existing 'pending_review' assessments to 'pending_psychometrician'
UPDATE `assessments` 
SET `Status` = 'pending_psychometrician' 
WHERE `Status` = 'pending_review';

-- 4. Add ReviewerRole, IsStudentVisible, and AiRating to counselor_feedback table
SET @exist_role := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='counselor_feedback' AND COLUMN_NAME='ReviewerRole');
SET @sql_role := IF(@exist_role = 0, 'ALTER TABLE `counselor_feedback` ADD COLUMN `ReviewerRole` ENUM(\'psychometrician\', \'guidance_counselor\') NOT NULL DEFAULT \'guidance_counselor\'', 'SELECT 1');
PREPARE stmt_role FROM @sql_role;
EXECUTE stmt_role;
DEALLOCATE PREPARE stmt_role;

SET @exist_vis := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='counselor_feedback' AND COLUMN_NAME='IsStudentVisible');
SET @sql_vis := IF(@exist_vis = 0, 'ALTER TABLE `counselor_feedback` ADD COLUMN `IsStudentVisible` TINYINT(1) NOT NULL DEFAULT 0', 'SELECT 1');
PREPARE stmt_vis FROM @sql_vis;
EXECUTE stmt_vis;
DEALLOCATE PREPARE stmt_vis;

SET @exist_rating := (SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='counselor_feedback' AND COLUMN_NAME='AiRating');
SET @sql_rating := IF(@exist_rating = 0, 'ALTER TABLE `counselor_feedback` ADD COLUMN `AiRating` TINYINT(1) NULL DEFAULT NULL', 'SELECT 1');
PREPARE stmt_rating FROM @sql_rating;
EXECUTE stmt_rating;
DEALLOCATE PREPARE stmt_rating;

-- 5. Seed test Psychometrician account (password: 123456)
INSERT INTO `counselors` (`RoleID`, `FirstName`, `LastName`, `Email`, `Password`, `IsBlocked`)
VALUES (5, 'Patricia', 'Reyes', 'psychometrician@school.com', '$2y$10$CKmjC.lXJHuDLjhrzkhmTuy7t7vyAcQR6bQ78nzlxLze5vNohUdIm', 0)
ON DUPLICATE KEY UPDATE `RoleID` = 5, `FirstName` = 'Patricia', `LastName` = 'Reyes';
