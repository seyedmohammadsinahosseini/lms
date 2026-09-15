-- OTMS demo data -------------------------------------------------------------
-- Optional companion to schema.sql: a populated teacher account, so every
-- screen has something real to show instead of an empty state. Run it AFTER
-- the schema, and only when you want sample content:
--
--   mysql -u root otms < backend/schema.sql
--   mysql -u root otms < tools/demo_seed.sql
--
-- Every demo student signs in with the password `password`. Run the schema and
-- this file together to reset the sample content; the inserts that overlap the
-- schema seed are written so they can be replayed without failing.

-- Force utf8mb4 for this session. The mysql client defaults to latin1 on many
-- systems, which silently double-encodes accented text and em dashes. On
-- Windows you can also pass --default-character-set=utf8mb4 explicitly.
SET NAMES utf8mb4;

USE otms;

-- Demo students reuse the seeded account's password hash.
SET @pwd = (SELECT password_hash FROM users WHERE id = 2);

-- Students
INSERT INTO users (id, full_name, email, password_hash, role) VALUES
  (3, 'Sara Ahmadi', 'student2@otms.test', @pwd, 'student'),
  (4, 'Reza Karimi', 'student3@otms.test', @pwd, 'student'),
  (5, 'Mina Hosseini', 'student4@otms.test', @pwd, 'student'),
  (6, 'Ali Rahimi', 'student5@otms.test', @pwd, 'student'),
  (7, 'Neda Sadeghi', 'student6@otms.test', @pwd, 'student'),
  (8, 'Omid Tabrizi', 'student7@otms.test', @pwd, 'student');

-- Classes (1 Mathematics and 2 Physics come from schema.sql)
INSERT INTO classes (id, teacher_id, name, description, color) VALUES
  (3, 1, 'Chemistry Essentials', 'Periodic table, bonding and simple reactions.', '#F59E0B'),
  (4, 1, 'English Literature', 'Poetry and short fiction, with weekly writing tasks.', '#EC4899'),
  (5, 1, 'Computer Science Basics', 'Algorithms, data structures and problem solving.', '#8B5CF6');
UPDATE classes SET description = 'Fractions, decimals and early algebra.' WHERE id = 1;
UPDATE classes SET description = 'Motion, forces and energy for grade 10.', color = '#14B8A6' WHERE id = 2;

-- Enrollments
INSERT IGNORE INTO enrollments (class_id, student_id) VALUES
  (1, 2),
  (1, 3),
  (1, 4),
  (1, 5),
  (2, 3),
  (2, 4),
  (2, 5),
  (2, 6),
  (2, 7),
  (3, 4),
  (3, 6),
  (3, 8),
  (4, 5),
  (4, 8),
  (5, 2),
  (5, 3),
  (5, 6),
  (5, 7),
  (5, 8);

-- Lessons
INSERT INTO lessons (id, class_id, title, position) VALUES
  (3, 2, 'Chapter 1 — Motion in a Straight Line', 0),
  (4, 2, 'Chapter 2 — Newton''s Laws', 1),
  (5, 2, 'Chapter 3 — Energy and Work', 2),
  (6, 3, 'Week 1 — The Periodic Table', 0),
  (7, 3, 'Week 2 — Chemical Bonds', 1),
  (8, 3, 'Week 3 — Reactions and Equations', 2),
  (9, 4, 'Unit 1 — Reading Poetry', 0),
  (10, 4, 'Unit 2 — Short Fiction', 1),
  (11, 4, 'Unit 3 — Writing Arguments', 2),
  (12, 5, 'Lesson 1 — What Is an Algorithm?', 0),
  (13, 5, 'Lesson 2 — Lists and Searching', 1),
  (14, 5, 'Lesson 3 — Sorting and Complexity', 2);

