<?php
// Teacher grades a homework submission. Body: submission_id, grade, feedback.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$subId = (int)($b['submission_id'] ?? 0);
$grade = trim($b['grade'] ?? '');
$feedback = trim($b['feedback'] ?? '');

$stmt = db()->prepare(
    'SELECT s.id, h.class_id FROM submissions s
     JOIN homework h ON h.id = s.homework_id WHERE s.id = ?'
);
$stmt->execute([$subId]);
$row = $stmt->fetch();
if (!$row) fail('Submission not found', 404);
owned_class_or_fail((int)$row['class_id'], (int)$user['id']);

db()->prepare('UPDATE submissions SET grade = ?, feedback = ? WHERE id = ?')
    ->execute([$grade ?: null, $feedback ?: null, $subId]);
send(['ok' => true]);
