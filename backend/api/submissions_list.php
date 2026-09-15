<?php
// Teacher (?homework_id=): all submissions for that homework.
// Student: only their own submission (privacy guaranteed server-side).
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$homeworkId = (int)($_GET['homework_id'] ?? 0);

$stmt = db()->prepare('SELECT class_id FROM homework WHERE id = ?');
$stmt->execute([$homeworkId]);
$hw = $stmt->fetch();
if (!$hw) fail('Homework not found', 404);

if ($user['role'] === 'teacher') {
    owned_class_or_fail((int)$hw['class_id'], (int)$user['id']);
    $stmt = db()->prepare(
        'SELECT s.*, u.full_name FROM submissions s
         JOIN users u ON u.id = s.student_id
         WHERE s.homework_id = ? ORDER BY s.submitted_at DESC'
    );
    $stmt->execute([$homeworkId]);
} else {
    enrolled_or_fail((int)$hw['class_id'], (int)$user['id']);
    $stmt = db()->prepare(
        'SELECT s.*, u.full_name FROM submissions s
         JOIN users u ON u.id = s.student_id
         WHERE s.homework_id = ? AND s.student_id = ?'
    );
    $stmt->execute([$homeworkId, $user['id']]);
}

$rows = array_map(fn($s) => [
    'id' => (int)$s['id'],
    'student_id' => (int)$s['student_id'],
    'student_name' => $s['full_name'],
    'text' => $s['text'],
    'file_path' => $s['file_path'],
    'submitted_at' => $s['submitted_at'],
    'grade' => $s['grade'],
    'feedback' => $s['feedback'],
], $stmt->fetchAll());
send(['submissions' => $rows]);
