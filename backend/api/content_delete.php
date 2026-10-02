<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$contentId = (int)input_int($b, 'content_id', 1);
$stmt = db()->prepare(
    'SELECT c.file_id, l.class_id FROM contents c
     JOIN lessons l ON l.id = c.lesson_id WHERE c.id = ?'
);
$stmt->execute([$contentId]);
$content = $stmt->fetch();
if (!$content) fail('Content not found.', 404, 'NOT_FOUND');
owned_class_or_fail((int)$content['class_id'], (int)$user['id']);
db()->prepare('DELETE FROM contents WHERE id = ?')->execute([$contentId]);
delete_stored_file_if_unreferenced($content['file_id'] === null ? null : (int)$content['file_id']);
audit_event((int)$user['id'], 'content.deleted', 'content', $contentId);
send(['success' => true]);