-- Lesson materials
INSERT INTO contents (id, lesson_id, type, title, body, url) VALUES
  (4, 3, 'video', 'Introduction to Motion', NULL, 'https://www.youtube.com/watch?v=ZM8ECpBuQYE'),
  (5, 3, 'note', 'Key formulas', '**Speed** = distance / time\n\n**Velocity** adds direction.\n\n**Acceleration** = change in velocity / time.', NULL),
  (6, 4, 'video', 'Newton''s Three Laws', NULL, 'https://www.youtube.com/watch?v=kKKM8Y-u7ds'),
  (7, 4, 'note', 'Worked examples', 'A 2 kg ball is pushed with 10 N.\n\n`a = F / m = 5 m/s^2`', NULL),
  (8, 4, 'booklet', 'Newton''s Laws Booklet', 'Printable booklet with 12 practice problems.', NULL),
  (9, 5, 'note', 'Energy cheat sheet', 'Kinetic energy: `KE = 1/2 mv^2`\n\nPotential energy: `PE = mgh`', NULL),
  (10, 6, 'note', 'Groups and periods', 'Columns are groups, rows are periods.\n\nGroup 1 = alkali metals, group 18 = noble gases.', NULL),
  (11, 6, 'video', 'Reading the periodic table', NULL, 'https://www.youtube.com/watch?v=0RRVV4Diomg'),
  (12, 7, 'note', 'Ionic vs covalent', 'Ionic: metal + non-metal, electrons are transferred.\n\nCovalent: non-metals sharing electrons.', NULL),
  (13, 8, 'booklet', 'Balancing equations workbook', 'Twenty unbalanced equations to complete.', NULL),
  (14, 9, 'note', 'Poetic devices', 'Metaphor, simile, alliteration, enjambment.\n\nLook for them in this week''s reading.', NULL),
  (15, 9, 'video', 'How to read a poem aloud', NULL, 'https://www.youtube.com/watch?v=JwhouCNqTjE'),
  (16, 10, 'note', 'Story structure', 'Exposition → rising action → climax → resolution.', NULL),
  (17, 12, 'note', 'What is an algorithm?', 'A finite sequence of unambiguous steps.\n\nCounter-example: ''add some numbers'' is not an algorithm.', NULL),
  (18, 13, 'note', 'Linear vs binary search', 'Linear: check each item, O(n).\n\nBinary: halve the range, O(log n) — it needs sorted input.', NULL),
  (19, 14, 'booklet', 'Sorting worksheet', 'Trace bubble sort and merge sort on the given lists.', NULL);

-- Assessments
INSERT INTO assessments (id, class_id, title, description, kind, duration_min) VALUES
  (2, 2, 'Motion & Forces Quiz', 'Speed, velocity and acceleration.', 'quiz', 15),
  (3, 2, 'Mechanics Test', 'Covers chapters 1 and 2.', 'test', 45),
  (4, 3, 'Periodic Table Quiz', 'Groups, periods and trends.', 'quiz', 10),
  (5, 4, 'Poetry Essay', 'Write a short analysis of the assigned poem.', 'exam', 60),
  (6, 5, 'Algorithms Quiz', 'Complexity and searching.', 'quiz', 20);

-- Questions
INSERT INTO questions (id, assessment_id, text, type, points, position) VALUES
  (6, 2, 'What is the SI unit of acceleration?', 'multiple_choice', 2, 0),
  (7, 2, 'Velocity is speed with a direction.', 'true_false', 1, 1),
  (8, 2, 'Can an object have zero velocity and non-zero acceleration?', 'yes_no', 2, 2),
  (9, 2, 'The rate of change of velocity is called _____.', 'fill_blank', 2, 3),
  (10, 3, 'State Newton''s second law.', 'essay', 5, 0),
  (11, 3, 'A 5 kg mass accelerates at 2 m/s². What force acts on it?', 'multiple_choice', 3, 1),
  (12, 4, 'Which group contains the noble gases?', 'multiple_choice', 2, 0),
  (13, 4, 'Sodium and chlorine bond ionically.', 'true_false', 1, 1),
  (14, 5, 'Analyse how the poet uses imagery to build a sense of place.', 'essay', 10, 0),
  (15, 6, 'What is the worst-case time complexity of binary search?', 'multiple_choice', 2, 0),
  (16, 6, 'Binary search works on an unsorted list.', 'true_false', 1, 1),
  (17, 6, 'Explain why merge sort is preferred for large datasets.', 'essay', 5, 2);

