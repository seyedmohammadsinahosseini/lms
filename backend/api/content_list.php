<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
$lessonId = (int)($_GET['lesson_id'] ?? 0);
lesson_access_or_fail($lessonId, $user);

$stmt = db()->prepare('SELECT * FROM contents WHERE lesson_id = ? ORDER BY id');
$stmt->execute([$lessonId]);
$items = array_map(fn($c) => [
    'id' => (int)$c['id'],
    'type' => $c['type'],
    'title' => $c['title'],
    'body' => $c['body'],
    'url' => $c['url'],
    'file_path' => $c['file_path'],
], $stmt->fetchAll());
send(['contents' => $items]);
