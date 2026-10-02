<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'student');
$b = body();
$homeworkId = (int)input_int($b, 'homework_id', 1);
$textWasProvided = array_key_exists('text', $b);
$text = $textWasProvided ? input_string($b, 'text', 100000, false) : null;
$homework = homework_access_or_fail($homeworkId, $user);
enrolled_or_fail((int)$homework['class_id'], (int)$user['id']);
$now = time();
$isLate = $homework['due_at'] && strtotime($homework['due_at'] . ' UTC') < $now;
if ($isLate && !(bool)$homework['allow_late_submission']) {
    fail('The homework deadline has passed.', 409, 'HOMEWORK_CLOSED');
}

$pdo = db();
$file = null;
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare(
        'SELECT s.*, sv.text AS previous_text, sv.file_id AS previous_file_id,
                sv.legacy_file_path AS previous_legacy_file_path
         FROM submissions s
         LEFT JOIN submission_versions sv ON sv.submission_id = s.id AND sv.version_no = s.latest_version_no
         WHERE s.homework_id = ? AND s.student_id = ? FOR UPDATE'
    );
    $stmt->execute([$homeworkId, $user['id']]);
    $submission = $stmt->fetch();
    if ($submission) {
        if (!(bool)$homework['allow_resubmit']) fail('Resubmission is not allowed.', 409, 'RESUBMIT_DISABLED');
        if ($homework['resubmit_until'] && strtotime($homework['resubmit_until'] . ' UTC') < $now) {
            fail('The resubmission window has closed.', 409, 'RESUBMIT_CLOSED');
        }
        $versionNo = (int)$submission['latest_version_no'] + 1;
        $submissionId = (int)$submission['id'];
        $finalText = $textWasProvided && $text !== null ? $text : $submission['previous_text'];
        $previousFileId = $submission['previous_file_id'];
        $legacyPath = $submission['previous_legacy_file_path'];
    } else {
        $versionNo = 1;
        $finalText = $text;
        $previousFileId = null;
        $legacyPath = null;
        $submissionId = 0;
    }

    $newFileExpected = isset($_FILES['file'])
        && (int)($_FILES['file']['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_NO_FILE;
    if (($finalText === null || trim((string)$finalText) === '')
        && $previousFileId === null && $legacyPath === null && !$newFileExpected) {
        fail('Provide text or a file.', 422, 'VALIDATION_ERROR');
    }

    // Upload only after all policy checks. The stored_files row participates in
    // this transaction; physical cleanup is handled in the catch block.
    $file = save_upload('file', (int)$user['id']);
    $finalFileId = $file['id'] ?? $previousFileId;
    if ($file !== null) $legacyPath = null;

    if (!$submission) {
        $pdo->prepare(
            'INSERT INTO submissions (homework_id, student_id, latest_version_no, status)
             VALUES (?,?,1,?)'
        )->execute([$homeworkId, $user['id'], $isLate ? 'late' : 'pending_grading']);
        $submissionId = (int)$pdo->lastInsertId();
    }
    $pdo->prepare(
        'INSERT INTO submission_versions
         (submission_id, version_no, text, file_id, legacy_file_path, submitted_at, is_late)
         VALUES (?,?,?,?,?,UTC_TIMESTAMP(),?)'
    )->execute([$submissionId, $versionNo, $finalText, $finalFileId, $legacyPath, $isLate ? 1 : 0]);
    $pdo->prepare(
        'UPDATE submissions SET latest_version_no = ?, status = ?, grade = NULL,
         feedback = NULL, graded_at = NULL WHERE id = ?'
    )->execute([$versionNo, $isLate ? 'late' : 'pending_grading', $submissionId]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    discard_saved_upload($file);
    throw $e;
}
audit_event((int)$user['id'], 'submission.submitted', 'submission', $submissionId, ['version' => $versionNo, 'late' => $isLate]);
send(['id' => $submissionId, 'version_no' => $versionNo, 'is_late' => $isLate], 201);
