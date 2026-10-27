<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$fileId = filter_var($_GET['id'] ?? null, FILTER_VALIDATE_INT);
if (!$fileId) fail('id is required.', 422, 'VALIDATION_ERROR');
$user = signed_download_user((int)$fileId) ?? require_auth();

$stmt = db()->prepare('SELECT * FROM stored_files WHERE id = ?');
$stmt->execute([$fileId]);
$file = $stmt->fetch();
if (!$file) fail('File not found.', 404, 'NOT_FOUND');

$allowed = (int)$file['owner_user_id'] === (int)$user['id'];
if (!$allowed && $user['role'] === 'teacher') {
    $stmt = db()->prepare(
        'SELECT 1 FROM contents c
           JOIN lessons l ON l.id = c.lesson_id
           JOIN classes cl ON cl.id = l.class_id
         WHERE c.file_id = ? AND cl.teacher_id = ?
         UNION ALL
         SELECT 1 FROM submission_versions sv
           JOIN submissions s ON s.id = sv.submission_id
           JOIN homework h ON h.id = s.homework_id
           JOIN classes cl ON cl.id = h.class_id
         WHERE sv.file_id = ? AND cl.teacher_id = ? LIMIT 1'
    );
    $stmt->execute([$fileId, $user['id'], $fileId, $user['id']]);
    $allowed = (bool)$stmt->fetchColumn();
} elseif (!$allowed && $user['role'] === 'student') {
    $stmt = db()->prepare(
        'SELECT 1 FROM contents c
           JOIN lessons l ON l.id = c.lesson_id
           JOIN enrollments e ON e.class_id = l.class_id
         WHERE c.file_id = ? AND e.student_id = ? LIMIT 1'
    );
    $stmt->execute([$fileId, $user['id']]);
    $allowed = (bool)$stmt->fetchColumn();
}
if (!$allowed) fail('Forbidden.', 403, 'FORBIDDEN');

$path = lms_storage_path() . DIRECTORY_SEPARATOR . $file['storage_name'];
if (!is_file($path) || !is_readable($path)) fail('File is unavailable.', 404, 'FILE_MISSING');

header_remove('Content-Type');
header_remove('Content-Security-Policy');
header('Content-Type: ' . $file['mime_type']);
header('Content-Length: ' . filesize($path));
header("Content-Disposition: inline; filename=\"download\"; filename*=UTF-8''" . rawurlencode($file['original_name']));
header('Cache-Control: private, no-store');
header('Accept-Ranges: bytes');
readfile($path);
exit;
