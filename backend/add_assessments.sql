SET FOREIGN_KEY_CHECKS = 0;

-- 1. Alter assessments and assessment_answers constraints
ALTER TABLE assessments ADD COLUMN IF NOT EXISTS AgreedToDisclaimer tinyint(1) NOT NULL DEFAULT 0;
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

-- 3. Create MBI tables
CREATE TABLE IF NOT EXISTS mbi_questions (
    QuestionID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    QuestionText text NOT NULL,
    Subscale varchar(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS mbi_answers (
    AnswerID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    AssessmentID bigint(20) NOT NULL,
    QuestionID bigint(20) NOT NULL,
    Score int(11) NOT NULL,
    FOREIGN KEY (AssessmentID) REFERENCES assessments(AssessmentID) ON DELETE CASCADE,
    FOREIGN KEY (QuestionID) REFERENCES mbi_questions(QuestionID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS mbi_results (
    ResultID bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
    AssessmentID bigint(20) NOT NULL UNIQUE,
    EX_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    CY_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    EF_Score decimal(5,2) NOT NULL DEFAULT 0.00,
    EX_Level varchar(50) NOT NULL,
    CY_Level varchar(50) NOT NULL,
    EF_Level varchar(50) NOT NULL,
    BurnoutStatus varchar(100) NOT NULL,
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

-- 5. Truncate and populate MBI questions
TRUNCATE TABLE mbi_questions;
INSERT INTO mbi_questions (QuestionID, QuestionText, Subscale) VALUES
(1, 'I feel emotionally drained by my studies.', 'EX'),
(2, 'I feel used up at the end of a day at the university/school.', 'EX'),
(3, 'I feel tired when I get up in the morning and have to face another day at the university/school.', 'EX'),
(4, 'I can effectively solve the problems that arise in my studies.', 'EF'),
(5, 'I have become less interested in my studies since my enrollment at the university/school.', 'CY'),
(6, 'I have become less enthusiastic about my studies.', 'CY'),
(7, 'I believe that I make an effective contribution to the classes that I attend.', 'EF'),
(8, 'Studying or attending class is really a strain for me.', 'EX'),
(9, 'I feel stimulated when I achieve my study goals.', 'EF'),
(10, 'In my opinion, I am a good student.', 'EF'),
(11, 'I have become more cynical about the potential usefulness of my studies.', 'CY'),
(12, 'I doubt the significance/value of my studies.', 'CY'),
(13, 'I feel burned out from my studies.', 'EX'),
(14, 'I have learned many interesting things during the course of my studies.', 'EF'),
(15, 'During class, I feel confident that I am effective in getting things done.', 'EF');

SET FOREIGN_KEY_CHECKS = 1;