-- Answer options (is_correct is only ever sent to teachers)
INSERT INTO options (id, question_id, text, is_correct) VALUES
  (101, 6, 'm/s', 0),
  (102, 6, 'm/s²', 1),
  (103, 6, 'm·s', 0),
  (104, 6, 's/m', 0),
  (105, 7, 'True', 1),
  (106, 7, 'False', 0),
  (107, 8, 'Yes', 1),
  (108, 8, 'No', 0),
  (109, 9, 'acceleration', 1),
  (110, 11, '2.5 N', 0),
  (111, 11, '7 N', 0),
  (112, 11, '10 N', 1),
  (113, 11, '20 N', 0),
  (114, 12, 'Group 1', 0),
  (115, 12, 'Group 2', 0),
  (116, 12, 'Group 17', 0),
  (117, 12, 'Group 18', 1),
  (118, 13, 'True', 1),
  (119, 13, 'False', 0),
  (120, 15, 'O(1)', 0),
  (121, 15, 'O(log n)', 1),
  (122, 15, 'O(n)', 0),
  (123, 15, 'O(n²)', 0),
  (124, 16, 'True', 0),
  (125, 16, 'False', 1);

-- Attempts. Essay points below are the teacher's marks where the work has
-- already been graded; the ones left out are still waiting, which is what
-- fills the essay-grading screen.
INSERT INTO attempts (id, assessment_id, student_id, started_at, submitted_at, score, status) VALUES
  (1, 1, 2, DATE_SUB(NOW(), INTERVAL 6 DAY), DATE_SUB(NOW(), INTERVAL 6 DAY), NULL, 'completed'),
  (2, 1, 3, DATE_SUB(NOW(), INTERVAL 6 DAY), DATE_SUB(NOW(), INTERVAL 6 DAY), NULL, 'completed'),
  (3, 1, 4, DATE_SUB(NOW(), INTERVAL 5 DAY), DATE_SUB(NOW(), INTERVAL 5 DAY), NULL, 'completed'),
  (4, 1, 5, DATE_SUB(NOW(), INTERVAL 4 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY), NULL, 'completed'),
  (5, 2, 3, DATE_SUB(NOW(), INTERVAL 3 DAY), DATE_SUB(NOW(), INTERVAL 3 DAY), NULL, 'completed'),
  (6, 2, 4, DATE_SUB(NOW(), INTERVAL 3 DAY), DATE_SUB(NOW(), INTERVAL 3 DAY), NULL, 'completed'),
  (7, 2, 5, DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), NULL, 'completed'),
  (8, 2, 6, DATE_SUB(NOW(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY), NULL, 'completed'),
  (9, 3, 5, DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), NULL, 'completed'),
  (10, 3, 6, DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), NULL, 'completed'),
  (11, 4, 4, DATE_SUB(NOW(), INTERVAL 4 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY), NULL, 'completed'),
  (12, 4, 6, DATE_SUB(NOW(), INTERVAL 4 DAY), DATE_SUB(NOW(), INTERVAL 4 DAY), NULL, 'completed'),
  (13, 5, 5, DATE_SUB(NOW(), INTERVAL 1 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY), NULL, 'completed'),
  (14, 5, 8, DATE_SUB(NOW(), INTERVAL 0 DAY), DATE_SUB(NOW(), INTERVAL 0 DAY), NULL, 'completed'),
  (15, 6, 3, DATE_SUB(NOW(), INTERVAL 2 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY), NULL, 'completed');

