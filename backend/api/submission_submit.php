<?php
// Student submits/updates their homework. Accepts multipart (file) or JSON (text).
// Body: homework_id, text?, file? Enforces one submission per (homework, student).
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'student');
require_method('POST');

$b = body();
$homeworkId = (int)($b['homework_id'] ?? 0);
$text = trim($b['text'] ?? '');

$stmt = db()->prepare('SELECT class_id FROM homework WHERE id = ?');
$stmt->execute([$homeworkId]);
$hw = $stmt->fetch();
if (!$hw) fail('Homework not found', 404);
enrolled_or_fail((int)$hw['class_id'], (int)$user['id']);

$filePath = save_upload('file');
if ($text === '' && !$filePath) fail('Provide text or a file.');

// Upsert (unique key on homework_id+student_id). Keep existing file if none uploaded.
$existing = db()->prepare('SELECT id, file_path FROM submissions WHERE homework_id = ? AND student_id = ?');
$existing->execute([$homeworkId, $user['id']]);
$row = $existing->fetch();

if ($row) {
    $keepFile = $filePath ?: $row['file_path'];
    db()->prepare('UPDATE submissions SET text = ?, file_path = ?, submitted_at = NOW() WHERE id = ?')
        ->execute([$text, $keepFile, $row['id']]);
    $id = (int)$row['id'];
} else {
    db()->prepare('INSERT INTO submissions (homework_id, student_id, text, file_path) VALUES (?,?,?,?)')
        ->execute([$homeworkId, $user['id'], $text, $filePath]);
    $id = (int)db()->lastInsertId();
}
send(['id' => $id], 201);
