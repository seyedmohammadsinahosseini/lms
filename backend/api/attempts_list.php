<?php
// Teacher: all attempts for an assessment (?assessment_id=). Student: own attempts.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$assessmentId = (int)($_GET['assessment_id'] ?? 0);

$stmt = db()->prepare('SELECT * FROM assessments WHERE id = ?');
$stmt->execute([$assessmentId]);
$a = $stmt->fetch();
if (!$a) fail('Assessment not found', 404);

if ($user['role'] === 'teacher') {
    owned_class_or_fail((int)$a['class_id'], (int)$user['id']);
    $stmt = db()->prepare(
        'SELECT at.*, u.full_name FROM attempts at
         JOIN users u ON u.id = at.student_id
         WHERE at.assessment_id = ? ORDER BY at.submitted_at DESC'
    );
    $stmt->execute([$assessmentId]);
} else {
    enrolled_or_fail((int)$a['class_id'], (int)$user['id']);
    $stmt = db()->prepare('SELECT at.*, u.full_name FROM attempts at JOIN users u ON u.id = at.student_id WHERE at.assessment_id = ? AND at.student_id = ? ORDER BY at.submitted_at DESC');
    $stmt->execute([$assessmentId, $user['id']]);
}

$rows = array_map(fn($r) => [
    'id' => (int)$r['id'],
    'student_id' => (int)$r['student_id'],
    'student_name' => $r['full_name'],
    'score' => $r['score'] !== null ? (float)$r['score'] : null,
    'status' => $r['status'],
    'submitted_at' => $r['submitted_at'],
], $stmt->fetchAll());
send(['attempts' => $rows]);