-- Answers recorded for those attempts
INSERT INTO answers (attempt_id, question_id, option_id, answer_text, points_earned, is_correct) VALUES
  (1, 1, 1, NULL, 2, 1),
  (1, 2, 5, NULL, 1, 1),
  (1, 3, 7, NULL, 1, 1),
  (1, 4, NULL, 'numerator', 1, 1),
  (1, 5, NULL, 'A fraction is a way of writing part of a whole, for example half a pizza.', 2, NULL),
  (2, 1, 1, NULL, 2, 1),
  (2, 2, 5, NULL, 1, 1),
  (2, 3, 7, NULL, 1, 1),
  (2, 4, NULL, 'numerator', 1, 1),
  (2, 5, NULL, 'A fraction is a way of writing part of a whole, for example half a pizza.', 3, NULL),
  (3, 1, 1, NULL, 2, 1),
  (3, 2, 5, NULL, 1, 1),
  (3, 3, 8, NULL, 0, 0),
  (3, 4, NULL, 'denominator', 0, 0),
  (3, 5, NULL, 'A fraction is a way of writing part of a whole, for example half a pizza.', NULL, NULL),
  (4, 1, 1, NULL, 2, 1),
  (4, 2, 5, NULL, 1, 1),
  (4, 3, 8, NULL, 0, 0),
  (4, 4, NULL, 'denominator', 0, 0),
  (4, 5, NULL, 'A fraction is a way of writing part of a whole, for example half a pizza.', NULL, NULL),
  (5, 6, 102, NULL, 2, 1),
  (5, 7, 105, NULL, 1, 1),
  (5, 8, 107, NULL, 2, 1),
  (5, 9, NULL, 'acceleration', 2, 1),
  (6, 6, 102, NULL, 2, 1),
  (6, 7, 105, NULL, 1, 1),
  (6, 8, 107, NULL, 2, 1),
  (6, 9, NULL, 'acceleration', 2, 1),
  (7, 6, 102, NULL, 2, 1),
  (7, 7, 105, NULL, 1, 1),
  (7, 8, 107, NULL, 2, 1),
  (7, 9, NULL, 'denominator', 0, 0),
  (8, 6, 102, NULL, 2, 1),
  (8, 7, 106, NULL, 0, 0),
  (8, 8, 108, NULL, 0, 0),
  (8, 9, NULL, 'denominator', 0, 0),
  (9, 10, NULL, 'Force equals mass times acceleration, so a heavier object needs more force.', 4, NULL),
  (9, 11, 112, NULL, 3, 1),
  (10, 10, NULL, 'Force equals mass times acceleration, so a heavier object needs more force.', NULL, NULL),
  (10, 11, 112, NULL, 3, 1),
  (11, 12, 117, NULL, 2, 1),
  (11, 13, 118, NULL, 1, 1),
  (12, 12, 117, NULL, 2, 1),
  (12, 13, 119, NULL, 0, 0),
  (13, 14, NULL, 'The poet uses sea imagery to make the town feel both familiar and far away.', 8, NULL),
  (14, 14, NULL, 'The poet uses sea imagery to make the town feel both familiar and far away.', 6, NULL),
  (15, 15, 121, NULL, 2, 1),
  (15, 16, 125, NULL, 1, 1),
  (15, 17, NULL, 'Merge sort stays O(n log n) in the worst case, so it copes with large inputs.', NULL, NULL);

-- Derive each score from the answers, so the percentages agree with what the
-- detail view shows instead of being typed in by hand. An attempt with an
-- ungraded essay stays 'completed' (awaiting grading) rather than 'graded'.
UPDATE attempts a SET
  a.score = (
    SELECT ROUND(COALESCE(SUM(ans.points_earned), 0)
                 / NULLIF((SELECT SUM(q.points) FROM questions q
                           WHERE q.assessment_id = a.assessment_id), 0) * 100, 2)
    FROM answers ans WHERE ans.attempt_id = a.id
  ),
  a.status = CASE
    WHEN EXISTS (
      SELECT 1 FROM answers ans JOIN questions q ON q.id = ans.question_id
      WHERE ans.attempt_id = a.id AND q.type = 'essay' AND ans.points_earned IS NULL
    ) THEN 'completed'
    ELSE 'graded'
  END;

