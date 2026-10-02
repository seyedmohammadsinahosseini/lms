<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$classId = (int)input_int($b, 'class_id', 1);
$title = input_string($b, 'title', 160, true, 1);
$description = input_string($b, 'description', 10000, false);
$dueAt = null;
if (!empty($b['due_at'])) {
    $dueAt = input_datetime($b, 'due_at');
} elseif (!empty($b['due_date']) && is_string($b['due_date'])) {
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $b['due_date'], new DateTimeZone('UTC'));
    $errors = DateTimeImmutable::getLastErrors();
    if (!$date || ($errors !== false && ($errors['warning_count'] || $errors['error_count'])) || $date->format('Y-m-d') !== $b['due_date']) {
        fail('due_date is invalid.', 422, 'VALIDATION_ERROR', ['due_date' => 'Use YYYY-MM-DD']);
    }
    $dueAt = $date->setTime(23, 59, 59)->format('Y-m-d H:i:s');
}
$allowLate = input_bool($b, 'allow_late_submission', false);
$allowResubmit = input_bool($b, 'allow_resubmit', true);
$resubmitUntil = input_datetime($b, 'resubmit_until');
if ($resubmitUntil && $dueAt && strtotime($resubmitUntil . ' UTC') < strtotime($dueAt . ' UTC')) {
    fail('resubmit_until cannot be before due_at.', 422, 'VALIDATION_ERROR');
}
owned_class_or_fail($classId, (int)$user['id']);
$stmt = db()->prepare(
    'INSERT INTO homework
     (class_id, title, description, due_at, allow_late_submission, allow_resubmit, resubmit_until)
     VALUES (?,?,?,?,?,?,?)'
);
$stmt->execute([$classId, $title, $description, $dueAt, $allowLate ? 1 : 0, $allowResubmit ? 1 : 0, $resubmitUntil]);
$id = (int)db()->lastInsertId();
audit_event((int)$user['id'], 'homework.created', 'homework', $id);
send(['id' => $id], 201);
