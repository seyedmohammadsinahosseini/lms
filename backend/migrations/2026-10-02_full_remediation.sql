-- OTMS migration: c89f74a schema -> secure/versioned 2.0 schema
-- Backup first. Run exactly once against the selected OTMS database.
-- Tested target syntax: MariaDB 10.11+ / MySQL 8+.
SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(80) PRIMARY KEY,
  applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

START TRANSACTION;

CREATE TABLE demo_sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  public_id CHAR(32) NOT NULL UNIQUE,
  access_key_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_by_ip_hash CHAR(64) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_demo_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE users
  ADD COLUMN demo_session_id BIGINT UNSIGNED NULL AFTER id,
  ADD COLUMN avatar_file_id BIGINT UNSIGNED NULL AFTER role,
  ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at,
  ADD INDEX idx_users_demo (demo_session_id),
  ADD CONSTRAINT fk_users_demo FOREIGN KEY (demo_session_id) REFERENCES demo_sessions(id) ON DELETE CASCADE;

-- Replace plaintext-token primary key with a numeric key and token hash. Old
-- clients remain signed in because their raw token hashes to the migrated value.
CREATE TABLE sessions_v2 (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  token_hash CHAR(64) NOT NULL UNIQUE,
  csrf_token_hash CHAR(64) NULL,
  user_id INT NOT NULL,
  device_name VARCHAR(160) NULL,
  expires_at DATETIME NOT NULL,
  last_used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_sessions_user (user_id),
  INDEX idx_sessions_expiry (expires_at),
  CONSTRAINT fk_sessions_user_v2 FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO sessions_v2 (token_hash, user_id, expires_at, created_at)
  SELECT SHA2(token, 256), user_id, expires_at, created_at FROM sessions;
DROP TABLE sessions;
RENAME TABLE sessions_v2 TO sessions;

CREATE TABLE rate_limits (
  bucket VARCHAR(40) NOT NULL,
  subject_hash CHAR(64) NOT NULL,
  hit_count INT UNSIGNED NOT NULL DEFAULT 1,
  window_started_at DATETIME NOT NULL,
  blocked_until DATETIME NULL,
  PRIMARY KEY (bucket, subject_hash),
  INDEX idx_rate_expiry (window_started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE teacher_invites (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  code_hash CHAR(64) NOT NULL UNIQUE,
  created_by INT NULL,
  expires_at DATETIME NOT NULL,
  used_by INT NULL,
  used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_teacher_invite_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_teacher_invite_user FOREIGN KEY (used_by) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE teacher_codes
  MODIFY code VARCHAR(16) NOT NULL,
  ADD INDEX idx_teacher_codes_active (teacher_id, active);
ALTER TABLE classes
  ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at,
  ADD INDEX idx_classes_teacher (teacher_id, created_at);
ALTER TABLE enrollments
  ADD INDEX idx_enrollments_student (student_id, joined_at);

CREATE TABLE join_grants (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  token_hash CHAR(64) NOT NULL UNIQUE,
  student_id INT NOT NULL,
  teacher_id INT NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_join_grant_expiry (expires_at),
  CONSTRAINT fk_join_grant_student FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_join_grant_teacher FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE lessons
  MODIFY position INT UNSIGNED NOT NULL DEFAULT 0,
  ADD UNIQUE KEY uq_lesson_position (class_id, position),
  ADD INDEX idx_lessons_class (class_id, position);

CREATE TABLE stored_files (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id INT NOT NULL,
  storage_name VARCHAR(80) NOT NULL UNIQUE,
  original_name VARCHAR(255) NOT NULL,
  mime_type VARCHAR(120) NOT NULL,
  byte_size BIGINT UNSIGNED NOT NULL,
  sha256 CHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_stored_files_owner (owner_user_id),
  CONSTRAINT fk_stored_files_owner FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
ALTER TABLE users
  ADD CONSTRAINT fk_users_avatar FOREIGN KEY (avatar_file_id) REFERENCES stored_files(id) ON DELETE SET NULL;
ALTER TABLE contents
  CHANGE COLUMN file_path legacy_file_path VARCHAR(300) NULL,
  ADD COLUMN file_id BIGINT UNSIGNED NULL AFTER url,
  ADD INDEX idx_contents_lesson (lesson_id, created_at),
  ADD CONSTRAINT fk_contents_file FOREIGN KEY (file_id) REFERENCES stored_files(id) ON DELETE SET NULL;

ALTER TABLE assessments
  MODIFY duration_min INT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN status ENUM('draft','published','closed') NOT NULL DEFAULT 'published' AFTER kind,
  ADD COLUMN max_attempts INT UNSIGNED NOT NULL DEFAULT 1 AFTER duration_min,
  ADD COLUMN opens_at DATETIME NULL AFTER max_attempts,
  ADD COLUMN closes_at DATETIME NULL AFTER opens_at,
  ADD COLUMN answer_release_policy ENUM('immediately','after_close','teacher_release','never') NOT NULL DEFAULT 'teacher_release' AFTER closes_at,
  ADD COLUMN answers_released_at DATETIME NULL AFTER answer_release_policy,
  ADD COLUMN current_version_no INT UNSIGNED NOT NULL DEFAULT 1 AFTER answers_released_at,
  ADD COLUMN published_at DATETIME NULL AFTER current_version_no,
  ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at,
  ADD INDEX idx_assessments_class (class_id, status, created_at);
UPDATE assessments SET published_at = created_at;

CREATE TABLE assessment_versions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  assessment_id INT NOT NULL,
  version_no INT UNSIGNED NOT NULL,
  is_published TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  published_at DATETIME NULL,
  UNIQUE KEY uq_assessment_version (assessment_id, version_no),
  CONSTRAINT fk_assessment_versions_assessment FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO assessment_versions (assessment_id, version_no, is_published, created_at, published_at)
  SELECT id, 1, 1, created_at, created_at FROM assessments;

ALTER TABLE questions
  MODIFY type ENUM('multiple_choice','single_choice','multiple_select','true_false','yes_no','fill_blank','essay') NOT NULL,
  MODIFY points DECIMAL(7,2) UNSIGNED NOT NULL DEFAULT 1,
  MODIFY position INT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN assessment_version_id BIGINT UNSIGNED NULL AFTER id;
UPDATE questions q JOIN assessment_versions av ON av.assessment_id = q.assessment_id AND av.version_no = 1
  SET q.assessment_version_id = av.id;
-- Preserve existing multi-correct data instead of silently forcing radio semantics.
UPDATE questions q SET q.type = CASE
  WHEN (SELECT COUNT(*) FROM options o WHERE o.question_id = q.id AND o.is_correct = 1) > 1
    THEN 'multiple_select' ELSE 'single_choice' END
  WHERE q.type = 'multiple_choice';
ALTER TABLE questions
  DROP FOREIGN KEY questions_ibfk_1,
  DROP COLUMN assessment_id,
  MODIFY assessment_version_id BIGINT UNSIGNED NOT NULL,
  MODIFY type ENUM('single_choice','multiple_select','true_false','yes_no','fill_blank','essay') NOT NULL,
  ADD UNIQUE KEY uq_question_position (assessment_version_id, position),
  ADD INDEX idx_questions_version (assessment_version_id, position),
  ADD CONSTRAINT fk_questions_version FOREIGN KEY (assessment_version_id) REFERENCES assessment_versions(id) ON DELETE CASCADE;

ALTER TABLE options
  ADD COLUMN position INT UNSIGNED NOT NULL DEFAULT 0 AFTER is_correct;
UPDATE options SET position = id;
ALTER TABLE options
  ADD UNIQUE KEY uq_option_position (question_id, position),
  ADD UNIQUE KEY uq_option_question_id (question_id, id);

ALTER TABLE attempts
  MODIFY status ENUM('in_progress','completed','graded','submitted','pending_grading','expired') NOT NULL DEFAULT 'in_progress',
  ADD COLUMN assessment_version_id BIGINT UNSIGNED NULL AFTER assessment_id,
  ADD COLUMN attempt_no INT UNSIGNED NULL AFTER student_id,
  ADD COLUMN deadline_at DATETIME NULL AFTER started_at,
  ADD COLUMN idempotency_key VARCHAR(80) NULL AFTER status;
UPDATE attempts at JOIN assessment_versions av ON av.assessment_id = at.assessment_id AND av.version_no = 1
  SET at.assessment_version_id = av.id;
CREATE TEMPORARY TABLE otms_attempt_numbers AS
  SELECT id, ROW_NUMBER() OVER (PARTITION BY assessment_id, student_id ORDER BY id) AS n FROM attempts;
UPDATE attempts at JOIN otms_attempt_numbers n ON n.id = at.id SET at.attempt_no = n.n;
DROP TEMPORARY TABLE otms_attempt_numbers;
UPDATE attempts SET status = 'pending_grading' WHERE status = 'completed';
ALTER TABLE attempts
  MODIFY assessment_version_id BIGINT UNSIGNED NOT NULL,
  MODIFY attempt_no INT UNSIGNED NOT NULL,
  MODIFY status ENUM('in_progress','submitted','pending_grading','graded','expired') NOT NULL DEFAULT 'in_progress',
  ADD UNIQUE KEY uq_attempt_number (assessment_id, student_id, attempt_no),
  ADD UNIQUE KEY uq_attempt_idempotency (student_id, idempotency_key),
  ADD INDEX idx_attempts_assessment (assessment_id, status),
  ADD INDEX idx_attempts_student (student_id, started_at),
  ADD CONSTRAINT fk_attempts_version FOREIGN KEY (assessment_version_id) REFERENCES assessment_versions(id) ON DELETE RESTRICT;

ALTER TABLE answers
  MODIFY points_earned DECIMAL(7,2) NULL,
  ADD COLUMN grading_status ENUM('auto_graded','pending','graded') NULL AFTER points_earned,
  ADD COLUMN graded_at DATETIME NULL AFTER is_correct;
UPDATE answers SET grading_status = CASE
  WHEN points_earned IS NULL THEN 'pending'
  WHEN is_correct IS NULL THEN 'graded'
  ELSE 'auto_graded' END,
  graded_at = CASE WHEN points_earned IS NULL THEN NULL ELSE NOW() END;
ALTER TABLE answers
  MODIFY grading_status ENUM('auto_graded','pending','graded') NOT NULL,
  ADD UNIQUE KEY uq_answer_attempt_question (attempt_id, question_id),
  ADD UNIQUE KEY uq_answer_question_id (question_id, id);

CREATE TABLE answer_options (
  answer_id INT NOT NULL,
  question_id INT NOT NULL,
  option_id INT NOT NULL,
  PRIMARY KEY (answer_id, option_id),
  CONSTRAINT fk_answer_options_answer_question FOREIGN KEY (question_id, answer_id)
    REFERENCES answers(question_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_answer_options_option_question FOREIGN KEY (question_id, option_id)
    REFERENCES options(question_id, id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO answer_options (answer_id, question_id, option_id)
  SELECT id, question_id, option_id FROM answers WHERE option_id IS NOT NULL;
ALTER TABLE answers DROP FOREIGN KEY answers_ibfk_3, DROP COLUMN option_id;

ALTER TABLE homework
  ADD COLUMN due_at DATETIME NULL AFTER description,
  ADD COLUMN allow_late_submission TINYINT(1) NOT NULL DEFAULT 0 AFTER due_at,
  ADD COLUMN allow_resubmit TINYINT(1) NOT NULL DEFAULT 1 AFTER allow_late_submission,
  ADD COLUMN resubmit_until DATETIME NULL AFTER allow_resubmit;
UPDATE homework SET due_at = CASE WHEN due_date IS NULL THEN NULL ELSE CONCAT(due_date, ' 23:59:59') END;
ALTER TABLE homework DROP COLUMN due_date, ADD INDEX idx_homework_class_due (class_id, due_at);

ALTER TABLE submissions
  ADD COLUMN latest_version_no INT UNSIGNED NOT NULL DEFAULT 1 AFTER student_id,
  ADD COLUMN status ENUM('submitted','late','pending_grading','graded') NOT NULL DEFAULT 'pending_grading' AFTER latest_version_no,
  ADD COLUMN graded_at DATETIME NULL AFTER feedback,
  ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP AFTER graded_at,
  ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP AFTER created_at;
UPDATE submissions SET status = CASE WHEN grade IS NULL AND feedback IS NULL THEN 'pending_grading' ELSE 'graded' END,
  graded_at = CASE WHEN grade IS NULL AND feedback IS NULL THEN NULL ELSE submitted_at END,
  created_at = submitted_at, updated_at = submitted_at;
CREATE TABLE submission_versions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  submission_id INT NOT NULL,
  version_no INT UNSIGNED NOT NULL,
  text TEXT NULL,
  file_id BIGINT UNSIGNED NULL,
  legacy_file_path VARCHAR(300) NULL,
  submitted_at DATETIME NOT NULL,
  is_late TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_submission_version (submission_id, version_no),
  CONSTRAINT fk_submission_versions_submission FOREIGN KEY (submission_id) REFERENCES submissions(id) ON DELETE CASCADE,
  CONSTRAINT fk_submission_versions_file FOREIGN KEY (file_id) REFERENCES stored_files(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT INTO submission_versions (submission_id, version_no, text, legacy_file_path, submitted_at)
  SELECT id, 1, text, file_path, submitted_at FROM submissions;
ALTER TABLE submissions DROP COLUMN text, DROP COLUMN file_path, DROP COLUMN submitted_at,
  ADD INDEX idx_submissions_homework_status (homework_id, status);

ALTER TABLE qa_threads
  ADD INDEX idx_qa_threads_class (class_id, created_at);
ALTER TABLE qa_replies
  ADD INDEX idx_qa_replies_thread (thread_id, created_at);

CREATE TABLE live_sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  class_id INT NOT NULL,
  created_by INT NOT NULL,
  provider ENUM('jitsi','jaas','external') NOT NULL DEFAULT 'jitsi',
  provider_room_id VARCHAR(180) NOT NULL UNIQUE,
  join_url VARCHAR(500) NOT NULL,
  status ENUM('scheduled','live','ended','cancelled') NOT NULL DEFAULT 'live',
  starts_at DATETIME NOT NULL,
  ended_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_live_class_status (class_id, status, starts_at),
  CONSTRAINT fk_live_sessions_class FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
  CONSTRAINT fk_live_sessions_creator FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_events (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  actor_user_id INT NULL,
  event_type VARCHAR(80) NOT NULL,
  entity_type VARCHAR(60) NULL,
  entity_id BIGINT UNSIGNED NULL,
  metadata_json LONGTEXT NULL,
  ip_hash CHAR(64) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_actor_time (actor_user_id, created_at),
  INDEX idx_audit_entity (entity_type, entity_id),
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Old public demo users are intentionally not removed automatically because a
-- real installation may already have changed/used them. Operators must review
-- them explicitly; fresh schema imports never create any default account.
INSERT INTO schema_migrations (version) VALUES ('2026-10-02_full_remediation');
COMMIT;
