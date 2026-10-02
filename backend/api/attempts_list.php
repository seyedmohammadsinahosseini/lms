<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('GET');
$user = require_auth();
require_role($user, 'teacher');
$assessmentId = filter_var($_GET['assessment_id'] ?? null, FILTER_VALIDATE_INT);
if (!$assessmentId) fail('assessment_id is required.', 422, 'VALIDATION_ERROR');
$assessment = assessment_access_or_fail((int)$assessmentId, $user);
owned_class_or_fail((int)$assessment['class_id'], (int)$user['id']);
[$page, $perPage, $offset] = pagination(30, 100);
$count = db()->prepare('SELECT COUNT(*) FROM attempts WHERE assessment_id = ?');
$count->execute([$assessmentId]);
$stmt = db()->prepare(
    'SELECT at.id, at.student_id, at.attempt_no, at.score, at.status,
            at.started_at, at.deadline_at, at.submitted_at, u.full_name AS student_name
     FROM attempts at JOIN users u ON u.id = at.student_id
     WHERE at.assessment_id = ? ORDER BY at.started_at DESC LIMIT ? OFFSET ?'
);
$stmt->bindValue(1, (int)$assessmentId, PDO::PARAM_INT);
$stmt->bindValue(2, $perPage, PDO::PARAM_INT);
$stmt->bindValue(3, $offset, PDO::PARAM_INT);
$stmt->execute();
$attempts = array_map(static fn(array $r): array => [
    'id' => (int)$r['id'], 'student_id' => (int)$r['student_id'],
    'student_name' => $r['student_name'], 'attempt_no' => (int)$r['attempt_no'],
    'score' => $r['score'] === null ? null : (float)$r['score'], 'status' => $r['status'],
    'started_at' => iso_utc($r['started_at']), 'deadline_at' => iso_utc($r['deadline_at']),
    'submitted_at' => iso_utc($r['submitted_at']),
], $stmt->fetchAll());
send(['attempts' => $attempts, 'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => (int)$count->fetchColumn()]]);
