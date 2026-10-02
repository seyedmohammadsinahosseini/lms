<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'student');
$b = body();
$classId = (int)input_int($b, 'class_id', 1);
$grant = input_string($b, 'join_grant', 128, true, 32);
enforce_rate_limit('enroll', $user['id'] . '|' . client_ip(), 20, 3600, 3600);

$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare(
        'SELECT jg.*, c.teacher_id AS class_teacher_id
         FROM join_grants jg JOIN classes c ON c.id = ?
         WHERE jg.token_hash = ? AND jg.student_id = ?
           AND jg.expires_at > UTC_TIMESTAMP() AND jg.used_at IS NULL
         FOR UPDATE'
    );
    $stmt->execute([$classId, token_hash((string)$grant), $user['id']]);
    $row = $stmt->fetch();
    if (!$row || (int)$row['teacher_id'] !== (int)$row['class_teacher_id']) {
        fail('A valid, unexpired join grant is required.', 403, 'INVALID_JOIN_GRANT');
    }

    $pdo->prepare(
        'INSERT INTO enrollments (class_id, student_id) VALUES (?,?)
         ON DUPLICATE KEY UPDATE joined_at = joined_at'
    )->execute([$classId, $user['id']]);
    $pdo->prepare('UPDATE join_grants SET used_at = UTC_TIMESTAMP() WHERE id = ?')
        ->execute([$row['id']]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'class.enrolled', 'class', $classId);
send(['success' => true]);
