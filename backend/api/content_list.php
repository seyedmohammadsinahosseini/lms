<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
$lessonId = filter_var($_GET['lesson_id'] ?? null, FILTER_VALIDATE_INT);
if (!$lessonId) fail('lesson_id is required.', 422, 'VALIDATION_ERROR');
lesson_access_or_fail((int)$lessonId, $user);
$stmt = db()->prepare(
    'SELECT id, type, title, body, url, file_id, legacy_file_path
     FROM contents WHERE lesson_id = ? ORDER BY id'
);
$stmt->execute([$lessonId]);
$contents = array_map(static fn(array $c): array => [
    'id' => (int)$c['id'], 'type' => $c['type'], 'title' => $c['title'],
    'body' => $c['body'], 'url' => $c['url'],
    'file_path' => file_download_path($c['file_id'] === null ? null : (int)$c['file_id'], $c['legacy_file_path'], (int)$user['id']),
], $stmt->fetchAll());
send(['contents' => $contents]);
