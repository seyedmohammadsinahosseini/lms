<?php
// Post a reply to a thread (teacher or enrolled student). Body: thread_id, body.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_method('POST');

$b = body();
$threadId = (int)($b['thread_id'] ?? 0);
$bodyText = trim($b['body'] ?? '');
if ($bodyText === '') fail('Reply cannot be empty.');

$stmt = db()->prepare('SELECT class_id FROM qa_threads WHERE id = ?');
$stmt->execute([$threadId]);
$t = $stmt->fetch();
if (!$t) fail('Thread not found', 404);
class_access_or_fail((int)$t['class_id'], $user);

$stmt = db()->prepare('INSERT INTO qa_replies (thread_id, author_id, body) VALUES (?,?,?)');
$stmt->execute([$threadId, $user['id'], $bodyText]);
send(['id' => (int)db()->lastInsertId()], 201);
