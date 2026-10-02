<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$lessonId = (int)input_int($b, 'lesson_id', 1);
[$lesson, $class] = lesson_access_or_fail($lessonId, $user);
owned_class_or_fail((int)$class['id'], (int)$user['id']);
$stmt = db()->prepare('SELECT file_id FROM contents WHERE lesson_id = ? AND file_id IS NOT NULL');
$stmt->execute([$lessonId]);
$fileIds = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
db()->prepare('DELETE FROM lessons WHERE id = ?')->execute([$lessonId]);
foreach ($fileIds as $fileId) delete_stored_file_if_unreferenced($fileId);
audit_event((int)$user['id'], 'lesson.deleted', 'lesson', $lessonId);
send(['success' => true]);
