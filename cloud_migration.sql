-- RIASEC SYSTEM CLOUD MIGRATION PATCH
-- Run this on your DigitalOcean Managed Database (riasec-db) to synchronize with local security hardening.

-- 1. Update the Status vocabulary to include 'rejected'
ALTER TABLE assessments 
MODIFY Status ENUM('in_progress', 'pending_review', 'approved', 'declined', 'rejected') 
NOT NULL DEFAULT 'in_progress';

-- 2. Update Counselor Feedback vocabulary to match
ALTER TABLE counselor_feedback 
MODIFY Action ENUM('approved', 'declined', 'rejected') 
NOT NULL;

-- 3. (Optional but Recommended) Map old 'declined' data to our new 'rejected' standard
UPDATE assessments SET Status = 'rejected' WHERE Status = 'declined';
UPDATE counselor_feedback SET Action = 'rejected' WHERE Action = 'declined';

-- 4. Verify Column Existence
-- Our code now uses 'StartedAt' instead of 'CreatedAt' to fetch student status.
-- Ensure the 'StartedAt' column is indexed for high-performance dashboard loading.
CREATE INDEX idx_student_started ON assessments(StudentID, StartedAt);
