<?php
require_once __DIR__ . '/../helpers.php';
$user = require_auth();
require_role($user, 'teacher');
require_method('POST');

$b = body();
$contentId = (int)($b['content_id'] ?? 0);

$stmt = db()->prepare('
    SELECT l.class_id FROM content c
    JOIN lessons l ON l.id = c.lesson_id
    WHERE c.id = ?
');
$stmt->execute([$contentId]);
$c = $stmt->fetch();
if (!$c) fail('Content not found', 404);
owned_class_or_fail((int)$c['class_id'], (int)$user['id']);

db()->prepare('DELETE FROM content WHERE id = ?')->execute([$contentId]);
send(['success' => true]);