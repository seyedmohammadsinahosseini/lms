<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
[$page, $perPage, $offset] = pagination(50, 100);

if ($user['role'] === 'teacher') {
    $count = db()->prepare('SELECT COUNT(*) FROM classes WHERE teacher_id = ?');
    $count->execute([$user['id']]);
    $stmt = db()->prepare(
        'SELECT c.*, COUNT(e.id) AS student_count
         FROM classes c LEFT JOIN enrollments e ON e.class_id = c.id
         WHERE c.teacher_id = ? GROUP BY c.id
         ORDER BY c.created_at DESC LIMIT ? OFFSET ?'
    );
    $stmt->bindValue(1, (int)$user['id'], PDO::PARAM_INT);
} else {
    $count = db()->prepare('SELECT COUNT(*) FROM enrollments WHERE student_id = ?');
    $count->execute([$user['id']]);
    $stmt = db()->prepare(
        'SELECT c.*, u.full_name AS teacher_name
         FROM enrollments e JOIN classes c ON c.id = e.class_id
         JOIN users u ON u.id = c.teacher_id
         WHERE e.student_id = ? ORDER BY c.name LIMIT ? OFFSET ?'
    );
    $stmt->bindValue(1, (int)$user['id'], PDO::PARAM_INT);
}
$stmt->bindValue(2, $perPage, PDO::PARAM_INT);
$stmt->bindValue(3, $offset, PDO::PARAM_INT);
$stmt->execute();
$rows = array_map(static function (array $class): array {
    $item = [
        'id' => (int)$class['id'],
        'name' => $class['name'],
        'description' => $class['description'],
        'color' => $class['color'],
    ];
    if (array_key_exists('student_count', $class)) $item['student_count'] = (int)$class['student_count'];
    if (array_key_exists('teacher_name', $class)) $item['teacher_name'] = $class['teacher_name'];
    return $item;
}, $stmt->fetchAll());
$total = (int)$count->fetchColumn();
send(['classes' => $rows, 'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total]]);
