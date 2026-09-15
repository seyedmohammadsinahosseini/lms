<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$classId = (int)($b['class_id'] ?? 0);
$title = trim($b['title'] ?? '');
$desc = trim($b['description'] ?? '');
$kind = $b['kind'] ?? 'quiz';
$duration = (int)($b['duration_min'] ?? 0);
owned_class_or_fail($classId, (int)$user['id']);
if ($title === '') fail('Title is required.');
if (!in_array($kind, ['quiz', 'test', 'exam'], true)) $kind = 'quiz';

$stmt = db()->prepare('INSERT INTO assessments (class_id, title, description, kind, duration_min) VALUES (?,?,?,?,?)');
$stmt->execute([$classId, $title, $desc, $kind, $duration]);
send(['id' => (int)db()->lastInsertId()], 201);
