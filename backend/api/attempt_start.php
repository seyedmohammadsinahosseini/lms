<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'student');
$b = body();
$assessmentId = (int)input_int($b, 'assessment_id', 1);
$idempotencyKey = isset($b['idempotency_key']) && is_string($b['idempotency_key'])
    ? trim($b['idempotency_key']) : null;
if ($idempotencyKey !== null && (strlen($idempotencyKey) < 8 || strlen($idempotencyKey) > 80)) {
    fail('idempotency_key is invalid.', 422, 'VALIDATION_ERROR');
}

$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare('SELECT * FROM assessments WHERE id = ? FOR UPDATE');
    $stmt->execute([$assessmentId]);
    $assessment = $stmt->fetch();
    if (!$assessment) fail('Assessment not found.', 404, 'NOT_FOUND');
    enrolled_or_fail((int)$assessment['class_id'], (int)$user['id']);

    $pdo->prepare(
        "UPDATE attempts SET status = 'expired'
         WHERE assessment_id = ? AND student_id = ? AND status = 'in_progress'
           AND deadline_at IS NOT NULL AND deadline_at <= UTC_TIMESTAMP()"
    )->execute([$assessmentId, $user['id']]);

    $active = $pdo->prepare(
        "SELECT * FROM attempts WHERE assessment_id = ? AND student_id = ?
         AND status = 'in_progress' ORDER BY id DESC LIMIT 1"
    );
    $active->execute([$assessmentId, $user['id']]);
    $attempt = $active->fetch();

    if (!$attempt) {
        if (!assessment_is_open($assessment)) {
            fail('This assessment is not currently open.', 409, 'ASSESSMENT_NOT_OPEN');
        }
        $version = assessment_latest_published_version($assessmentId);
        if (!$version) fail('This assessment has no published version.', 409, 'ASSESSMENT_NOT_PUBLISHED');

        $counter = $pdo->prepare('SELECT COALESCE(MAX(attempt_no),0) FROM attempts WHERE assessment_id = ? AND student_id = ?');
        $counter->execute([$assessmentId, $user['id']]);
        $attemptNo = (int)$counter->fetchColumn() + 1;
        if ($attemptNo > (int)$assessment['max_attempts']) {
            fail('You have used all allowed attempts.', 409, 'ATTEMPT_LIMIT_REACHED');
        }

        $now = time();
        $deadline = null;
        if ((int)$assessment['duration_min'] > 0) {
            $deadline = $now + (int)$assessment['duration_min'] * 60;
        }
        if ($assessment['closes_at']) {
            $close = strtotime($assessment['closes_at'] . ' UTC');
            $deadline = $deadline === null ? $close : min($deadline, $close);
        }
        $deadlineSql = $deadline === null ? null : gmdate('Y-m-d H:i:s', $deadline);
        $pdo->prepare(
            'INSERT INTO attempts
             (assessment_id, assessment_version_id, student_id, attempt_no, started_at, deadline_at, idempotency_key)
             VALUES (?,?,?,?,UTC_TIMESTAMP(),?,?)'
        )->execute([$assessmentId, $version['id'], $user['id'], $attemptNo, $deadlineSql, $idempotencyKey]);
        $attemptId = (int)$pdo->lastInsertId();
        $attempt = [
            'id' => $attemptId, 'assessment_version_id' => $version['id'],
            'attempt_no' => $attemptNo, 'deadline_at' => $deadlineSql,
            'started_at' => gmdate('Y-m-d H:i:s'), 'status' => 'in_progress',
        ];
    }
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}

$questions = serialize_questions(assessment_questions((int)$attempt['assessment_version_id']), false);
audit_event((int)$user['id'], 'attempt.started', 'attempt', (int)$attempt['id'], ['assessment_id' => $assessmentId]);
send([
    'attempt' => [
        'id' => (int)$attempt['id'], 'attempt_no' => (int)$attempt['attempt_no'],
        'status' => $attempt['status'], 'started_at' => iso_utc($attempt['started_at']),
        'deadline_at' => iso_utc($attempt['deadline_at']),
    ],
    'assessment' => [
        'id' => (int)$assessment['id'], 'class_id' => (int)$assessment['class_id'],
        'title' => $assessment['title'], 'description' => $assessment['description'],
        'kind' => $assessment['kind'], 'duration_min' => (int)$assessment['duration_min'],
    ],
    'questions' => $questions,
], 201);
