<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$classId = (int)($_GET['class_id'] ?? 0);
class_access_or_fail($classId, $user);

$stmt = db()->prepare(
    'SELECT a.*, (SELECT COUNT(*) FROM questions q WHERE q.assessment_id = a.id) AS question_count
     FROM assessments a WHERE a.class_id = ? ORDER BY a.created_at DESC'
);
$stmt->execute([$classId]);
$rows = $stmt->fetchAll();

// For students, attach their latest attempt status/score per assessment.
$out = [];
foreach ($rows as $a) {
    $item = [
        'id' => (int)$a['id'],
        'title' => $a['title'],
        'description' => $a['description'],
        'kind' => $a['kind'],
        'duration_min' => (int)$a['duration_min'],
        'question_count' => (int)$a['question_count'],
    ];
    if ($user['role'] === 'student') {
        $s = db()->prepare('SELECT id, status, score FROM attempts WHERE assessment_id = ? AND student_id = ? ORDER BY id DESC LIMIT 1');
        $s->execute([$a['id'], $user['id']]);
        $att = $s->fetch();
        $item['attempt'] = $att ? [
            'id' => (int)$att['id'],
            'status' => $att['status'],
            'score' => $att['score'] !== null ? (float)$att['score'] : null,
        ] : null;
    }
    $out[] = $item;
}
send(['assessments' => $out]);
