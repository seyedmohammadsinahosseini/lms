<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$classId = (int)input_int($b, 'class_id', 1);
$title = input_string($b, 'title', 160, true, 1);
$description = input_string($b, 'description', 10000, false);
$kind = input_enum($b, 'kind', ['quiz', 'test', 'exam'], 'quiz');
$duration = (int)input_int($b, 'duration_min', 0, 10080, false) ?: 0;
$maxAttempts = (int)input_int($b, 'max_attempts', 1, 100, false) ?: 1;
$opensAt = input_datetime($b, 'opens_at');
$closesAt = input_datetime($b, 'closes_at');
$release = input_enum($b, 'answer_release_policy', ['immediately', 'after_close', 'teacher_release', 'never'], 'teacher_release');
owned_class_or_fail($classId, (int)$user['id']);
if ($opensAt && $closesAt && strtotime($closesAt . ' UTC') <= strtotime($opensAt . ' UTC')) {
    fail('closes_at must be after opens_at.', 422, 'VALIDATION_ERROR');
}

$pdo = db();
$pdo->beginTransaction();
try {
    $pdo->prepare(
        'INSERT INTO assessments
         (class_id, title, description, kind, duration_min, max_attempts, opens_at, closes_at, answer_release_policy)
         VALUES (?,?,?,?,?,?,?,?,?)'
    )->execute([$classId, $title, $description, $kind, $duration, $maxAttempts, $opensAt, $closesAt, $release]);
    $id = (int)$pdo->lastInsertId();
    $pdo->prepare('INSERT INTO assessment_versions (assessment_id, version_no) VALUES (?,1)')
        ->execute([$id]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'assessment.created', 'assessment', $id);
send(['id' => $id, 'status' => 'draft', 'version_no' => 1], 201);