-- Homework (due dates are relative to today, so the list always looks current)
INSERT INTO homework (id, class_id, title, description, due_date) VALUES
  (2, 2, 'Motion problem set', 'Complete problems 1-10 from the worksheet.', DATE_ADD(CURDATE(), INTERVAL 3 DAY)),
  (3, 2, 'Mechanics lab report', 'Write up the trolley experiment, one page.', DATE_ADD(CURDATE(), INTERVAL 7 DAY)),
  (4, 3, 'Periodic table worksheet', 'Label the groups and periods on the blank table.', DATE_SUB(CURDATE(), INTERVAL 2 DAY)),
  (5, 3, 'Balancing equations', 'Balance the twenty equations in the workbook.', DATE_ADD(CURDATE(), INTERVAL 5 DAY)),
  (6, 4, 'Poem analysis draft', '300 words on imagery in the assigned poem.', DATE_ADD(CURDATE(), INTERVAL 2 DAY)),
  (7, 5, 'Trace binary search', 'Trace the algorithm on the given list, showing every step.', DATE_ADD(CURDATE(), INTERVAL 4 DAY)),
  (8, 5, 'Complexity table', 'Fill in best and worst case for the five algorithms we covered.', DATE_SUB(CURDATE(), INTERVAL 1 DAY));

-- Submissions: a mix of graded and still waiting, so the grading screens
-- have real work in them
INSERT IGNORE INTO submissions (homework_id, student_id, text, grade, feedback) VALUES
  (1, 3, 'Uploaded my working as a photo.', 'A', 'Tidy work, all correct.'),
  (1, 4, 'Answers attached; question 7 was tricky.', 'B+', 'Good, revisit question 7.'),
  (1, 6, 'Finished all ten problems.', NULL, NULL),
  (2, 5, 'Lab report attached.', 'A-', 'Clear method, add the uncertainty.'),
  (2, 7, 'My report is in the file.', NULL, NULL),
  (3, 8, 'Worksheet completed.', 'B', 'Two groups mislabelled.'),
  (4, 4, 'Balanced all but the last three.', NULL, NULL),
  (6, 5, 'Draft attached for feedback.', 'A', 'Strong imagery analysis.'),
  (7, 2, 'Steps 1-8 are shown in the document.', NULL, NULL),
  (8, 6, 'Filled in every column.', 'A', 'All correct.');

-- Q&A threads
INSERT INTO qa_threads (id, class_id, student_id, title, body) VALUES
  (1, 1, 2, 'Why is 3/3 equal to 1?', 'I understand 1/2 but not why three thirds is a whole.'),
  (2, 2, 3, 'Do we need to memorise the formulas?', 'Will the formula sheet be given in the test?'),
  (3, 3, 6, 'Noble gases and reactivity', 'Why do group 18 elements barely react?'),
  (4, 4, 5, 'Choosing a poem for the essay', 'Can we pick our own poem, or is one assigned?'),
  (5, 5, 8, 'Is binary search always faster?', 'It seems slower than looping for short lists.');

-- Replies (author_id 1 is the teacher)
INSERT INTO qa_replies (thread_id, author_id, body) VALUES
  (1, 1, 'Because three equal parts make the whole: 3/3 = 1. Try it with a pizza cut into three.'),
  (1, 2, 'Think of it as 3 divided by 3, which is 1.'),
  (2, 1, 'The sheet is provided, but you should know what each formula means.'),
  (3, 1, 'Their outer shell is already full, so they have no reason to gain or lose electrons.'),
  (3, 4, 'That full shell is also why they have such low boiling points.'),
  (4, 1, 'Pick your own, as long as it comes from the reading list.'),
  (5, 1, 'For tiny lists a loop wins. Binary search pays off as the list grows: try 10,000 items.'),
  (5, 2, 'O(log n) is why real databases rely on it.');

-- Done. Sign in as teacher@otms.test or student@otms.test (password: password)
