<?php
// Returns an assessment with its questions and options.
// For students, `is_correct` flags are stripped so answers aren't leaked.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$id = (int)($_GET['id'] ?? 0);

$stmt = db()->prepare('SELECT * FROM assessments WHERE id = ?');
$stmt->execute([$id]);
$a = $stmt->fetch();
if (!$a) fail('Assessment not found', 404);
class_access_or_fail((int)$a['class_id'], $user);

$isTeacher = $user['role'] === 'teacher';

$qs = db()->prepare('SELECT * FROM questions WHERE assessment_id = ? ORDER BY position, id');
$qs->execute([$id]);
$questions = [];
foreach ($qs->fetchAll() as $q) {
    $opts = db()->prepare('SELECT * FROM options WHERE question_id = ? ORDER BY id');
    $opts->execute([$q['id']]);
    $options = [];
    foreach ($opts->fetchAll() as $o) {
        $opt = ['id' => (int)$o['id'], 'text' => $o['text']];
        if ($isTeacher) $opt['is_correct'] = (bool)$o['is_correct'];
        $options[] = $opt;
    }
    $questions[] = [
        'id' => (int)$q['id'],
        'text' => $q['text'],
        'type' => $q['type'],
        'points' => (int)$q['points'],
        // fill_blank correct answer lives in options[0]; hide from students.
        'options' => ($q['type'] === 'fill_blank' && !$isTeacher) ? [] : $options,
    ];
}

send([
    'assessment' => [
        'id' => (int)$a['id'],
        'class_id' => (int)$a['class_id'],
        'title' => $a['title'],
        'description' => $a['description'],
        'kind' => $a['kind'],
        'duration_min' => (int)$a['duration_min'],
    ],
    'questions' => $questions,
]);
