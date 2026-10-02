<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
$classId = filter_var($_GET['class_id'] ?? null, FILTER_VALIDATE_INT);
if (!$classId) fail('class_id is required.', 422, 'VALIDATION_ERROR');
class_access_or_fail((int)$classId, $user);
[$page, $perPage, $offset] = pagination(30, 100);
$count = db()->prepare('SELECT COUNT(*) FROM qa_threads WHERE class_id = ?');
$count->execute([$classId]);
$stmt = db()->prepare(
    'SELECT t.id, t.title, t.body, t.created_at, u.full_name AS author_name,
            COUNT(r.id) AS reply_count, MAX(r.created_at) AS last_reply_at
     FROM qa_threads t JOIN users u ON u.id = t.student_id
     LEFT JOIN qa_replies r ON r.thread_id = t.id
     WHERE t.class_id = ? GROUP BY t.id
     ORDER BY COALESCE(MAX(r.created_at), t.created_at) DESC LIMIT ? OFFSET ?'
);
$stmt->bindValue(1, (int)$classId, PDO::PARAM_INT);
$stmt->bindValue(2, $perPage, PDO::PARAM_INT);
$stmt->bindValue(3, $offset, PDO::PARAM_INT);
$stmt->execute();
$threads = array_map(static fn(array $r): array => [
    'id' => (int)$r['id'], 'title' => $r['title'], 'body' => $r['body'],
    'author_name' => $r['author_name'], 'reply_count' => (int)$r['reply_count'],
    'created_at' => iso_utc($r['created_at']), 'last_reply_at' => iso_utc($r['last_reply_at']),
], $stmt->fetchAll());
send(['threads' => $threads, 'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => (int)$count->fetchColumn()]]);
