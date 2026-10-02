<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$submissionId = (int)input_int($b, 'submission_id', 1);
$grade = input_string($b, 'grade', 40, false);
$feedback = input_string($b, 'feedback', 10000, false);
if ($grade === null && $feedback === null) fail('Provide a grade or feedback.', 422, 'VALIDATION_ERROR');
$stmt = db()->prepare(
    'SELECT s.id, h.class_id FROM submissions s JOIN homework h ON h.id = s.homework_id WHERE s.id = ?'
);
$stmt->execute([$submissionId]);
$row = $stmt->fetch();
if (!$row) fail('Submission not found.', 404, 'NOT_FOUND');
owned_class_or_fail((int)$row['class_id'], (int)$user['id']);
db()->prepare(
    "UPDATE submissions SET grade = ?, feedback = ?, graded_at = UTC_TIMESTAMP(), status = 'graded' WHERE id = ?"
)->execute([$grade, $feedback, $submissionId]);
audit_event((int)$user['id'], 'submission.graded', 'submission', $submissionId);
send(['success' => true]);
