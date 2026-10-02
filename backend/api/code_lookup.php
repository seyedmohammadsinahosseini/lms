<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'student');
$b = body();
$code = strtoupper((string)input_string($b, 'code', 16, true, 6));
enforce_rate_limit('code_lookup', $user['id'] . '|' . client_ip(), 12, 900, 1800);

$stmt = db()->prepare(
    'SELECT tc.teacher_id, u.full_name
     FROM teacher_codes tc JOIN users u ON u.id = tc.teacher_id
     WHERE tc.code = ? AND tc.active = 1'
);
$stmt->execute([$code]);
$teacher = $stmt->fetch();
if (!$teacher) fail('The teacher code is invalid.', 404, 'CODE_NOT_FOUND');

$stmt = db()->prepare(
    'SELECT c.id, c.name, c.description, c.color,
            CASE WHEN e.id IS NULL THEN 0 ELSE 1 END AS enrolled
     FROM classes c
     LEFT JOIN enrollments e ON e.class_id = c.id AND e.student_id = ?
     WHERE c.teacher_id = ? ORDER BY c.created_at DESC'
);
$stmt->execute([$user['id'], $teacher['teacher_id']]);
$classes = array_map(static fn(array $class): array => [
    'id' => (int)$class['id'],
    'name' => $class['name'],
    'description' => $class['description'],
    'color' => $class['color'],
    'enrolled' => (bool)$class['enrolled'],
], $stmt->fetchAll());

db()->prepare('DELETE FROM join_grants WHERE expires_at <= UTC_TIMESTAMP() OR used_at IS NOT NULL')
    ->execute();
$grant = create_join_grant((int)$user['id'], (int)$teacher['teacher_id']);
send([
    'teacher' => ['id' => (int)$teacher['teacher_id'], 'full_name' => $teacher['full_name']],
    'classes' => $classes,
    'join_grant' => $grant,
    'join_grant_expires_in' => 600,
]);
