-- OTMS fresh-install schema (MariaDB 10.11+ / MySQL 8+)
-- Production-safe: this file creates tables only. It does not create/drop a
-- database and it never inserts demo credentials. Select an empty database
-- before importing it. Existing installations must use migrations/.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE demo_sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  public_id CHAR(32) NOT NULL UNIQUE,
  access_key_hash CHAR(64) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_by_ip_hash CHAR(64) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_demo_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE users (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  demo_session_id BIGINT UNSIGNED NULL,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('teacher','student') NOT NULL,
  avatar_file_id BIGINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_users_demo (demo_session_id),
  CONSTRAINT fk_users_demo FOREIGN KEY (demo_session_id)
    REFERENCES demo_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  token_hash CHAR(64) NOT NULL UNIQUE,
  csrf_token_hash CHAR(64) NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  device_name VARCHAR(160) NULL,
  expires_at DATETIME NOT NULL,
  last_used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_sessions_user (user_id),
  INDEX idx_sessions_expiry (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
  created_by BIGINT UNSIGNED NULL,
  expires_at DATETIME NOT NULL,
  used_by BIGINT UNSIGNED NULL,
  used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_teacher_invite_creator FOREIGN KEY (created_by)
    REFERENCES users(id) ON DELETE SET NULL,
  CONSTRAINT fk_teacher_invite_user FOREIGN KEY (used_by)
    REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE teacher_codes (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  teacher_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(16) NOT NULL UNIQUE,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_teacher_codes_active (teacher_id, active),
  CONSTRAINT fk_teacher_codes_user FOREIGN KEY (teacher_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE classes (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  teacher_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  description TEXT NULL,
  color VARCHAR(9) NOT NULL DEFAULT '#6366F1',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_classes_teacher (teacher_id, created_at),
  CONSTRAINT fk_classes_teacher FOREIGN KEY (teacher_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE join_grants (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  token_hash CHAR(64) NOT NULL UNIQUE,
  student_id BIGINT UNSIGNED NOT NULL,
  teacher_id BIGINT UNSIGNED NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_join_grant_expiry (expires_at),
  CONSTRAINT fk_join_grant_student FOREIGN KEY (student_id)
    REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_join_grant_teacher FOREIGN KEY (teacher_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE enrollments (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  class_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_enrollment (class_id, student_id),
  INDEX idx_enrollments_student (student_id, joined_at),
  CONSTRAINT fk_enrollment_class FOREIGN KEY (class_id)
    REFERENCES classes(id) ON DELETE CASCADE,
  CONSTRAINT fk_enrollment_student FOREIGN KEY (student_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lessons (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  class_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  position INT UNSIGNED NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_lesson_position (class_id, position),
  INDEX idx_lessons_class (class_id, position),
  CONSTRAINT fk_lessons_class FOREIGN KEY (class_id)
    REFERENCES classes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE stored_files (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  owner_user_id BIGINT UNSIGNED NOT NULL,
  storage_name VARCHAR(80) NOT NULL UNIQUE,
  original_name VARCHAR(255) NOT NULL,
  mime_type VARCHAR(120) NOT NULL,
  byte_size BIGINT UNSIGNED NOT NULL,
  sha256 CHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_stored_files_owner (owner_user_id),
  CONSTRAINT fk_stored_files_owner FOREIGN KEY (owner_user_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE users
  ADD CONSTRAINT fk_users_avatar FOREIGN KEY (avatar_file_id)
  REFERENCES stored_files(id) ON DELETE SET NULL;

CREATE TABLE contents (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  lesson_id BIGINT UNSIGNED NOT NULL,
  type ENUM('video','note','booklet') NOT NULL,
  title VARCHAR(160) NOT NULL,
  body MEDIUMTEXT NULL,
  url VARCHAR(500) NULL,
  file_id BIGINT UNSIGNED NULL,
  legacy_file_path VARCHAR(300) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_contents_lesson (lesson_id, created_at),
  CONSTRAINT fk_contents_lesson FOREIGN KEY (lesson_id)
    REFERENCES lessons(id) ON DELETE CASCADE,
  CONSTRAINT fk_contents_file FOREIGN KEY (file_id)
    REFERENCES stored_files(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE assessments (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  class_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  description TEXT NULL,
  kind ENUM('quiz','test','exam') NOT NULL DEFAULT 'quiz',
  status ENUM('draft','published','closed') NOT NULL DEFAULT 'draft',
  duration_min INT UNSIGNED NOT NULL DEFAULT 0,
  max_attempts INT UNSIGNED NOT NULL DEFAULT 1,
  opens_at DATETIME NULL,
  closes_at DATETIME NULL,
  answer_release_policy ENUM('immediately','after_close','teacher_release','never')
    NOT NULL DEFAULT 'teacher_release',
  answers_released_at DATETIME NULL,
  current_version_no INT UNSIGNED NOT NULL DEFAULT 1,
  published_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_assessments_class (class_id, status, created_at),
  CONSTRAINT fk_assessments_class FOREIGN KEY (class_id)
    REFERENCES classes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE assessment_versions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  assessment_id BIGINT UNSIGNED NOT NULL,
  version_no INT UNSIGNED NOT NULL,
  is_published TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  published_at DATETIME NULL,
  UNIQUE KEY uq_assessment_version (assessment_id, version_no),
  CONSTRAINT fk_assessment_versions_assessment FOREIGN KEY (assessment_id)
    REFERENCES assessments(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE questions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  assessment_version_id BIGINT UNSIGNED NOT NULL,
  text TEXT NOT NULL,
  type ENUM('single_choice','multiple_select','true_false','yes_no','fill_blank','essay') NOT NULL,
  points DECIMAL(7,2) UNSIGNED NOT NULL DEFAULT 1,
  position INT UNSIGNED NOT NULL DEFAULT 0,
  UNIQUE KEY uq_question_position (assessment_version_id, position),
  INDEX idx_questions_version (assessment_version_id, position),
  CONSTRAINT fk_questions_version FOREIGN KEY (assessment_version_id)
    REFERENCES assessment_versions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE options (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  question_id BIGINT UNSIGNED NOT NULL,
  text TEXT NOT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  position INT UNSIGNED NOT NULL DEFAULT 0,
  UNIQUE KEY uq_option_position (question_id, position),
  UNIQUE KEY uq_option_question_id (question_id, id),
  CONSTRAINT fk_options_question FOREIGN KEY (question_id)
    REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE attempts (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  assessment_id BIGINT UNSIGNED NOT NULL,
  assessment_version_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  attempt_no INT UNSIGNED NOT NULL,
  started_at DATETIME NOT NULL,
  deadline_at DATETIME NULL,
  submitted_at DATETIME NULL,
  score DECIMAL(5,2) NULL,
  status ENUM('in_progress','submitted','pending_grading','graded','expired')
    NOT NULL DEFAULT 'in_progress',
  idempotency_key VARCHAR(80) NULL,
  UNIQUE KEY uq_attempt_number (assessment_id, student_id, attempt_no),
  UNIQUE KEY uq_attempt_idempotency (student_id, idempotency_key),
  INDEX idx_attempts_assessment (assessment_id, status),
  INDEX idx_attempts_student (student_id, started_at),
  CONSTRAINT fk_attempts_assessment FOREIGN KEY (assessment_id)
    REFERENCES assessments(id) ON DELETE CASCADE,
  CONSTRAINT fk_attempts_version FOREIGN KEY (assessment_version_id)
    REFERENCES assessment_versions(id) ON DELETE RESTRICT,
  CONSTRAINT fk_attempts_student FOREIGN KEY (student_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE answers (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  attempt_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  answer_text TEXT NULL,
  points_earned DECIMAL(7,2) NULL,
  grading_status ENUM('auto_graded','pending','graded') NOT NULL,
  is_correct TINYINT(1) NULL,
  graded_at DATETIME NULL,
  UNIQUE KEY uq_answer_attempt_question (attempt_id, question_id),
  UNIQUE KEY uq_answer_question_id (question_id, id),
  CONSTRAINT fk_answers_attempt FOREIGN KEY (attempt_id)
    REFERENCES attempts(id) ON DELETE CASCADE,
  CONSTRAINT fk_answers_question FOREIGN KEY (question_id)
    REFERENCES questions(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE answer_options (
  answer_id BIGINT UNSIGNED NOT NULL,
  question_id BIGINT UNSIGNED NOT NULL,
  option_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (answer_id, option_id),
  CONSTRAINT fk_answer_options_answer_question FOREIGN KEY (question_id, answer_id)
    REFERENCES answers(question_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_answer_options_option_question FOREIGN KEY (question_id, option_id)
    REFERENCES options(question_id, id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE homework (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  class_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(160) NOT NULL,
  description TEXT NULL,
  due_at DATETIME NULL,
  allow_late_submission TINYINT(1) NOT NULL DEFAULT 0,
  allow_resubmit TINYINT(1) NOT NULL DEFAULT 1,
  resubmit_until DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_homework_class_due (class_id, due_at),
  CONSTRAINT fk_homework_class FOREIGN KEY (class_id)
    REFERENCES classes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE submissions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  homework_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  latest_version_no INT UNSIGNED NOT NULL DEFAULT 1,
  status ENUM('submitted','late','pending_grading','graded') NOT NULL DEFAULT 'pending_grading',
  grade VARCHAR(40) NULL,
  feedback TEXT NULL,
  graded_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_submission (homework_id, student_id),
  INDEX idx_submissions_homework_status (homework_id, status),
  CONSTRAINT fk_submissions_homework FOREIGN KEY (homework_id)
    REFERENCES homework(id) ON DELETE CASCADE,
  CONSTRAINT fk_submissions_student FOREIGN KEY (student_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE submission_versions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  submission_id BIGINT UNSIGNED NOT NULL,
  version_no INT UNSIGNED NOT NULL,
  text TEXT NULL,
  file_id BIGINT UNSIGNED NULL,
  legacy_file_path VARCHAR(300) NULL,
  submitted_at DATETIME NOT NULL,
  is_late TINYINT(1) NOT NULL DEFAULT 0,
  UNIQUE KEY uq_submission_version (submission_id, version_no),
  CONSTRAINT fk_submission_versions_submission FOREIGN KEY (submission_id)
    REFERENCES submissions(id) ON DELETE CASCADE,
  CONSTRAINT fk_submission_versions_file FOREIGN KEY (file_id)
    REFERENCES stored_files(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE qa_threads (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  class_id BIGINT UNSIGNED NOT NULL,
  student_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(200) NOT NULL,
  body TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_qa_threads_class (class_id, created_at),
  CONSTRAINT fk_qa_threads_class FOREIGN KEY (class_id)
    REFERENCES classes(id) ON DELETE CASCADE,
  CONSTRAINT fk_qa_threads_student FOREIGN KEY (student_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE qa_replies (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  thread_id BIGINT UNSIGNED NOT NULL,
  author_id BIGINT UNSIGNED NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_qa_replies_thread (thread_id, created_at),
  CONSTRAINT fk_qa_replies_thread FOREIGN KEY (thread_id)
    REFERENCES qa_threads(id) ON DELETE CASCADE,
  CONSTRAINT fk_qa_replies_author FOREIGN KEY (author_id)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE live_sessions (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  class_id BIGINT UNSIGNED NOT NULL,
  created_by BIGINT UNSIGNED NOT NULL,
  provider ENUM('jitsi','jaas','external') NOT NULL DEFAULT 'jitsi',
  provider_room_id VARCHAR(180) NOT NULL UNIQUE,
  join_url VARCHAR(500) NOT NULL,
  status ENUM('scheduled','live','ended','cancelled') NOT NULL DEFAULT 'live',
  starts_at DATETIME NOT NULL,
  ended_at DATETIME NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_live_class_status (class_id, status, starts_at),
  CONSTRAINT fk_live_sessions_class FOREIGN KEY (class_id)
    REFERENCES classes(id) ON DELETE CASCADE,
  CONSTRAINT fk_live_sessions_creator FOREIGN KEY (created_by)
    REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE audit_events (
  id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  actor_user_id BIGINT UNSIGNED NULL,
  event_type VARCHAR(80) NOT NULL,
  entity_type VARCHAR(60) NULL,
  entity_id BIGINT UNSIGNED NULL,
  metadata_json LONGTEXT NULL,
  ip_hash CHAR(64) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_actor_time (actor_user_id, created_at),
  INDEX idx_audit_entity (entity_type, entity_id),
  CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id)
    REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
