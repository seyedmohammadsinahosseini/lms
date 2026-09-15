<?php
// Full attempt detail with per-question answers. Accessible to the owning
// student or the class teacher. Used for results view and essay grading.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$id = (int)($_GET['id'] ?? 0);

$stmt = db()->prepare(
    'SELECT at.*, a.class_id, a.title FROM attempts at
     JOIN assessments a ON a.id = at.assessment_id WHERE at.id = ?'
);
$stmt->execute([$id]);
$att = $stmt->fetch();
if (!$att) fail('Attempt not found', 404);

$isTeacher = $user['role'] === 'teacher';
if ($isTeacher) {
    owned_class_or_fail((int)$att['class_id'], (int)$user['id']);
} elseif ((int)$att['student_id'] !== (int)$user['id']) {
    fail('Forbidden', 403);
}

$stmt = db()->prepare(
    'SELECT q.id AS question_id, q.text, q.type, q.points, q.position,
            ans.id AS answer_id, ans.option_id, ans.answer_text, ans.points_earned, ans.is_correct
     FROM questions q
     LEFT JOIN answers ans ON ans.question_id = q.id AND ans.attempt_id = ?
     WHERE q.assessment_id = ? ORDER BY q.position, q.id'
);
$stmt->execute([$id, $att['assessment_id']]);

$items = [];
foreach ($stmt->fetchAll() as $r) {
    // Resolve chosen + correct option text for display.
    $chosen = null; $correct = null;
    $o = db()->prepare('SELECT id, text, is_correct FROM options WHERE question_id = ?');
    $o->execute([$r['question_id']]);
    foreach ($o->fetchAll() as $opt) {
        if ((int)$opt['is_correct'] === 1) $correct = $opt['text'];
        if ($r['option_id'] !== null && (int)$opt['id'] === (int)$r['option_id']) $chosen = $opt['text'];
    }
    $items[] = [
        'answer_id' => $r['answer_id'] !== null ? (int)$r['answer_id'] : null,
        'question_id' => (int)$r['question_id'],
        'text' => $r['text'],
        'type' => $r['type'],
        'points' => (int)$r['points'],
        'answer_text' => $r['answer_text'],
        'chosen_option' => $chosen,
        'correct_answer' => $correct,
        'points_earned' => $r['points_earned'] !== null ? (int)$r['points_earned'] : null,
        'is_correct' => $r['is_correct'] === null ? null : (bool)$r['is_correct'],
    ];
}

send([
    'attempt' => [
        'id' => (int)$att['id'],
        'assessment_id' => (int)$att['assessment_id'],
        'assessment_title' => $att['title'],
        'score' => $att['score'] !== null ? (float)$att['score'] : null,
        'status' => $att['status'],
        'submitted_at' => $att['submitted_at'],
    ],
    'answers' => $items,
]);
