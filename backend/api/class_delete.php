<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$classId = (int)input_int($b, 'class_id', 1);
owned_class_or_fail($classId, (int)$user['id']);

$stmt = db()->prepare(
    'SELECT DISTINCT file_id FROM (
       SELECT c.file_id FROM contents c JOIN lessons l ON l.id = c.lesson_id WHERE l.class_id = ?
       UNION ALL
       SELECT sv.file_id FROM submission_versions sv
       JOIN submissions s ON s.id = sv.submission_id
       JOIN homework h ON h.id = s.homework_id WHERE h.class_id = ?
     ) f WHERE file_id IS NOT NULL'
);
$stmt->execute([$classId, $classId]);
$fileIds = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));

db()->prepare('DELETE FROM classes WHERE id = ?')->execute([$classId]);
foreach ($fileIds as $fileId) delete_stored_file_if_unreferenced($fileId);
audit_event((int)$user['id'], 'class.deleted', 'class', $classId);
send(['success' => true]);
