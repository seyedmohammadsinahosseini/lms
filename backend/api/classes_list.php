<?php
// Teacher: classes they own. Student: classes they are enrolled in (with teacher name).
require_once __DIR__ . '/../helpers.php';
$user = require_auth();

if ($user['role'] === 'teacher') {
    $stmt = db()->prepare(
        'SELECT c.*, (SELECT COUNT(*) FROM enrollments e WHERE e.class_id = c.id) AS student_count
         FROM classes c WHERE c.teacher_id = ? ORDER BY c.created_at DESC'
    );
    $stmt->execute([$user['id']]);
} else {
    $stmt = db()->prepare(
        'SELECT c.*, u.full_name AS teacher_name
         FROM enrollments e
         JOIN classes c ON c.id = e.class_id
         JOIN users u ON u.id = c.teacher_id
         WHERE e.student_id = ? ORDER BY c.name'
    );
    $stmt->execute([$user['id']]);
}

$rows = array_map(function ($c) {
    $out = [
        'id' => (int)$c['id'],
        'name' => $c['name'],
        'description' => $c['description'],
        'color' => $c['color'],
    ];
    if (isset($c['student_count'])) $out['student_count'] = (int)$c['student_count'];
    if (isset($c['teacher_name'])) $out['teacher_name'] = $c['teacher_name'];
    return $out;
}, $stmt->fetchAll());

send(['classes' => $rows]);
