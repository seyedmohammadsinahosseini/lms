<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('GET');
$user = require_auth();
$id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
if (!$id) fail('id is required.', 422, 'VALIDATION_ERROR');
$assessment = assessment_access_or_fail((int)$id, $user);

if ($user['role'] === 'teacher') {
    $version = assessment_current_version($assessment);
    $includeCorrect = true;
} else {
    // Questions are only returned for an already-started active attempt. This
    // prevents previewing the test without starting the server-side timer.
    $attemptId = filter_var($_GET['attempt_id'] ?? null, FILTER_VALIDATE_INT);
    if (!$attemptId) fail('Start the assessment first.', 409, 'ATTEMPT_REQUIRED');
    $stmt = db()->prepare(
        "SELECT assessment_version_id FROM attempts
         WHERE id = ? AND assessment_id = ? AND student_id = ? AND status = 'in_progress'"
    );
    $stmt->execute([$attemptId, $id, $user['id']]);
    $versionId = $stmt->fetchColumn();
    if (!$versionId) fail('Active attempt not found.', 404, 'ATTEMPT_NOT_FOUND');
    $version = ['id' => (int)$versionId, 'version_no' => null];
    $includeCorrect = false;
}

send([
    'assessment' => [
        'id' => (int)$assessment['id'], 'class_id' => (int)$assessment['class_id'],
        'title' => $assessment['title'], 'description' => $assessment['description'],
        'kind' => $assessment['kind'], 'status' => $assessment['status'],
        'duration_min' => (int)$assessment['duration_min'],
        'max_attempts' => (int)$assessment['max_attempts'],
        'opens_at' => iso_utc($assessment['opens_at']), 'closes_at' => iso_utc($assessment['closes_at']),
        'answer_release_policy' => $assessment['answer_release_policy'],
        'version_no' => $version['version_no'],
    ],
    'questions' => serialize_questions(assessment_questions((int)$version['id']), $includeCorrect),
]);
