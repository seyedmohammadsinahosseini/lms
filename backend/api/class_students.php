<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
$classId = (int)($_GET['class_id'] ?? 0);
owned_class_or_fail($classId, (int)$user['id']);

$stmt = db()->prepare(
    'SELECT u.id, u.full_name, u.email, e.joined_at
     FROM enrollments e JOIN users u ON u.id = e.student_id
     WHERE e.class_id = ? ORDER BY u.full_name'
);
$stmt->execute([$classId]);
$students = array_map(function ($s) {
    return [
        'id' => (int)$s['id'],
        'full_name' => $s['full_name'],
        'email' => $s['email'],
        'joined_at' => $s['joined_at'],
    ];
}, $stmt->fetchAll());
send(['students' => $students]);
