<?php
// Student posts a new question thread. Body: class_id, title, body.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'student');
require_method('POST');

$b = body();
$classId = (int)($b['class_id'] ?? 0);
$title = trim($b['title'] ?? '');
$bodyText = trim($b['body'] ?? '');
enrolled_or_fail($classId, (int)$user['id']);
if ($title === '') fail('Question title is required.');

$stmt = db()->prepare('INSERT INTO qa_threads (class_id, student_id, title, body) VALUES (?,?,?,?)');
$stmt->execute([$classId, $user['id'], $title, $bodyText]);
send(['id' => (int)db()->lastInsertId()], 201);
