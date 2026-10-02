<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'student');
$b = body();
$classId = (int)input_int($b, 'class_id', 1);
$title = input_string($b, 'title', 200, true, 2);
$text = input_string($b, 'body', 20000, true, 1);
enrolled_or_fail($classId, (int)$user['id']);
enforce_rate_limit('qa_create', (string)$user['id'], 20, 3600, 3600);
db()->prepare('INSERT INTO qa_threads (class_id, student_id, title, body) VALUES (?,?,?,?)')
    ->execute([$classId, $user['id'], $title, $text]);
$id = (int)db()->lastInsertId();
audit_event((int)$user['id'], 'qa.thread_created', 'qa_thread', $id);
send(['id' => $id], 201);
