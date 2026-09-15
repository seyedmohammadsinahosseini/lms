<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'student');
require_method('POST');

$classId = (int)(body()['class_id'] ?? 0);
if (!$classId) fail('class_id is required.');

$stmt = db()->prepare('SELECT 1 FROM classes WHERE id = ?');
$stmt->execute([$classId]);
if (!$stmt->fetch()) fail('Class not found.', 404);

db()->prepare('INSERT IGNORE INTO enrollments (class_id, student_id) VALUES (?,?)')
    ->execute([$classId, $user['id']]);
send(['ok' => true]);
