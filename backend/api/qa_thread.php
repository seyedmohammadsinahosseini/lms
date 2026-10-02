<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
$id = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
if (!$id) fail('id is required.', 422, 'VALIDATION_ERROR');
$stmt = db()->prepare(
    'SELECT t.*, u.full_name AS author_name FROM qa_threads t
     JOIN users u ON u.id = t.student_id WHERE t.id = ?'
);
$stmt->execute([$id]);
$thread = $stmt->fetch();
if (!$thread) fail('Thread not found.', 404, 'NOT_FOUND');
class_access_or_fail((int)$thread['class_id'], $user);
$stmt = db()->prepare(
    'SELECT r.id, r.body, r.created_at, u.full_name AS author_name, u.role AS author_role
     FROM qa_replies r JOIN users u ON u.id = r.author_id
     WHERE r.thread_id = ? ORDER BY r.created_at, r.id'
);
$stmt->execute([$id]);
$replies = array_map(static fn(array $r): array => [
    'id' => (int)$r['id'], 'body' => $r['body'], 'author_name' => $r['author_name'],
    'author_role' => $r['author_role'], 'created_at' => iso_utc($r['created_at']),
], $stmt->fetchAll());
send(['thread' => [
    'id' => (int)$thread['id'], 'title' => $thread['title'], 'body' => $thread['body'],
    'author_name' => $thread['author_name'], 'reply_count' => count($replies),
    'created_at' => iso_utc($thread['created_at']),
], 'replies' => $replies]);
