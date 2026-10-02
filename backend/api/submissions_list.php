<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
$homeworkId = filter_var($_GET['homework_id'] ?? null, FILTER_VALIDATE_INT);
if (!$homeworkId) fail('homework_id is required.', 422, 'VALIDATION_ERROR');
$homework = homework_access_or_fail((int)$homeworkId, $user);
[$page, $perPage, $offset] = pagination(30, 100);

if ($user['role'] === 'teacher') {
    owned_class_or_fail((int)$homework['class_id'], (int)$user['id']);
    $count = db()->prepare('SELECT COUNT(*) FROM submissions WHERE homework_id = ?');
    $count->execute([$homeworkId]);
    $stmt = db()->prepare(
        'SELECT s.*, u.full_name, sv.text, sv.file_id, sv.legacy_file_path,
                sv.submitted_at, sv.is_late
         FROM submissions s JOIN users u ON u.id = s.student_id
         JOIN submission_versions sv ON sv.submission_id = s.id AND sv.version_no = s.latest_version_no
         WHERE s.homework_id = ? ORDER BY sv.submitted_at DESC LIMIT ? OFFSET ?'
    );
    $stmt->bindValue(1, (int)$homeworkId, PDO::PARAM_INT);
    $stmt->bindValue(2, $perPage, PDO::PARAM_INT);
    $stmt->bindValue(3, $offset, PDO::PARAM_INT);
} else {
    $count = null;
    $stmt = db()->prepare(
        'SELECT s.*, u.full_name, sv.text, sv.file_id, sv.legacy_file_path,
                sv.submitted_at, sv.is_late
         FROM submissions s JOIN users u ON u.id = s.student_id
         JOIN submission_versions sv ON sv.submission_id = s.id AND sv.version_no = s.latest_version_no
         WHERE s.homework_id = ? AND s.student_id = ?'
    );
    $stmt->bindValue(1, (int)$homeworkId, PDO::PARAM_INT);
    $stmt->bindValue(2, (int)$user['id'], PDO::PARAM_INT);
}
$stmt->execute();
$submissions = array_map(static fn(array $s): array => [
    'id' => (int)$s['id'], 'student_id' => (int)$s['student_id'],
    'student_name' => $s['full_name'], 'version_no' => (int)$s['latest_version_no'],
    'status' => $s['status'], 'text' => $s['text'],
    'file_path' => file_download_path($s['file_id'] === null ? null : (int)$s['file_id'], $s['legacy_file_path'], (int)$user['id']),
    'submitted_at' => iso_utc($s['submitted_at']), 'is_late' => (bool)$s['is_late'],
    'grade' => $s['grade'], 'feedback' => $s['feedback'], 'graded_at' => iso_utc($s['graded_at']),
], $stmt->fetchAll());
$response = ['submissions' => $submissions];
if ($count) $response['pagination'] = ['page' => $page, 'per_page' => $perPage, 'total' => (int)$count->fetchColumn()];
send($response);
