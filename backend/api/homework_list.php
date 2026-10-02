<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
$user = require_auth();
$classId = filter_var($_GET['class_id'] ?? null, FILTER_VALIDATE_INT);
if (!$classId) fail('class_id is required.', 422, 'VALIDATION_ERROR');
class_access_or_fail((int)$classId, $user);
[$page, $perPage, $offset] = pagination(30, 100);
$count = db()->prepare('SELECT COUNT(*) FROM homework WHERE class_id = ?');
$count->execute([$classId]);

if ($user['role'] === 'teacher') {
    $stmt = db()->prepare(
        'SELECT h.*, COUNT(s.id) AS submission_count,
                SUM(s.status IN (\'pending_grading\',\'late\')) AS pending_count
         FROM homework h LEFT JOIN submissions s ON s.homework_id = h.id
         WHERE h.class_id = ? GROUP BY h.id
         ORDER BY h.due_at IS NULL, h.due_at DESC, h.created_at DESC LIMIT ? OFFSET ?'
    );
    $stmt->bindValue(1, (int)$classId, PDO::PARAM_INT);
} else {
    $stmt = db()->prepare(
        'SELECT h.*, s.id AS submission_id, s.status AS submission_status,
                s.grade, s.feedback, s.graded_at, s.latest_version_no,
                sv.text AS submission_text, sv.file_id, sv.legacy_file_path,
                sv.submitted_at, sv.is_late
         FROM homework h
         LEFT JOIN submissions s ON s.homework_id = h.id AND s.student_id = ?
         LEFT JOIN submission_versions sv ON sv.submission_id = s.id AND sv.version_no = s.latest_version_no
         WHERE h.class_id = ?
         ORDER BY h.due_at IS NULL, h.due_at DESC, h.created_at DESC LIMIT ? OFFSET ?'
    );
    $stmt->bindValue(1, (int)$user['id'], PDO::PARAM_INT);
    $stmt->bindValue(2, (int)$classId, PDO::PARAM_INT);
}
$limitIndex = $user['role'] === 'teacher' ? 2 : 3;
$stmt->bindValue($limitIndex, $perPage, PDO::PARAM_INT);
$stmt->bindValue($limitIndex + 1, $offset, PDO::PARAM_INT);
$stmt->execute();
$out = [];
foreach ($stmt->fetchAll() as $homework) {
    $item = [
        'id' => (int)$homework['id'], 'title' => $homework['title'],
        'description' => $homework['description'],
        'due_date' => $homework['due_at'] ? substr($homework['due_at'], 0, 10) : null,
        'due_at' => iso_utc($homework['due_at']),
        'allow_late_submission' => (bool)$homework['allow_late_submission'],
        'allow_resubmit' => (bool)$homework['allow_resubmit'],
        'resubmit_until' => iso_utc($homework['resubmit_until']),
    ];
    if ($user['role'] === 'teacher') {
        $item['submission_count'] = (int)$homework['submission_count'];
        $item['pending_count'] = (int)$homework['pending_count'];
    } else {
        $item['my_submission'] = $homework['submission_id'] === null ? null : [
            'id' => (int)$homework['submission_id'], 'status' => $homework['submission_status'],
            'version_no' => (int)$homework['latest_version_no'],
            'text' => $homework['submission_text'],
            'file_path' => file_download_path($homework['file_id'] === null ? null : (int)$homework['file_id'], $homework['legacy_file_path'], (int)$user['id']),
            'submitted_at' => iso_utc($homework['submitted_at']),
            'is_late' => (bool)$homework['is_late'], 'grade' => $homework['grade'],
            'feedback' => $homework['feedback'], 'graded_at' => iso_utc($homework['graded_at']),
        ];
    }
    $out[] = $item;
}
send(['homework' => $out, 'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => (int)$count->fetchColumn()]]);
