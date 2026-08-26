SET SESSION sql_require_primary_key = 0;
-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Mar 13, 2026 at 03:06 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `riasec_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `assessments`
--

CREATE TABLE `assessments` (
  `AssessmentID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `StudentID` bigint(20) NOT NULL,
  `PI_ID` bigint(20) NOT NULL,
  `Status` enum('in_progress','pending_review','approved','declined') NOT NULL DEFAULT 'in_progress',
  `StartedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  `SubmittedAt` timestamp NULL DEFAULT NULL,
  KEY `StudentID` (`StudentID`),
  KEY `PI_ID` (`PI_ID`),
  KEY `idx_assessment_status` (`Status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `assessment_answers`
--

CREATE TABLE `assessment_answers` (
  `AnswerID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `AssessmentID` bigint(20) NOT NULL,
  `QuestionID` bigint(20) NOT NULL,
  `Score` int(11) NOT NULL DEFAULT 3 CHECK (`Score` between 1 and 5),
  KEY `AssessmentID` (`AssessmentID`),
  KEY `QuestionID` (`QuestionID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `assessment_results`
--

CREATE TABLE `assessment_results` (
  `ResultID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `AssessmentID` bigint(20) NOT NULL UNIQUE,
  `R_Score` int(11) NOT NULL DEFAULT 0,
  `I_Score` int(11) NOT NULL DEFAULT 0,
  `A_Score` int(11) NOT NULL DEFAULT 0,
  `S_Score` int(11) NOT NULL DEFAULT 0,
  `E_Score` int(11) NOT NULL DEFAULT 0,
  `C_Score` int(11) NOT NULL DEFAULT 0,
  `R_Percentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `I_Percentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `A_Percentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `S_Percentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `E_Percentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `C_Percentage` decimal(5,2) NOT NULL DEFAULT 0.00,
  `PrimaryType` char(1) DEFAULT NULL,
  `SecondaryType` char(1) DEFAULT NULL,
  `TertiaryType` char(1) DEFAULT NULL,
  `CalculatedAt` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `counselors`
--

CREATE TABLE `counselors` (
  `CounselorID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `RoleID` bigint(20) NOT NULL DEFAULT 2,
  `FirstName` varchar(100) NOT NULL,
  `LastName` varchar(100) NOT NULL,
  `Email` varchar(150) NOT NULL UNIQUE,
  `Password` varchar(255) NOT NULL,
  `IsBlocked` TINYINT(1) NOT NULL DEFAULT 0,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `RoleID` (`RoleID`),
  KEY `idx_counselor_name` (`FirstName`, `LastName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci AUTO_INCREMENT=2;

--
-- Dumping data for table `counselors`
--

INSERT INTO `counselors` (`CounselorID`, `RoleID`, `FirstName`, `LastName`, `Email`, `Password`, `CreatedAt`) VALUES
(1, 2, 'Maria', 'Santos', 'counselor@school.com', '$2y$10$3GQlCqHy4nNH6c/EF3bP0ecqMOVdMHyLpboVYckRZgnlTN1ufWTuu', '2026-03-12 01:18:11');

-- --------------------------------------------------------

--
-- Table structure for table `counselor_feedback`
--

CREATE TABLE `counselor_feedback` (
  `FeedbackID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `AssessmentID` bigint(20) NOT NULL,
  `CounselorID` bigint(20) NOT NULL,
  `Action` enum('approved','declined','modified') NOT NULL,
  `ModifiedCourseID` bigint(20) DEFAULT NULL,
  `FeedbackNotes` text DEFAULT NULL,
  `ReviewedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `AssessmentID` (`AssessmentID`),
  KEY `CounselorID` (`CounselorID`),
  KEY `ModifiedCourseID` (`ModifiedCourseID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `live_sessions`
--

CREATE TABLE `live_sessions` (
  `SessionID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `AssessmentID` bigint(20) NOT NULL,
  `StudentID` bigint(20) NOT NULL,
  `PI_ID` bigint(20) NOT NULL,
  `CurrentQuestion` int(11) NOT NULL DEFAULT 1,
  `TotalQuestions` int(11) NOT NULL DEFAULT 77,
  `Duration` bigint(20) NOT NULL DEFAULT 0,
  `IsActive` tinyint(1) NOT NULL DEFAULT 1,
  `StartedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `AssessmentID` (`AssessmentID`),
  KEY `StudentID` (`StudentID`),
  KEY `PI_ID` (`PI_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `personal_information`
--

CREATE TABLE `personal_information` (
  `PI_ID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `StudentID` bigint(20) NOT NULL,
  `FirstName` varchar(100) NOT NULL,
  `LastName` varchar(100) NOT NULL,
  `MiddleName` varchar(100) DEFAULT NULL,
  `Suffix` varchar(20) DEFAULT NULL,
  `Birthdate` date NOT NULL,
  `Age` int(11) NOT NULL,
  `Gender` varchar(30) NOT NULL,
  `Strand` varchar(150) NOT NULL,
  `GradeLevel` varchar(20) NOT NULL,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `StudentID` (`StudentID`),
  KEY `idx_pi_name` (`FirstName`, `LastName`),
  KEY `idx_pi_strand` (`Strand`),
  KEY `idx_pi_grade` (`GradeLevel`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `riasec_courses`
--

CREATE TABLE `riasec_courses` (
  `CourseID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `CourseName` varchar(200) NOT NULL,
  `CourseCode` varchar(50) DEFAULT NULL,
  `RIASECCategory` char(1) NOT NULL CHECK (`RIASECCategory` in ('R','I','A','S','E','C')),
  `Description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci AUTO_INCREMENT=38;

--
-- Dumping data for table `riasec_courses`
--

INSERT INTO `riasec_courses` (`CourseID`, `CourseName`, `CourseCode`, `RIASECCategory`, `Description`) VALUES
(1, 'Bachelor of Science in Civil Engineering', 'BSCE', 'R', 'Focuses on design and construction of infrastructure such as roads, bridges, and buildings.'),
(2, 'Bachelor of Science in Mechanical Engineering', 'BSME', 'R', 'Covers design, manufacturing, and maintenance of mechanical systems.'),
(3, 'Bachelor of Science in Electrical Engineering', 'BSEE', 'R', 'Deals with electrical systems, power generation, and electronics.'),
(4, 'Bachelor of Science in Agriculture', 'BSA', 'R', 'Covers crop production, animal science, and farm management.'),
(5, 'Bachelor of Science in Architecture', 'BSArch', 'R', 'Focuses on building design, planning, and construction.'),
(6, 'Bachelor of Science in Industrial Technology', 'BSIT-Tech', 'R', 'Technical and vocational education in industrial trades.'),
(7, 'Bachelor of Science in Computer Science', 'BSCS', 'I', 'Study of algorithms, programming, and computational theory.'),
(8, 'Bachelor of Science in Information Technology', 'BSIT', 'I', 'Focuses on software development, networking, and IT management.'),
(9, 'Bachelor of Science in Biology', 'BSBio', 'I', 'Study of living organisms and biological processes.'),
(10, 'Bachelor of Science in Chemistry', 'BSChem', 'I', 'Covers chemical processes, laboratory methods, and research.'),
(11, 'Bachelor of Science in Physics', 'BSPhysics', 'I', 'Study of matter, energy, and the fundamental forces of nature.'),
(12, 'Bachelor of Science in Mathematics', 'BSMath', 'I', 'Advanced study of mathematical theory and applications.'),
(13, 'Bachelor of Science in Data Science', 'BSDS', 'I', 'Combines statistics, programming, and data analysis.'),
(14, 'Bachelor of Fine Arts', 'BFA', 'A', 'Study of visual arts including painting, sculpture, and design.'),
(15, 'Bachelor of Arts in Communication', 'BAComm', 'A', 'Covers media, journalism, public relations, and creative writing.'),
(16, 'Bachelor of Science in Interior Design', 'BSID', 'A', 'Focuses on interior space planning and aesthetic design.'),
(17, 'Bachelor of Music', 'BMus', 'A', 'Study of music performance, theory, and composition.'),
(18, 'Bachelor of Arts in Literature', 'BALit', 'A', 'Study of literary works, creative writing, and language arts.'),
(19, 'Bachelor of Science in Fashion Design', 'BSFD', 'A', 'Covers clothing design, textiles, and fashion industry.'),
(20, 'Bachelor of Science in Nursing', 'BSN', 'S', 'Prepares students for patient care and health services.'),
(21, 'Bachelor of Science in Social Work', 'BSSW', 'S', 'Focuses on community development and welfare services.'),
(22, 'Bachelor of Secondary Education', 'BSEd', 'S', 'Prepares students to teach at the secondary level.'),
(23, 'Bachelor of Elementary Education', 'BEEd', 'S', 'Prepares students to teach at the elementary level.'),
(24, 'Bachelor of Science in Psychology', 'BSPsych', 'S', 'Study of human behavior, mental processes, and counseling.'),
(25, 'Bachelor of Science in Physical Therapy', 'BSPT', 'S', 'Focuses on rehabilitation and physical health services.'),
(26, 'Doctor of Medicine', 'MD', 'S', 'Professional degree for medical practice and patient care.'),
(27, 'Bachelor of Science in Business Administration', 'BSBA', 'E', 'Covers management, marketing, finance, and entrepreneurship.'),
(28, 'Bachelor of Science in Entrepreneurship', 'BSEntrep', 'E', 'Focuses on starting and managing business ventures.'),
(29, 'Bachelor of Science in Marketing', 'BSMktg', 'E', 'Study of market analysis, advertising, and sales strategies.'),
(30, 'Bachelor of Science in Hospitality Management', 'BSHM', 'E', 'Covers hotel, tourism, and hospitality industry management.'),
(31, 'Bachelor of Science in Tourism Management', 'BSTM', 'E', 'Focuses on travel, tourism operations, and destination management.'),
(32, 'Bachelor of Laws', 'LLB', 'E', 'Professional law degree covering legal systems and practice.'),
(33, 'Bachelor of Science in Accountancy', 'BSA-Acc', 'C', 'Covers financial accounting, auditing, and taxation.'),
(34, 'Bachelor of Science in Office Administration', 'BSOA', 'C', 'Focuses on office management, records, and administrative tasks.'),
(35, 'Bachelor of Science in Library and Information Science', 'BSLIS', 'C', 'Study of library management and information organization.'),
(36, 'Bachelor of Science in Statistics', 'BSStat', 'C', 'Covers data collection, analysis, and statistical methods.'),
(37, 'Bachelor of Science in Financial Management', 'BSFM', 'C', 'Focuses on financial planning, investment, and risk management.');

-- --------------------------------------------------------

--
-- Table structure for table `riasec_questions`
--

CREATE TABLE `riasec_questions` (
  `QuestionID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `QuestionText` text NOT NULL,
  `RIASECCategory` char(1) NOT NULL CHECK (`RIASECCategory` in ('R','I','A','S','E','C'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci AUTO_INCREMENT=43;

--
-- Dumping data for table `riasec_questions`
--

INSERT INTO `riasec_questions` (`QuestionID`, `QuestionText`, `RIASECCategory`) VALUES
(1, 'I like to work on cars', 'R'),
(2, 'I like to do puzzles', 'I'),
(3, 'I am good at working independently', 'R'),
(4, 'I like to work in teams', 'S'),
(5, 'I am an ambitious person, I set goals for myself', 'E'),
(6, 'I like to organize things (files, desks/offices)', 'C'),
(7, 'I like to build things', 'R'),
(8, 'I like to read about art and music', 'A'),
(9, 'I like to have clear instructions to follow', 'C'),
(10, 'I like to try to influence or persuade people', 'E'),
(11, 'I like to do experiments', 'I'),
(12, 'I like to teach or train people', 'S'),
(13, 'I like trying to help people solve their problems', 'S'),
(14, 'I like to take care of animals', 'R'),
(15, 'I wouldn\'t mind working 8 hours per day in an office', 'C'),
(16, 'I like selling things', 'E'),
(17, 'I enjoy creative writing', 'A'),
(18, 'I enjoy science', 'I'),
(19, 'I am quick to take on new responsibilities', 'E'),
(20, 'I am interested in healing people', 'S'),
(21, 'I enjoy trying to figure out how things work', 'R'),
(22, 'I like putting things together or assembling things', 'R'),
(23, 'I am a creative person', 'A'),
(24, 'I pay attention to details', 'C'),
(25, 'I like to do filing or typing', 'C'),
(26, 'I like to analyze things (problems/situations)', 'I'),
(27, 'I like to play instruments or sing', 'A'),
(28, 'I enjoy learning about other cultures', 'S'),
(29, 'I would like to start my own business', 'E'),
(30, 'I like to cook', 'R'),
(31, 'I like acting in plays', 'A'),
(32, 'I am a practical person', 'R'),
(33, 'I like working with numbers or charts', 'I'),
(34, 'I like to get into discussions about issues', 'I'),
(35, 'I am good at keeping records of my work', 'C'),
(36, 'I like to lead', 'E'),
(37, 'I like working outdoors', 'R'),
(38, 'I would like to work in an office', 'C'),
(39, 'I\'m good at math', 'I'),
(40, 'I like helping people', 'S'),
(41, 'I like to draw', 'A'),
(42, 'I like to give speeches', 'E');

-- --------------------------------------------------------

--
-- Table structure for table `riasec_recommendations`
--

CREATE TABLE `riasec_recommendations` (
  `RecommendationID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `ResultID` bigint(20) NOT NULL,
  `CourseID` bigint(20) NOT NULL,
  `MatchScore` decimal(5,2) NOT NULL DEFAULT 0.00,
  `Explanation` text DEFAULT NULL,
  `Rank` int(11) NOT NULL,
  `GeneratedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `ResultID` (`ResultID`),
  KEY `CourseID` (`CourseID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `roles`
--

CREATE TABLE `roles` (
  `RoleID` bigint(20) NOT NULL PRIMARY KEY AUTO_INCREMENT,
  `RoleName` char(50) NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci AUTO_INCREMENT=3;

--
-- Dumping data for table `roles`
--

INSERT INTO `roles` (`RoleID`, `RoleName`) VALUES
(2, 'guidance_counselor'),
(1, 'student');

-- --------------------------------------------------------

--
-- Table structure for table `students`
--

CREATE TABLE `students` (
  `StudentID` bigint(20) NOT NULL PRIMARY KEY,
  `RoleID` bigint(20) NOT NULL DEFAULT 1,
  `FirstName` varchar(100) NOT NULL,
  `LastName` varchar(100) NOT NULL,
  `Email` varchar(150) NOT NULL UNIQUE,
  `Password` varchar(255) NOT NULL,
  `IsBlocked` TINYINT(1) NOT NULL DEFAULT 0,
  `CreatedAt` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `RoleID` (`RoleID`),
  KEY `idx_student_name` (`FirstName`, `LastName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `students`
--

INSERT INTO `students` (`StudentID`, `RoleID`, `FirstName`, `LastName`, `Email`, `Password`, `CreatedAt`) VALUES
(2024001, 1, 'Juan', 'Dela Cruz', 'juan@school.com', '$2y$10$vCzIKnJLe3k0DoRpYWCS8.IROhLfp8y.YQgyJvyBMikJfzvac2Hxq', '2026-03-12 01:18:11');

--
-- Constraints for dumped tables
--

--
-- Constraints for table `assessments`
--
ALTER TABLE `assessments`
  ADD CONSTRAINT `assessments_ibfk_1` FOREIGN KEY (`StudentID`) REFERENCES `students` (`StudentID`),
  ADD CONSTRAINT `assessments_ibfk_2` FOREIGN KEY (`PI_ID`) REFERENCES `personal_information` (`PI_ID`);

--
-- Constraints for table `assessment_answers`
--
ALTER TABLE `assessment_answers`
  ADD CONSTRAINT `assessment_answers_ibfk_1` FOREIGN KEY (`AssessmentID`) REFERENCES `assessments` (`AssessmentID`),
  ADD CONSTRAINT `assessment_answers_ibfk_2` FOREIGN KEY (`QuestionID`) REFERENCES `riasec_questions` (`QuestionID`);

--
-- Constraints for table `assessment_results`
--
ALTER TABLE `assessment_results`
  ADD CONSTRAINT `assessment_results_ibfk_1` FOREIGN KEY (`AssessmentID`) REFERENCES `assessments` (`AssessmentID`);

--
-- Constraints for table `counselors`
--
ALTER TABLE `counselors`
  ADD CONSTRAINT `counselors_ibfk_1` FOREIGN KEY (`RoleID`) REFERENCES `roles` (`RoleID`);

--
-- Constraints for table `counselor_feedback`
--
ALTER TABLE `counselor_feedback`
  ADD CONSTRAINT `counselor_feedback_ibfk_1` FOREIGN KEY (`AssessmentID`) REFERENCES `assessments` (`AssessmentID`),
  ADD CONSTRAINT `counselor_feedback_ibfk_2` FOREIGN KEY (`CounselorID`) REFERENCES `counselors` (`CounselorID`),
  ADD CONSTRAINT `counselor_feedback_ibfk_3` FOREIGN KEY (`ModifiedCourseID`) REFERENCES `riasec_courses` (`CourseID`);

--
-- Constraints for table `live_sessions`
--
ALTER TABLE `live_sessions`
  ADD CONSTRAINT `live_sessions_ibfk_1` FOREIGN KEY (`AssessmentID`) REFERENCES `assessments` (`AssessmentID`),
  ADD CONSTRAINT `live_sessions_ibfk_2` FOREIGN KEY (`StudentID`) REFERENCES `students` (`StudentID`),
  ADD CONSTRAINT `live_sessions_ibfk_3` FOREIGN KEY (`PI_ID`) REFERENCES `personal_information` (`PI_ID`);

--
-- Constraints for table `personal_information`
--
ALTER TABLE `personal_information`
  ADD CONSTRAINT `personal_information_ibfk_1` FOREIGN KEY (`StudentID`) REFERENCES `students` (`StudentID`);

--
-- Constraints for table `riasec_recommendations`
--
ALTER TABLE `riasec_recommendations`
  ADD CONSTRAINT `riasec_recommendations_ibfk_1` FOREIGN KEY (`ResultID`) REFERENCES `assessment_results` (`ResultID`),
  ADD CONSTRAINT `riasec_recommendations_ibfk_2` FOREIGN KEY (`CourseID`) REFERENCES `riasec_courses` (`CourseID`);

--
-- Constraints for table `students`
--
ALTER TABLE `students`
  ADD CONSTRAINT `students_ibfk_1` FOREIGN KEY (`RoleID`) REFERENCES `roles` (`RoleID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
