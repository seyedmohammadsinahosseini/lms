<?php
// Student enters a teacher code -> returns the teacher and their classes,
// each flagged with whether this student is already enrolled.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'student');
require_method('POST');

$code = strtoupper(trim(body()['code'] ?? ''));
if ($code === '') fail('Enter a teacher code.');

$stmt = db()->prepare(
    'SELECT tc.teacher_id, u.full_name FROM teacher_codes tc
     JOIN users u ON u.id = tc.teacher_id
     WHERE tc.code = ? AND tc.active = 1'
);
$stmt->execute([$code]);
$teacher = $stmt->fetch();
if (!$teacher) fail('No teacher found for that code.', 404);

$stmt = db()->prepare(
    'SELECT c.id, c.name, c.description, c.color,
            EXISTS(SELECT 1 FROM enrollments e WHERE e.class_id = c.id AND e.student_id = ?) AS enrolled
     FROM classes c WHERE c.teacher_id = ? ORDER BY c.name'
);
$stmt->execute([$user['id'], $teacher['teacher_id']]);
$classes = array_map(function ($c) {
    return [
        'id' => (int)$c['id'],
        'name' => $c['name'],
        'description' => $c['description'],
        'color' => $c['color'],
        'enrolled' => (bool)$c['enrolled'],
    ];
}, $stmt->fetchAll());

send([
    'teacher' => ['id' => (int)$teacher['teacher_id'], 'full_name' => $teacher['full_name']],
    'classes' => $classes,
]);
