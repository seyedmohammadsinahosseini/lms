-- LMS 2.0 local-development seed.
-- Import ONLY into a fresh non-production database after backend/schema.sql.
-- Both accounts use password: password
SET NAMES utf8mb4;
SET time_zone = '+00:00';
START TRANSACTION;

INSERT INTO users (full_name, email, password_hash, role) VALUES
  ('Portfolio Teacher', 'teacher@lms.test', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'teacher');
SET @teacher_id = LAST_INSERT_ID();
INSERT INTO users (full_name, email, password_hash, role) VALUES
  ('Portfolio Student', 'student@lms.test', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'student');
SET @student_id = LAST_INSERT_ID();
INSERT INTO teacher_codes (teacher_id, code, active) VALUES (@teacher_id, 'DEMO24', 1);

INSERT INTO classes (teacher_id, name, description, color)
VALUES (@teacher_id, 'Mathematics Demo', 'Synthetic data for local development only.', '#6366F1');
SET @class_id = LAST_INSERT_ID();
INSERT INTO enrollments (class_id, student_id) VALUES (@class_id, @student_id);

INSERT INTO lessons (class_id, title, position)
VALUES (@class_id, 'Fractions and equations', 0);
SET @lesson_id = LAST_INSERT_ID();
INSERT INTO contents (lesson_id, type, title, body, url) VALUES
  (@lesson_id, 'note', 'Key definitions', 'A numerator is above the denominator.', NULL),
  (@lesson_id, 'video', 'Practice video', NULL, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');

INSERT INTO assessments
  (class_id, title, description, kind, status, duration_min, max_attempts,
   answer_release_policy, current_version_no, published_at)
VALUES
  (@class_id, 'Fractions quiz', 'A short objective quiz.', 'quiz', 'published',
   10, 2, 'immediately', 1, UTC_TIMESTAMP());
SET @assessment_id = LAST_INSERT_ID();
INSERT INTO assessment_versions (assessment_id, version_no, is_published, published_at)
VALUES (@assessment_id, 1, 1, UTC_TIMESTAMP());
SET @assessment_version_id = LAST_INSERT_ID();
INSERT INTO questions (assessment_version_id, text, type, points, position)
VALUES (@assessment_version_id, 'What is 1/2 + 1/2?', 'single_choice', 2, 0);
SET @question_1 = LAST_INSERT_ID();
INSERT INTO options (question_id, text, is_correct, position) VALUES
  (@question_1, '1', 1, 0), (@question_1, '2', 0, 1), (@question_1, '1/4', 0, 2);
SET @correct_option = (SELECT id FROM options WHERE question_id = @question_1 AND is_correct = 1 LIMIT 1);
INSERT INTO questions (assessment_version_id, text, type, points, position)
VALUES (@assessment_version_id, 'Explain a fraction in your own words.', 'essay', 3, 1);
SET @question_2 = LAST_INSERT_ID();

INSERT INTO attempts
  (assessment_id, assessment_version_id, student_id, attempt_no, started_at,
   submitted_at, score, status)
VALUES
  (@assessment_id, @assessment_version_id, @student_id, 1,
   DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY),
   DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY), 100, 'graded');
SET @attempt_id = LAST_INSERT_ID();
INSERT INTO answers
  (attempt_id, question_id, answer_text, points_earned, grading_status,
   is_correct, graded_at)
VALUES
  (@attempt_id, @question_1, NULL, 2, 'auto_graded', 1, DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY)),
  (@attempt_id, @question_2, 'A fraction describes part of a whole.', 3, 'graded', 1, DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY));
SET @answer_1 = (SELECT id FROM answers WHERE attempt_id = @attempt_id AND question_id = @question_1);
INSERT INTO answer_options (answer_id, question_id, option_id)
VALUES (@answer_1, @question_1, @correct_option);

INSERT INTO homework
  (class_id, title, description, due_at, allow_late_submission,
   allow_resubmit, resubmit_until)
VALUES
  (@class_id, 'Fractions worksheet', 'Submit text or a small attachment.',
   DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 DAY), 1, 1,
   DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 DAY));
SET @homework_id = LAST_INSERT_ID();
INSERT INTO submissions
  (homework_id, student_id, latest_version_no, status, grade, feedback, graded_at)
VALUES
  (@homework_id, @student_id, 1, 'graded', 'A', 'Clear work.', UTC_TIMESTAMP());
SET @submission_id = LAST_INSERT_ID();
INSERT INTO submission_versions
  (submission_id, version_no, text, submitted_at, is_late)
VALUES (@submission_id, 1, 'Completed all worksheet questions.', UTC_TIMESTAMP(), 0);

INSERT INTO qa_threads (class_id, student_id, title, body)
VALUES (@class_id, @student_id, 'Can I resubmit?', 'I want to improve my work.');
SET @thread_id = LAST_INSERT_ID();
INSERT INTO qa_replies (thread_id, author_id, body)
VALUES (@thread_id, @teacher_id, 'Yes, this assignment allows versioned resubmissions.');

COMMIT;
