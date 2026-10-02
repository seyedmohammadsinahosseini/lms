<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$assessmentId = (int)input_int($b, 'assessment_id', 1);
$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare('SELECT * FROM assessments WHERE id = ? FOR UPDATE');
    $stmt->execute([$assessmentId]);
    $assessment = $stmt->fetch();
    if (!$assessment) fail('Assessment not found.', 404, 'NOT_FOUND');
    owned_class_or_fail((int)$assessment['class_id'], (int)$user['id']);
    $version = assessment_current_version($assessment);
    $count = $pdo->prepare('SELECT COUNT(*) FROM questions WHERE assessment_version_id = ?');
    $count->execute([$version['id']]);
    if ((int)$count->fetchColumn() === 0) {
        fail('Add at least one question before publishing.', 422, 'ASSESSMENT_EMPTY');
    }
    $pdo->prepare(
        'UPDATE assessment_versions SET is_published = 1, published_at = UTC_TIMESTAMP() WHERE id = ?'
    )->execute([$version['id']]);
    $pdo->prepare(
        "UPDATE assessments SET status = 'published', published_at = COALESCE(published_at, UTC_TIMESTAMP()) WHERE id = ?"
    )->execute([$assessmentId]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'assessment.published', 'assessment', $assessmentId, ['version' => (int)$version['version_no']]);
send(['success' => true, 'status' => 'published', 'version_no' => (int)$version['version_no']]);
