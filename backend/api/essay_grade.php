<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$answerId = (int)input_int($b, 'answer_id', 1);
$points = (int)input_int($b, 'points_earned', 0, 1000);

$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare(
        "SELECT ans.id, ans.attempt_id, q.points, q.type, a.class_id
         FROM answers ans JOIN questions q ON q.id = ans.question_id
         JOIN attempts at ON at.id = ans.attempt_id
         JOIN assessments a ON a.id = at.assessment_id
         WHERE ans.id = ? FOR UPDATE"
    );
    $stmt->execute([$answerId]);
    $answer = $stmt->fetch();
    if (!$answer) fail('Answer not found.', 404, 'NOT_FOUND');
    owned_class_or_fail((int)$answer['class_id'], (int)$user['id']);
    if ($answer['type'] !== 'essay') fail('Only essay answers can be manually graded.', 422, 'INVALID_ANSWER_TYPE');
    if ($points > (float)$answer['points']) {
        fail('Points cannot exceed the question maximum.', 422, 'VALIDATION_ERROR');
    }
    $pdo->prepare(
        "UPDATE answers SET points_earned = ?, grading_status = 'graded',
         is_correct = ?, graded_at = UTC_TIMESTAMP() WHERE id = ?"
    )->execute([$points, $points >= (float)$answer['points'] ? 1 : 0, $answerId]);
    $result = recalculate_attempt((int)$answer['attempt_id']);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'essay.graded', 'answer', $answerId, ['points' => $points]);
send(['success' => true, ...$result]);
