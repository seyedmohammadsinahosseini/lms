<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$classId = (int)($_GET['class_id'] ?? 0);
class_access_or_fail($classId, $user);

$stmt = db()->prepare('SELECT * FROM homework WHERE class_id = ? ORDER BY created_at DESC');
$stmt->execute([$classId]);
$out = [];
foreach ($stmt->fetchAll() as $h) {
    $item = [
        'id' => (int)$h['id'],
        'title' => $h['title'],
        'description' => $h['description'],
        'due_date' => $h['due_date'],
        'created_at' => $h['created_at'],
    ];
    if ($user['role'] === 'student') {
        // Only the student's own submission (privacy).
        $s = db()->prepare('SELECT id, submitted_at, grade FROM submissions WHERE homework_id = ? AND student_id = ?');
        $s->execute([$h['id'], $user['id']]);
        $sub = $s->fetch();
        $item['my_submission'] = $sub ? [
            'id' => (int)$sub['id'],
            'submitted_at' => $sub['submitted_at'],
            'grade' => $sub['grade'],
        ] : null;
    } else {
        $c = db()->prepare('SELECT COUNT(*) FROM submissions WHERE homework_id = ?');
        $c->execute([$h['id']]);
        $item['submission_count'] = (int)$c->fetchColumn();
    }
    $out[] = $item;
}
send(['homework' => $out]);
