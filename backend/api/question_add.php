<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$assessmentId = (int)input_int($b, 'assessment_id', 1);
$text = input_string($b, 'text', 10000, true, 1);
$type = input_enum($b, 'type', ['single_choice', 'multiple_select', 'multiple_choice', 'true_false', 'yes_no', 'fill_blank', 'essay']);
$points = (int)input_int($b, 'points', 1, 1000, false) ?: 1;

$options = [];
if (in_array($type, ['single_choice', 'multiple_select', 'multiple_choice'], true)) {
    $rawOptions = $b['options'] ?? null;
    if (!is_array($rawOptions) || count($rawOptions) < 2 || count($rawOptions) > 20) {
        fail('Choice questions need 2 to 20 options.', 422, 'VALIDATION_ERROR');
    }
    $correctCount = 0;
    foreach (array_values($rawOptions) as $position => $option) {
        if (!is_array($option)) fail('Each option must be an object.', 422, 'VALIDATION_ERROR');
        $optionText = input_string($option, 'text', 2000, true, 1);
        $correct = input_bool($option, 'is_correct', false);
        if ($correct) $correctCount++;
        $options[] = ['text' => $optionText, 'is_correct' => $correct, 'position' => $position];
    }
    if ($type === 'multiple_choice') $type = $correctCount > 1 ? 'multiple_select' : 'single_choice';
    if ($type === 'single_choice' && $correctCount !== 1) {
        fail('Single choice requires exactly one correct option.', 422, 'VALIDATION_ERROR');
    }
    if ($type === 'multiple_select' && $correctCount < 1) {
        fail('Multiple select requires at least one correct option.', 422, 'VALIDATION_ERROR');
    }
} elseif (in_array($type, ['true_false', 'yes_no'], true)) {
    $allowed = $type === 'true_false' ? ['true', 'false'] : ['yes', 'no'];
    $labels = $type === 'true_false' ? ['True', 'False'] : ['Yes', 'No'];
    $correct = strtolower((string)($b['correct'] ?? ''));
    if ($correct === '' && isset($b['options']) && is_array($b['options'])) {
        foreach ($b['options'] as $option) {
            if (is_array($option) && !empty($option['is_correct'])) {
                $correct = strtolower((string)($option['text'] ?? ''));
            }
        }
    }
    if (!in_array($correct, $allowed, true)) {
        fail('Select the correct answer.', 422, 'VALIDATION_ERROR', ['correct' => 'Required']);
    }
    foreach ($labels as $position => $label) {
        $options[] = ['text' => $label, 'is_correct' => strtolower($label) === $correct, 'position' => $position];
    }
} elseif ($type === 'fill_blank') {
    $answer = isset($b['answer']) && is_string($b['answer']) ? trim($b['answer']) : '';
    if ($answer === '' && isset($b['options'][0]['text'])) $answer = trim((string)$b['options'][0]['text']);
    if ($answer === '' || mb_strlen($answer) > 2000) {
        fail('Provide the correct fill-in answer.', 422, 'VALIDATION_ERROR');
    }
    $options[] = ['text' => $answer, 'is_correct' => true, 'position' => 0];
}

$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare('SELECT * FROM assessments WHERE id = ? FOR UPDATE');
    $stmt->execute([$assessmentId]);
    $assessment = $stmt->fetch();
    if (!$assessment) fail('Assessment not found.', 404, 'NOT_FOUND');
    owned_class_or_fail((int)$assessment['class_id'], (int)$user['id']);
    $version = ensure_editable_assessment_version($assessment);
    $posStmt = $pdo->prepare('SELECT COALESCE(MAX(position) + 1, 0) FROM questions WHERE assessment_version_id = ?');
    $posStmt->execute([$version['id']]);
    $position = (int)$posStmt->fetchColumn();
    $pdo->prepare(
        'INSERT INTO questions (assessment_version_id, text, type, points, position) VALUES (?,?,?,?,?)'
    )->execute([$version['id'], $text, $type, $points, $position]);
    $questionId = (int)$pdo->lastInsertId();
    $insert = $pdo->prepare('INSERT INTO options (question_id, text, is_correct, position) VALUES (?,?,?,?)');
    foreach ($options as $option) {
        $insert->execute([$questionId, $option['text'], $option['is_correct'] ? 1 : 0, $option['position']]);
    }
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'question.created', 'question', $questionId, ['assessment_id' => $assessmentId]);
send(['id' => $questionId, 'type' => $type, 'version_no' => (int)$version['version_no']], 201);
