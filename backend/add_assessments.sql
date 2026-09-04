SET FOREIGN_KEY_CHECKS = 0;

-- 1. Alter assessments and assessment_answers constraints
-- Note: AgreedToDisclaimer column is already created in the main schema.
-- If not present, run: ALTER TABLE assessments ADD COLUMN AgreedToDisclaimer tinyint(1) NOT NULL DEFAULT 0;
ALTER TABLE assessment_answers ALTER Score SET DEFAULT 0;

-- 2. Create RSE tables
CREATE TABLE IF NOT EXISTS rse_questions (
    QuestionID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    QuestionText text NOT NULL,
    IsNegative tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS rse_answers (
    AnswerID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    AssessmentID bigint(20) NOT NULL,
    QuestionID bigint(20) NOT NULL,
    Score int(11) NOT NULL,
    FOREIGN KEY (AssessmentID) REFERENCES assessments(AssessmentID) ON DELETE CASCADE,
    FOREIGN KEY (QuestionID) REFERENCES rse_questions(QuestionID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS rse_results (
    ResultID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    AssessmentID bigint(20) NOT NULL UNIQUE,
    Score int(11) NOT NULL,
    Level varchar(50) NOT NULL,
    CalculatedAt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (AssessmentID) REFERENCES assessments(AssessmentID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Create CDSES tables
CREATE TABLE IF NOT EXISTS cdses_questions (
    QuestionID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    QuestionText text NOT NULL,
    Subscale varchar(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS cdses_answers (
    AnswerID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    AssessmentID bigint(20) NOT NULL,
    QuestionID bigint(20) NOT NULL,
    Score int(11) NOT NULL,
    FOREIGN KEY (AssessmentID) REFERENCES assessments(AssessmentID) ON DELETE CASCADE,
    FOREIGN KEY (QuestionID) REFERENCES cdses_questions(QuestionID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS cdses_results (
    ResultID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    AssessmentID bigint(20) NOT NULL UNIQUE,
    SA_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    OI_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    GS_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    PL_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    PS_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    TotalScore decimal(5,2) NOT NULL DEFAULT 0.00,
    SelfEfficacyLevel varchar(100) NOT NULL,
    CalculatedAt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (AssessmentID) REFERENCES assessments(AssessmentID) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Truncate and populate RSE questions
TRUNCATE TABLE rse_questions;
INSERT INTO rse_questions (QuestionID, QuestionText, IsNegative) VALUES
(1, 'On the whole, I am satisfied with myself.', 0),
(2, 'At times I think I am no good at all.', 1),
(3, 'I feel that I have a number of good qualities.', 0),
(4, 'I am able to do things as well as most other people.', 0),
(5, 'I feel I do not have much to be proud of.', 1),
(6, 'I certainly feel useless at times.', 1),
(7, 'I feel that I\'m a person of worth.', 0),
(8, 'I wish I could have more respect for myself.', 1),
(9, 'All in all, I am inclined to think that I am a failure.', 1),
(10, 'I take a positive attitude toward myself.', 0);

-- 5. Truncate and populate CDSES questions
TRUNCATE TABLE cdses_questions;
INSERT INTO cdses_questions (QuestionID, QuestionText, Subscale) VALUES
(1, 'Find information in the library or online about occupations you are interested in', 'OI'),
(2, 'Select one major from a list of potential majors you are considering', 'GS'),
(3, 'Make a plan of your goals for the next five years', 'PL'),
(4, 'Determine the steps to take if you are having academic trouble with an aspect of your chosen major', 'PS'),
(5, 'Accurately assess your abilities', 'SA'),
(6, 'Select one occupation from a list of potential occupations you are considering', 'GS'),
(7, 'Determine the steps you need to take to successfully complete your chosen major', 'PL'),
(8, 'Persistently work at your major or career goal even when you get frustrated', 'PS'),
(9, 'Determine what your ideal job would be', 'SA'),
(10, 'Find out the employment trends for an occupation over the next ten years', 'OI'),
(11, 'Choose a career that will fit your preferred lifestyle', 'GS'),
(12, 'Prepare a good resume', 'PL'),
(13, 'Change majors if you did not like your first choice', 'PS'),
(14, 'Decide what you value most in an occupation', 'SA'),
(15, 'Find out about the average yearly earnings of people in an occupation', 'OI'),
(16, 'Make a career decision and then not worry whether it was right or wrong', 'GS'),
(17, 'Change occupations if you are not satisfied with the one you enter', 'PS'),
(18, 'Figure out what you are and are not ready to sacrifice to achieve your career goals', 'SA'),
(19, 'Talk with a person already employed in a field you are interested in', 'OI'),
(20, 'Choose a major or career that will fit your interests', 'GS'),
(21, 'Identify employers, firms, and institutions relevant to your career possibilities', 'OI'),
(22, 'Define the type of lifestyle you would like to live', 'SA'),
(23, 'Find information about graduate or professional schools', 'PL'),
(24, 'Successfully manage the job interview process', 'PL'),
(25, 'Identify some reasonable major or career alternatives if you are unable to get your first choice', 'PS');

-- 6. Create Admin and Logging tables
INSERT IGNORE INTO `roles` (`RoleID`, `RoleName`) VALUES 
(3, 'admin'),
(4, 'super_admin');

CREATE TABLE IF NOT EXISTS `admins` (
  `AdminID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `RoleID` bigint(20) NOT NULL DEFAULT 3,
  `FirstName` varchar(100) NOT NULL,
  `LastName` varchar(100) NOT NULL,
  `Email` varchar(150) NOT NULL UNIQUE,
  `Password` varchar(255) NOT NULL,
  `OTP_Code` varchar(20) DEFAULT NULL,
  `OTP_Expiry` datetime DEFAULT NULL,
  `IsBlocked` tinyint(1) NOT NULL DEFAULT 0,
  `LastLogin` datetime DEFAULT NULL,
  KEY `RoleID` (`RoleID`),
  CONSTRAINT `admins_ibfk_1` FOREIGN KEY (`RoleID`) REFERENCES `roles` (`RoleID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `admins` (`AdminID`, `RoleID`, `FirstName`, `LastName`, `Email`, `Password`) VALUES
(1, 4, 'Super', 'Admin', 'admin@school.com', '$2y$10$ihpU8TArBKpkHGFLLVdv.OWqA54WMhQVeVbWwOm8fW8aCzu8KEzx.');

CREATE TABLE IF NOT EXISTS `system_logs` (
  `LogID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `AdminID` bigint(20) NOT NULL,
  `Action` varchar(100) NOT NULL,
  `TargetType` varchar(50) NOT NULL,
  `TargetID` varchar(50) DEFAULT NULL,
  `Details` text DEFAULT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY `AdminID` (`AdminID`),
  CONSTRAINT `system_logs_ibfk_1` FOREIGN KEY (`AdminID`) REFERENCES `admins` (`AdminID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

SET FOREIGN_KEY_CHECKS = 1;
