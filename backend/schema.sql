-- OTMS (Online Teaching & Management System) schema
-- New database, independent of the legacy `training_management` DB.

CREATE DATABASE IF NOT EXISTS otms CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE otms;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS qa_replies, qa_threads, submissions, homework,
  answers, attempts, options, questions, assessments, contents, lessons,
  enrollments, classes, teacher_codes, sessions, login_attempts, users;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE users (
  id INT PRIMARY KEY AUTO_INCREMENT,
  full_name VARCHAR(120) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('teacher','student') NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE sessions (
  token CHAR(64) PRIMARY KEY,
  user_id INT NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Failed sign-in attempts, used to throttle password guessing (see
-- helpers.php: login_attempts_exceeded / record_login_failure).
-- Rows older than a few minutes are pruned opportunistically on failure.
CREATE TABLE login_attempts (
  id INT PRIMARY KEY AUTO_INCREMENT,
  email VARCHAR(160) NOT NULL,
  ip VARCHAR(45) NOT NULL,
  attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email_ip_time (email, ip, attempted_at)
) ENGINE=InnoDB;

CREATE TABLE teacher_codes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  teacher_id INT NOT NULL,
  code VARCHAR(12) NOT NULL UNIQUE,
  active TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE classes (
  id INT PRIMARY KEY AUTO_INCREMENT,
  teacher_id INT NOT NULL,
  name VARCHAR(120) NOT NULL,
  description TEXT,
  color VARCHAR(9) DEFAULT '#6366F1',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (teacher_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE enrollments (
  id INT PRIMARY KEY AUTO_INCREMENT,
  class_id INT NOT NULL,
  student_id INT NOT NULL,
  joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_enroll (class_id, student_id),
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE lessons (
  id INT PRIMARY KEY AUTO_INCREMENT,
  class_id INT NOT NULL,
  title VARCHAR(160) NOT NULL,
  position INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE contents (
  id INT PRIMARY KEY AUTO_INCREMENT,
  lesson_id INT NOT NULL,
  type ENUM('video','note','booklet') NOT NULL,
  title VARCHAR(160) NOT NULL,
  body MEDIUMTEXT,
  url VARCHAR(500),
  file_path VARCHAR(300),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (lesson_id) REFERENCES lessons(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE assessments (
  id INT PRIMARY KEY AUTO_INCREMENT,
  class_id INT NOT NULL,
  title VARCHAR(160) NOT NULL,
  description TEXT,
  kind ENUM('quiz','test','exam') NOT NULL DEFAULT 'quiz',
  duration_min INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE questions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  assessment_id INT NOT NULL,
  text TEXT NOT NULL,
  type ENUM('multiple_choice','true_false','yes_no','fill_blank','essay') NOT NULL,
  points INT NOT NULL DEFAULT 1,
  position INT NOT NULL DEFAULT 0,
  FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE options (
  id INT PRIMARY KEY AUTO_INCREMENT,
  question_id INT NOT NULL,
  text TEXT NOT NULL,
  is_correct TINYINT(1) NOT NULL DEFAULT 0,
  FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE attempts (
  id INT PRIMARY KEY AUTO_INCREMENT,
  assessment_id INT NOT NULL,
  student_id INT NOT NULL,
  started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  submitted_at DATETIME NULL,
  score DECIMAL(5,2) NULL,
  status ENUM('in_progress','completed','graded') NOT NULL DEFAULT 'in_progress',
  FOREIGN KEY (assessment_id) REFERENCES assessments(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE answers (
  id INT PRIMARY KEY AUTO_INCREMENT,
  attempt_id INT NOT NULL,
  question_id INT NOT NULL,
  option_id INT NULL,
  answer_text TEXT NULL,
  points_earned INT NULL,
  is_correct TINYINT(1) NULL,
  FOREIGN KEY (attempt_id) REFERENCES attempts(id) ON DELETE CASCADE,
  FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE,
  FOREIGN KEY (option_id) REFERENCES options(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE homework (
  id INT PRIMARY KEY AUTO_INCREMENT,
  class_id INT NOT NULL,
  title VARCHAR(160) NOT NULL,
  description TEXT,
  due_date DATE NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE submissions (
  id INT PRIMARY KEY AUTO_INCREMENT,
  homework_id INT NOT NULL,
  student_id INT NOT NULL,
  text TEXT NULL,
  file_path VARCHAR(300) NULL,
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  grade VARCHAR(40) NULL,
  feedback TEXT NULL,
  UNIQUE KEY uq_sub (homework_id, student_id),
  FOREIGN KEY (homework_id) REFERENCES homework(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE qa_threads (
  id INT PRIMARY KEY AUTO_INCREMENT,
  class_id INT NOT NULL,
  student_id INT NOT NULL,
  title VARCHAR(200) NOT NULL,
  body TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
  FOREIGN KEY (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE qa_replies (
  id INT PRIMARY KEY AUTO_INCREMENT,
  thread_id INT NOT NULL,
  author_id INT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (thread_id) REFERENCES qa_threads(id) ON DELETE CASCADE,
  FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------------
-- Seed data. Password hash below is for the plain password: password
-- (bcrypt, generated with PHP password_hash).
-- ---------------------------------------------------------------------------
INSERT INTO users (id, full_name, email, password_hash, role) VALUES
  (1, 'Demo Teacher', 'teacher@otms.test', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'teacher'),
  (2, 'Demo Student', 'student@otms.test', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student');

INSERT INTO teacher_codes (teacher_id, code, active) VALUES (1, 'ABC123', 1);

INSERT INTO classes (id, teacher_id, name, description, color) VALUES
  (1, 1, 'Mathematics', 'Algebra, geometry and beyond.', '#6366F1'),
  (2, 1, 'Physics', 'Mechanics, waves and energy.', '#14B8A6');

INSERT INTO enrollments (class_id, student_id) VALUES (1, 2);

INSERT INTO lessons (id, class_id, title, position) VALUES
  (1, 1, 'Chapter 1 — Fractions', 0),
  (2, 1, 'Chapter 2 — Equations', 1);

INSERT INTO contents (lesson_id, type, title, body, url) VALUES
  (1, 'video', 'Intro to Fractions', NULL, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
  (1, 'note',  'Key definitions', 'A fraction represents a part of a whole.\n\nNumerator over denominator.', NULL),
  (1, 'booklet', 'Fractions Booklet', '# Fractions\n\n## What is a fraction?\n\nA **fraction** is written as `a/b`.\n\n- The top is the *numerator*\n- The bottom is the *denominator*\n\n> Practice makes perfect.', NULL);

INSERT INTO assessments (id, class_id, title, description, kind, duration_min) VALUES
  (1, 1, 'Fractions Quiz', 'A short quiz on chapter 1.', 'quiz', 10);

INSERT INTO questions (id, assessment_id, text, type, points, position) VALUES
  (1, 1, 'What is 1/2 + 1/2?', 'multiple_choice', 2, 0),
  (2, 1, 'A fraction has a numerator and a denominator.', 'true_false', 1, 1),
  (3, 1, 'Is 3/3 equal to 1?', 'yes_no', 1, 2),
  (4, 1, 'The top number of a fraction is called the _____.', 'fill_blank', 1, 3),
  (5, 1, 'Explain in your own words what a fraction is.', 'essay', 3, 4);

INSERT INTO options (question_id, text, is_correct) VALUES
  (1, '1', 1), (1, '2', 0), (1, '1/4', 0), (1, '0', 0),
  (2, 'True', 1), (2, 'False', 0),
  (3, 'Yes', 1), (3, 'No', 0),
  (4, 'numerator', 1);

INSERT INTO homework (id, class_id, title, description, due_date) VALUES
  (1, 1, 'Fractions worksheet', 'Complete problems 1-10 and upload a photo of your work.', '2026-09-01');

