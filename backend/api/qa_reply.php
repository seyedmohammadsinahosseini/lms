<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
$b = body();
$threadId = (int)input_int($b, 'thread_id', 1);
$text = input_string($b, 'body', 20000, true, 1);
$stmt = db()->prepare('SELECT class_id FROM qa_threads WHERE id = ?');
$stmt->execute([$threadId]);
$classId = $stmt->fetchColumn();
if (!$classId) fail('Thread not found.', 404, 'NOT_FOUND');
class_access_or_fail((int)$classId, $user);
enforce_rate_limit('qa_reply', (string)$user['id'], 60, 3600, 3600);
db()->prepare('INSERT INTO qa_replies (thread_id, author_id, body) VALUES (?,?,?)')
    ->execute([$threadId, $user['id'], $text]);
$id = (int)db()->lastInsertId();
audit_event((int)$user['id'], 'qa.reply_created', 'qa_reply', $id, ['thread_id' => $threadId]);
send(['id' => $id], 201);
