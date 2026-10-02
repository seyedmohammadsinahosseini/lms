<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'student');
$b = body();
$attemptId = (int)input_int($b, 'attempt_id', 1);
$givenAnswers = $b['answers'] ?? [];
if (!is_array($givenAnswers)) fail('answers must be an object.', 422, 'VALIDATION_ERROR');

$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare(
        'SELECT at.*, a.class_id FROM attempts at
         JOIN assessments a ON a.id = at.assessment_id
         WHERE at.id = ? FOR UPDATE'
    );
    $stmt->execute([$attemptId]);
    $attempt = $stmt->fetch();
    if (!$attempt) fail('Attempt not found.', 404, 'NOT_FOUND');
    if ((int)$attempt['student_id'] !== (int)$user['id']) fail('Forbidden.', 403, 'FORBIDDEN');
    if ($attempt['status'] !== 'in_progress') {
        $pdo->commit();
        $result = ['score' => $attempt['score'] === null ? null : (float)$attempt['score'], 'status' => $attempt['status']];
        send(['attempt_id' => $attemptId, ...$result, 'pending_essay' => $attempt['status'] === 'pending_grading']);
    }
    if ($attempt['deadline_at'] && strtotime($attempt['deadline_at'] . ' UTC') < time()) {
        $pdo->prepare("UPDATE attempts SET status = 'expired' WHERE id = ?")->execute([$attemptId]);
        $pdo->commit();
        fail('The assessment deadline has passed.', 409, 'ATTEMPT_EXPIRED');
    }

    $questions = assessment_questions((int)$attempt['assessment_version_id']);
    $insertAnswer = $pdo->prepare(
        'INSERT INTO answers
         (attempt_id, question_id, answer_text, points_earned, grading_status, is_correct, graded_at)
         VALUES (?,?,?,?,?,?,?)'
    );
    $insertSelected = $pdo->prepare(
        'INSERT INTO answer_options (answer_id, question_id, option_id) VALUES (?,?,?)'
    );

    foreach ($questions as $question) {
        $qid = (int)$question['id'];
        $given = $givenAnswers[(string)$qid] ?? $givenAnswers[$qid] ?? null;
        $text = null;
        $points = 0.0;
        $status = 'auto_graded';
        $isCorrect = false;
        $gradedAt = gmdate('Y-m-d H:i:s');
        $selectedIds = [];

        if ($question['type'] === 'essay') {
            $text = is_string($given) ? trim($given) : '';
            if ($text !== '') {
                $points = null;
                $status = 'pending';
                $isCorrect = null;
                $gradedAt = null;
            }
        } elseif ($question['type'] === 'fill_blank') {
            $text = is_string($given) ? trim($given) : '';
            $correct = (string)($question['options'][0]['text'] ?? '');
            $normalize = static fn(string $value): string => mb_strtolower(trim(preg_replace('/\s+/u', ' ', $value) ?? $value));
            $isCorrect = hash_equals($normalize($correct), $normalize($text));
            $points = $isCorrect ? (float)$question['points'] : 0.0;
        } else {
            if ($question['type'] === 'multiple_select') {
                $selectedIds = is_array($given) ? array_values(array_unique(array_map('intval', $given))) : [];
            } else {
                $selected = filter_var($given, FILTER_VALIDATE_INT);
                $selectedIds = $selected === false ? [] : [(int)$selected];
            }
            $valid = [];
            $correctIds = [];
            foreach ($question['options'] as $option) {
                $valid[(int)$option['id']] = true;
                if ($option['is_correct']) $correctIds[] = (int)$option['id'];
            }
            foreach ($selectedIds as $selectedId) {
                if (!isset($valid[$selectedId])) {
                    fail('An option does not belong to its question.', 422, 'INVALID_OPTION', ['question_id' => $qid]);
                }
            }
            sort($selectedIds);
            sort($correctIds);
            $isCorrect = $selectedIds === $correctIds;
            $points = $isCorrect ? (float)$question['points'] : 0.0;
        }

        $insertAnswer->execute([
            $attemptId, $qid, $text, $points, $status,
            $isCorrect === null ? null : ($isCorrect ? 1 : 0), $gradedAt,
        ]);
        $answerId = (int)$pdo->lastInsertId();
        foreach ($selectedIds as $selectedId) $insertSelected->execute([$answerId, $qid, $selectedId]);
    }

    $pdo->prepare("UPDATE attempts SET submitted_at = UTC_TIMESTAMP(), status = 'submitted' WHERE id = ?")
        ->execute([$attemptId]);
    $result = recalculate_attempt($attemptId);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'attempt.submitted', 'attempt', $attemptId);
send(['attempt_id' => $attemptId, ...$result]);
