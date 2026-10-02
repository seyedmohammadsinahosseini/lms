<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('GET');
$user = require_auth();
$id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
if (!$id) fail('id is required.', 422, 'VALIDATION_ERROR');
$stmt = db()->prepare(
    'SELECT at.*, a.class_id, a.title, a.answer_release_policy, a.closes_at, a.answers_released_at
     FROM attempts at JOIN assessments a ON a.id = at.assessment_id WHERE at.id = ?'
);
$stmt->execute([$id]);
$attempt = $stmt->fetch();
if (!$attempt) fail('Attempt not found.', 404, 'NOT_FOUND');
$isTeacher = $user['role'] === 'teacher';
if ($isTeacher) {
    owned_class_or_fail((int)$attempt['class_id'], (int)$user['id']);
} elseif ((int)$attempt['student_id'] !== (int)$user['id']) {
    fail('Forbidden.', 403, 'FORBIDDEN');
}
$showAnswers = $isTeacher || assessment_answers_released($attempt);

$stmt = db()->prepare(
    "SELECT q.id AS question_id, q.text, q.type, q.points, q.position,
            ans.id AS answer_id, ans.answer_text, ans.points_earned,
            ans.grading_status, ans.is_correct,
            GROUP_CONCAT(DISTINCT chosen.text ORDER BY chosen.position SEPARATOR '|||') AS chosen_options,
            GROUP_CONCAT(DISTINCT correct.text ORDER BY correct.position SEPARATOR '|||') AS correct_options
     FROM questions q
     LEFT JOIN answers ans ON ans.question_id = q.id AND ans.attempt_id = ?
     LEFT JOIN answer_options ao ON ao.answer_id = ans.id
     LEFT JOIN options chosen ON chosen.id = ao.option_id
     LEFT JOIN options correct ON correct.question_id = q.id AND correct.is_correct = 1
     WHERE q.assessment_version_id = ?
     GROUP BY q.id, q.text, q.type, q.points, q.position,
              ans.id, ans.answer_text, ans.points_earned, ans.grading_status, ans.is_correct
     ORDER BY q.position, q.id"
);
$stmt->execute([$id, $attempt['assessment_version_id']]);
$answers = [];
foreach ($stmt->fetchAll() as $row) {
    $correct = null;
    if ($showAnswers) {
        $correct = $row['type'] === 'fill_blank'
            ? $row['correct_options']
            : ($row['correct_options'] === null ? null : str_replace('|||', ', ', $row['correct_options']));
    }
    $answers[] = [
        'answer_id' => $row['answer_id'] === null ? null : (int)$row['answer_id'],
        'question_id' => (int)$row['question_id'], 'text' => $row['text'],
        'type' => $row['type'], 'points' => (float)$row['points'],
        'answer_text' => $row['answer_text'],
        'chosen_option' => $row['chosen_options'] === null ? null : str_replace('|||', ', ', $row['chosen_options']),
        'correct_answer' => $correct,
        'points_earned' => $row['points_earned'] === null ? null : (float)$row['points_earned'],
        'grading_status' => $row['grading_status'],
        'is_correct' => $row['is_correct'] === null ? null : (bool)$row['is_correct'],
    ];
}
send([
    'attempt' => [
        'id' => (int)$attempt['id'], 'assessment_id' => (int)$attempt['assessment_id'],
        'assessment_title' => $attempt['title'], 'attempt_no' => (int)$attempt['attempt_no'],
        'score' => $attempt['score'] === null ? null : (float)$attempt['score'],
        'status' => $attempt['status'], 'started_at' => iso_utc($attempt['started_at']),
        'deadline_at' => iso_utc($attempt['deadline_at']), 'submitted_at' => iso_utc($attempt['submitted_at']),
        'answers_released' => $showAnswers,
    ],
    'answers' => $answers,
]);
