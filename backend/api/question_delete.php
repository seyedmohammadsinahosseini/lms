<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$questionId = (int)($b['question_id'] ?? 0);

$stmt = db()->prepare('
    SELECT a.class_id FROM questions q
    JOIN assessments a ON a.id = q.assessment_id
    WHERE q.id = ?
');
$stmt->execute([$questionId]);
$q = $stmt->fetch();
if (!$q) fail('Question not found', 404);
owned_class_or_fail((int)$q['class_id'], (int)$user['id']);

db()->prepare('DELETE FROM questions WHERE id = ?')->execute([$questionId]);
send(['success' => true]);