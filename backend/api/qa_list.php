<?php
// List Q&A threads for a class (?class_id=), with reply counts.
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$classId = (int)($_GET['class_id'] ?? 0);
class_access_or_fail($classId, $user);

$stmt = db()->prepare(
    'SELECT t.*, u.full_name AS author_name,
            (SELECT COUNT(*) FROM qa_replies r WHERE r.thread_id = t.id) AS reply_count
     FROM qa_threads t JOIN users u ON u.id = t.student_id
     WHERE t.class_id = ? ORDER BY t.created_at DESC'
);
$stmt->execute([$classId]);
$rows = array_map(fn($t) => [
    'id' => (int)$t['id'],
    'title' => $t['title'],
    'body' => $t['body'],
    'author_name' => $t['author_name'],
    'reply_count' => (int)$t['reply_count'],
    'created_at' => $t['created_at'],
], $stmt->fetchAll());
send(['threads' => $rows]);
