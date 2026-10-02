<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$lessonId = (int)input_int($b, 'lesson_id', 1);
$type = input_enum($b, 'type', ['video', 'note', 'booklet']);
$title = input_string($b, 'title', 160, true, 1);
$bodyText = input_string($b, 'body', 200000, false);
$url = isset($b['url']) && is_string($b['url']) ? valid_https_url($b['url'], true) : null;
[, $class] = lesson_access_or_fail($lessonId, $user);
owned_class_or_fail((int)$class['id'], (int)$user['id']);

$file = save_upload('file', (int)$user['id']);
if ($type === 'video' && $url === null && $file === null) {
    fail('Provide an HTTPS video URL or a video file.', 422, 'VALIDATION_ERROR');
}
if (in_array($type, ['note', 'booklet'], true) && $bodyText === null && $file === null) {
    fail('Provide text or a file.', 422, 'VALIDATION_ERROR');
}

try {
    db()->prepare(
        'INSERT INTO contents (lesson_id, type, title, body, url, file_id)
         VALUES (?,?,?,?,?,?)'
    )->execute([$lessonId, $type, $title, $bodyText, $url, $file['id'] ?? null]);
    $id = (int)db()->lastInsertId();
} catch (Throwable $e) {
    discard_saved_upload($file);
    throw $e;
}
audit_event((int)$user['id'], 'content.created', 'content', $id);
send(['id' => $id], 201);
