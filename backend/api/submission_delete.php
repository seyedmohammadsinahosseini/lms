<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_method('POST');

$b = body();
$submissionId = (int)($b['submission_id'] ?? 0);

$stmt = db()->prepare('SELECT s.*, h.class_id FROM submissions s JOIN homework h ON h.id = s.homework_id WHERE s.id = ?');
$stmt->execute([$submissionId]);
$sub = $stmt->fetch();
if (!$sub) fail('Submission not found', 404);

// Students can only delete their own submissions
if ($user['role'] === 'student') {
    if ((int)$sub['student_id'] !== (int)$user['id']) fail('Forbidden', 403);
} else {
    // Teacher can delete any submission in their class
    owned_class_or_fail((int)$sub['class_id'], (int)$user['id']);
}

db()->prepare('DELETE FROM submissions WHERE id = ?')->execute([$submissionId]);
send(['success' => true]);