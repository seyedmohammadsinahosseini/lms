<?php
// Add a question (any of 5 types) to an assessment.
// Body: assessment_id, text, type, points, options[] (each {text, is_correct}).
// For true_false/yes_no the client may omit options (server supplies defaults);
// correct side is given via `correct` ("true"/"false" or "yes"/"no").
// For fill_blank, `answer` holds the correct text. essay needs no options.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$assessmentId = (int)($b['assessment_id'] ?? 0);
$text = trim($b['text'] ?? '');
$type = $b['type'] ?? '';
$points = max(1, (int)($b['points'] ?? 1));

// Verify ownership through the class.
$stmt = db()->prepare('SELECT class_id FROM assessments WHERE id = ?');
$stmt->execute([$assessmentId]);
$a = $stmt->fetch();
if (!$a) fail('Assessment not found', 404);
owned_class_or_fail((int)$a['class_id'], (int)$user['id']);

$valid = ['multiple_choice', 'true_false', 'yes_no', 'fill_blank', 'essay'];
if (!in_array($type, $valid, true)) fail('Invalid question type.');
if ($text === '') fail('Question text is required.');

// Build the option list per type.
$options = []; // each: [text, is_correct]
if ($type === 'multiple_choice') {
    $opts = $b['options'] ?? [];
    if (count($opts) < 2) fail('Multiple choice needs at least 2 options.');
    $hasCorrect = false;
    foreach ($opts as $o) {
        $t = trim($o['text'] ?? '');
        if ($t === '') fail('Options cannot be empty.');
        $c = !empty($o['is_correct']);
        if ($c) $hasCorrect = true;
        $options[] = [$t, $c ? 1 : 0];
    }
    if (!$hasCorrect) fail('Mark one option as correct.');
} elseif ($type === 'true_false') {
    $correct = strtolower($b['correct'] ?? 'true');
    $options[] = ['True', $correct === 'true' ? 1 : 0];
    $options[] = ['False', $correct === 'false' ? 1 : 0];
} elseif ($type === 'yes_no') {
    $correct = strtolower($b['correct'] ?? 'yes');
    $options[] = ['Yes', $correct === 'yes' ? 1 : 0];
    $options[] = ['No', $correct === 'no' ? 1 : 0];
} elseif ($type === 'fill_blank') {
    // Accept both 'answer' (legacy) and 'options' (new format) for fill_blank
    $answer = '';
    if (!empty($b['options']) && is_array($b['options'])) {
        $opts = $b['options'];
        if (count($opts) > 0 && isset($opts[0]['text'])) {
            $answer = trim($opts[0]['text'] ?? '');
        }
    }
    if ($answer === '') {
        $answer = trim($b['answer'] ?? '');
    }
    if ($answer === '') fail('Provide the correct answer.');
    $options[] = [$answer, 1];
}
// essay -> no options

$posStmt = db()->prepare('SELECT COALESCE(MAX(position)+1,0) FROM questions WHERE assessment_id = ?');
$posStmt->execute([$assessmentId]);
$pos = (int)$posStmt->fetchColumn();

db()->beginTransaction();
try {
    $stmt = db()->prepare('INSERT INTO questions (assessment_id, text, type, points, position) VALUES (?,?,?,?,?)');
    $stmt->execute([$assessmentId, $text, $type, $points, $pos]);
    $qid = (int)db()->lastInsertId();
    if ($options) {
        $ins = db()->prepare('INSERT INTO options (question_id, text, is_correct) VALUES (?,?,?)');
        foreach ($options as [$ot, $oc]) $ins->execute([$qid, $ot, $oc]);
    }
    db()->commit();
} catch (Throwable $e) {
    db()->rollBack();
    fail('Could not save question.', 500);
}
send(['id' => $qid], 201);
