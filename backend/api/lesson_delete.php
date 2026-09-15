<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$lessonId = (int)($b['lesson_id'] ?? 0);

$stmt = db()->prepare('SELECT class_id FROM lessons WHERE id = ?');
$stmt->execute([$lessonId]);
$lesson = $stmt->fetch();
if (!$lesson) fail('Lesson not found', 404);
owned_class_or_fail((int)$lesson['class_id'], (int)$user['id']);

db()->prepare('DELETE FROM lessons WHERE id = ?')->execute([$lessonId]);
send(['success' => true]);