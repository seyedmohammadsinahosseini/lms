<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$classId = (int)($b['class_id'] ?? 0);
$title = trim($b['title'] ?? '');
owned_class_or_fail($classId, (int)$user['id']);
if ($title === '') fail('Lesson title is required.');

$pos = (int)db()->query("SELECT COALESCE(MAX(position)+1,0) FROM lessons WHERE class_id = " . $classId)->fetchColumn();
$stmt = db()->prepare('INSERT INTO lessons (class_id, title, position) VALUES (?,?,?)');
$stmt->execute([$classId, $title, $pos]);
send(['id' => (int)db()->lastInsertId(), 'title' => $title, 'position' => $pos], 201);
