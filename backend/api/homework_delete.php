<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$homeworkId = (int)input_int($b, 'homework_id', 1);
$homework = homework_access_or_fail($homeworkId, $user);
owned_class_or_fail((int)$homework['class_id'], (int)$user['id']);
$stmt = db()->prepare(
    'SELECT DISTINCT sv.file_id FROM submission_versions sv
     JOIN submissions s ON s.id = sv.submission_id
     WHERE s.homework_id = ? AND sv.file_id IS NOT NULL'
);
$stmt->execute([$homeworkId]);
$fileIds = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
db()->prepare('DELETE FROM homework WHERE id = ?')->execute([$homeworkId]);
foreach ($fileIds as $fileId) delete_stored_file_if_unreferenced($fileId);
audit_event((int)$user['id'], 'homework.deleted', 'homework', $homeworkId);
send(['success' => true]);
