<?php
declare(strict_types=1);
require_once __DIR__ . '/../assessment_service.php';
require_method('GET');
$user = require_auth();
$classId = filter_var($_GET['class_id'] ?? null, FILTER_VALIDATE_INT);
if (!$classId) fail('class_id is required.', 422, 'VALIDATION_ERROR');
class_access_or_fail((int)$classId, $user);
[$page, $perPage, $offset] = pagination(30, 100);

$where = $user['role'] === 'student' ? "AND a.status IN ('published','closed')" : '';
$count = db()->prepare("SELECT COUNT(*) FROM assessments a WHERE a.class_id = ? {$where}");
$count->execute([$classId]);
$stmt = db()->prepare(
    "SELECT a.*,
       COALESCE((SELECT av.id FROM assessment_versions av
         WHERE av.assessment_id = a.id " . ($user['role'] === 'student' ? 'AND av.is_published = 1' : 'AND av.version_no = a.current_version_no') . "
         ORDER BY av.version_no DESC LIMIT 1), 0) AS visible_version_id
     FROM assessments a WHERE a.class_id = ? {$where}
     ORDER BY a.created_at DESC LIMIT ? OFFSET ?"
);
$stmt->bindValue(1, (int)$classId, PDO::PARAM_INT);
$stmt->bindValue(2, $perPage, PDO::PARAM_INT);
$stmt->bindValue(3, $offset, PDO::PARAM_INT);
$stmt->execute();
$rows = $stmt->fetchAll();
$versionIds = array_values(array_filter(array_map(static fn($a) => (int)$a['visible_version_id'], $rows)));
$questionCounts = [];
if ($versionIds !== []) {
    $marks = implode(',', array_fill(0, count($versionIds), '?'));
    $q = db()->prepare("SELECT assessment_version_id, COUNT(*) n FROM questions WHERE assessment_version_id IN ({$marks}) GROUP BY assessment_version_id");
    $q->execute($versionIds);
    foreach ($q->fetchAll() as $r) $questionCounts[(int)$r['assessment_version_id']] = (int)$r['n'];
}
$latestAttempts = [];
if ($user['role'] === 'student' && $rows !== []) {
    $ids = array_map(static fn($a) => (int)$a['id'], $rows);
    $marks = implode(',', array_fill(0, count($ids), '?'));
    $q = db()->prepare(
        "SELECT at.* FROM attempts at
         JOIN (SELECT assessment_id, MAX(id) id FROM attempts
               WHERE student_id = ? AND assessment_id IN ({$marks}) GROUP BY assessment_id) latest
           ON latest.id = at.id"
    );
    $q->execute(array_merge([(int)$user['id']], $ids));
    foreach ($q->fetchAll() as $r) $latestAttempts[(int)$r['assessment_id']] = $r;
}
$out = [];
foreach ($rows as $assessment) {
    $item = [
        'id' => (int)$assessment['id'], 'title' => $assessment['title'],
        'description' => $assessment['description'], 'kind' => $assessment['kind'],
        'status' => $assessment['status'], 'duration_min' => (int)$assessment['duration_min'],
        'max_attempts' => (int)$assessment['max_attempts'],
        'opens_at' => iso_utc($assessment['opens_at']), 'closes_at' => iso_utc($assessment['closes_at']),
        'answer_release_policy' => $assessment['answer_release_policy'],
        'answers_released' => assessment_answers_released($assessment),
        'question_count' => $questionCounts[(int)$assessment['visible_version_id']] ?? 0,
    ];
    if ($user['role'] === 'student') {
        $attempt = $latestAttempts[(int)$assessment['id']] ?? null;
        $item['attempt'] = $attempt ? [
            'id' => (int)$attempt['id'], 'status' => $attempt['status'],
            'score' => $attempt['score'] === null ? null : (float)$attempt['score'],
            'deadline_at' => iso_utc($attempt['deadline_at']),
        ] : null;
    }
    $out[] = $item;
}
send(['assessments' => $out, 'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => (int)$count->fetchColumn()]]);
