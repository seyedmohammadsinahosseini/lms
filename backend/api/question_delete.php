<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$questionId = (int)input_int($b, 'question_id', 1);

$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare(
        'SELECT q.*, av.assessment_id, av.version_no
         FROM questions q JOIN assessment_versions av ON av.id = q.assessment_version_id
         WHERE q.id = ?'
    );
    $stmt->execute([$questionId]);
    $source = $stmt->fetch();
    if (!$source) fail('Question not found.', 404, 'NOT_FOUND');
    $lock = $pdo->prepare('SELECT * FROM assessments WHERE id = ? FOR UPDATE');
    $lock->execute([$source['assessment_id']]);
    $assessment = $lock->fetch();
    owned_class_or_fail((int)$assessment['class_id'], (int)$user['id']);
    if ((int)$source['version_no'] !== (int)$assessment['current_version_no']) {
        fail('Only the current assessment version can be edited.', 409, 'VERSION_IMMUTABLE');
    }
    $editable = ensure_editable_assessment_version($assessment);
    $deleteId = $questionId;
    if ((int)$editable['id'] !== (int)$source['assessment_version_id']) {
        $mapped = $pdo->prepare(
            'SELECT id FROM questions WHERE assessment_version_id = ? AND position = ?'
        );
        $mapped->execute([$editable['id'], $source['position']]);
        $deleteId = (int)$mapped->fetchColumn();
    }
    $pdo->prepare('DELETE FROM questions WHERE id = ?')->execute([$deleteId]);
    // Keep ordering dense and the unique position constraint valid.
    $pdo->prepare(
        'UPDATE questions SET position = position - 1
         WHERE assessment_version_id = ? AND position > ?'
    )->execute([$editable['id'], $source['position']]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'question.deleted', 'question', $questionId, ['assessment_id' => (int)$source['assessment_id']]);
send(['success' => true, 'version_no' => (int)$editable['version_no']]);
