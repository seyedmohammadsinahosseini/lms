<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
require_role($user, 'teacher');
$classId = filter_var($_GET['class_id'] ?? null, FILTER_VALIDATE_INT);
if (!$classId) fail('class_id is required.', 422, 'VALIDATION_ERROR');
owned_class_or_fail((int)$classId, (int)$user['id']);
[$page, $perPage, $offset] = pagination(50, 100);
$count = db()->prepare('SELECT COUNT(*) FROM enrollments WHERE class_id = ?');
$count->execute([$classId]);
$stmt = db()->prepare(
    'SELECT u.id, u.full_name, u.email, e.joined_at
     FROM enrollments e JOIN users u ON u.id = e.student_id
     WHERE e.class_id = ? ORDER BY u.full_name LIMIT ? OFFSET ?'
);
$stmt->bindValue(1, (int)$classId, PDO::PARAM_INT);
$stmt->bindValue(2, $perPage, PDO::PARAM_INT);
$stmt->bindValue(3, $offset, PDO::PARAM_INT);
$stmt->execute();
$students = array_map(static fn(array $r): array => [
    'id' => (int)$r['id'], 'full_name' => $r['full_name'], 'email' => $r['email'],
    'joined_at' => iso_utc($r['joined_at']),
], $stmt->fetchAll());
send(['students' => $students, 'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => (int)$count->fetchColumn()]]);
