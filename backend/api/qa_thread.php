<?php
// Full thread with replies (?id=).
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$id = (int)($_GET['id'] ?? 0);

$stmt = db()->prepare(
    'SELECT t.*, u.full_name AS author_name FROM qa_threads t
     JOIN users u ON u.id = t.student_id WHERE t.id = ?'
);
$stmt->execute([$id]);
$t = $stmt->fetch();
if (!$t) fail('Thread not found', 404);
class_access_or_fail((int)$t['class_id'], $user);

$r = db()->prepare(
    'SELECT r.*, u.full_name AS author_name, u.role AS author_role
     FROM qa_replies r JOIN users u ON u.id = r.author_id
     WHERE r.thread_id = ? ORDER BY r.created_at'
);
$r->execute([$id]);
$replies = array_map(fn($x) => [
    'id' => (int)$x['id'],
    'body' => $x['body'],
    'author_name' => $x['author_name'],
    'author_role' => $x['author_role'],
    'created_at' => $x['created_at'],
], $r->fetchAll());

send([
    'thread' => [
        'id' => (int)$t['id'],
        'class_id' => (int)$t['class_id'],
        'title' => $t['title'],
        'body' => $t['body'],
        'author_name' => $t['author_name'],
        'created_at' => $t['created_at'],
    ],
    'replies' => $replies,
]);
