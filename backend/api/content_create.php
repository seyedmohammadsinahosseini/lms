<?php
// Create content in a lesson. Accepts JSON (video url / note+booklet body) or
// multipart form-data with a `file` field (attaches file_path).
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$lessonId = (int)($b['lesson_id'] ?? 0);
$type = $b['type'] ?? '';
$title = trim($b['title'] ?? '');
$bodyText = $b['body'] ?? null;
$url = trim($b['url'] ?? '');

// Verify teacher owns the lesson's class.
$stmt = db()->prepare('SELECT class_id FROM lessons WHERE id = ?');
$stmt->execute([$lessonId]);
$lesson = $stmt->fetch();
if (!$lesson) fail('Lesson not found', 404);
owned_class_or_fail((int)$lesson['class_id'], (int)$user['id']);

if (!in_array($type, ['video', 'note', 'booklet'], true)) fail('Invalid content type.');
if ($title === '') fail('Title is required.');

$filePath = save_upload('file');
if ($type === 'video' && $url === '' && !$filePath) fail('Provide a video URL or file.');
if (($type === 'note' || $type === 'booklet') && ($bodyText === null || trim($bodyText) === '')) {
    fail('Content body is required.');
}

$stmt = db()->prepare('INSERT INTO contents (lesson_id, type, title, body, url, file_path) VALUES (?,?,?,?,?,?)');
$stmt->execute([$lessonId, $type, $title, $bodyText, $url ?: null, $filePath]);
send(['id' => (int)db()->lastInsertId()], 201);
