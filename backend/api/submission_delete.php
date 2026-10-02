<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
$b = body();
$submissionId = (int)input_int($b, 'submission_id', 1);
$stmt = db()->prepare(
    'SELECT s.*, h.class_id FROM submissions s JOIN homework h ON h.id = s.homework_id WHERE s.id = ?'
);
$stmt->execute([$submissionId]);
$submission = $stmt->fetch();
if (!$submission) fail('Submission not found.', 404, 'NOT_FOUND');
if ($user['role'] === 'student') {
    if ((int)$submission['student_id'] !== (int)$user['id']) fail('Forbidden.', 403, 'FORBIDDEN');
} else {
    owned_class_or_fail((int)$submission['class_id'], (int)$user['id']);
}
$stmt = db()->prepare('SELECT file_id FROM submission_versions WHERE submission_id = ? AND file_id IS NOT NULL');
$stmt->execute([$submissionId]);
$fileIds = array_unique(array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN)));
db()->prepare('DELETE FROM submissions WHERE id = ?')->execute([$submissionId]);
foreach ($fileIds as $fileId) delete_stored_file_if_unreferenced($fileId);
audit_event((int)$user['id'], 'submission.deleted', 'submission', $submissionId);
send(['success' => true]);
