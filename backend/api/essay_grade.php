<?php
// Teacher grades one essay answer. Body: answer_id, points_earned.
// Recomputes the attempt score across all answers and marks it 'graded'
// once no essay answers remain ungraded.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$answerId = (int)($b['answer_id'] ?? 0);
$points = max(0, (int)($b['points_earned'] ?? 0));

// Load answer -> question -> attempt -> class, verify ownership.
$stmt = db()->prepare(
    'SELECT ans.*, q.points AS q_points, q.type AS q_type, at.id AS attempt_id,
            at.assessment_id, a.class_id
     FROM answers ans
     JOIN questions q ON q.id = ans.question_id
     JOIN attempts at ON at.id = ans.attempt_id
     JOIN assessments a ON a.id = at.assessment_id
     WHERE ans.id = ?'
);
$stmt->execute([$answerId]);
$row = $stmt->fetch();
if (!$row) fail('Answer not found', 404);
if ($row['q_type'] !== 'essay') fail('Only essay answers are graded manually.');
owned_class_or_fail((int)$row['class_id'], (int)$user['id']);
if ($points > (int)$row['q_points']) fail('Points exceed the question maximum.');

db()->beginTransaction();
try {
    db()->prepare('UPDATE answers SET points_earned = ?, is_correct = ? WHERE id = ?')
        ->execute([$points, $points > 0 ? 1 : 0, $answerId]);

    $attemptId = (int)$row['attempt_id'];
    $assessmentId = (int)$row['assessment_id'];

    $total = (int)db()->query('SELECT COALESCE(SUM(points),0) FROM questions WHERE assessment_id = ' . $assessmentId)->fetchColumn();
    $earned = (int)db()->query('SELECT COALESCE(SUM(points_earned),0) FROM answers WHERE attempt_id = ' . $attemptId)->fetchColumn();

    // Any essay still ungraded (points_earned NULL)?
    $pending = db()->prepare(
        "SELECT COUNT(*) FROM answers ans JOIN questions q ON q.id = ans.question_id
         WHERE ans.attempt_id = ? AND q.type = 'essay' AND ans.points_earned IS NULL"
    );
    $pending->execute([$attemptId]);
    $status = ((int)$pending->fetchColumn() === 0) ? 'graded' : 'completed';

    $score = $total > 0 ? round($earned / $total * 100, 2) : 0;
    db()->prepare('UPDATE attempts SET score = ?, status = ? WHERE id = ?')
        ->execute([$score, $status, $attemptId]);
    db()->commit();
} catch (Throwable $e) {
    db()->rollBack();
    fail('Could not grade answer.', 500);
}
send(['score' => $score, 'status' => $status]);
