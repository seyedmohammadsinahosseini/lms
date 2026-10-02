<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
$submissionId = filter_var($_GET['submission_id'] ?? null, FILTER_VALIDATE_INT);
if (!$submissionId) fail('submission_id is required.', 422, 'VALIDATION_ERROR');

$stmt = db()->prepare(
    'SELECT s.id, s.student_id, h.class_id
     FROM submissions s JOIN homework h ON h.id = s.homework_id
     WHERE s.id = ?'
);
$stmt->execute([(int)$submissionId]);
$submission = $stmt->fetch();
if (!$submission) fail('Submission not found.', 404, 'NOT_FOUND');
if ($user['role'] === 'student') {
    if ((int)$submission['student_id'] !== (int)$user['id']) {
        fail('Forbidden.', 403, 'FORBIDDEN');
    }
} else {
    owned_class_or_fail((int)$submission['class_id'], (int)$user['id']);
}

$stmt = db()->prepare(
    'SELECT version_no, text, file_id, legacy_file_path, submitted_at, is_late
     FROM submission_versions WHERE submission_id = ? ORDER BY version_no DESC'
);
$stmt->execute([(int)$submissionId]);
$versions = array_map(static fn(array $version): array => [
    'version_no' => (int)$version['version_no'],
    'text' => $version['text'],
    'file_path' => file_download_path(
        $version['file_id'] === null ? null : (int)$version['file_id'],
        $version['legacy_file_path'],
        (int)$user['id']
    ),
    'submitted_at' => iso_utc($version['submitted_at']),
    'is_late' => (bool)$version['is_late'],
], $stmt->fetchAll());

send(['versions' => $versions]);
