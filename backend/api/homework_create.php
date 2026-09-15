<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$classId = (int)($b['class_id'] ?? 0);
$title = trim($b['title'] ?? '');
$desc = trim($b['description'] ?? '');
$due = trim($b['due_date'] ?? '');
owned_class_or_fail($classId, (int)$user['id']);
if ($title === '') fail('Title is required.');
$dueVal = ($due !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $due)) ? $due : null;

$stmt = db()->prepare('INSERT INTO homework (class_id, title, description, due_date) VALUES (?,?,?,?)');
$stmt->execute([$classId, $title, $desc, $dueVal]);
send(['id' => (int)db()->lastInsertId()], 201);
