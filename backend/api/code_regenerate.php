<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
enforce_rate_limit('code_regenerate', (string)$user['id'], 5, 3600, 3600);

$pdo = db();
$pdo->beginTransaction();
try {
    // Create the replacement first; a failure cannot leave the teacher without a code.
    $code = generate_teacher_code();
    $pdo->prepare('INSERT INTO teacher_codes (teacher_id, code, active) VALUES (?,?,1)')
        ->execute([$user['id'], $code]);
    $newId = (int)$pdo->lastInsertId();
    $pdo->prepare('UPDATE teacher_codes SET active = 0 WHERE teacher_id = ? AND id <> ?')
        ->execute([$user['id'], $newId]);
    // Grants issued for a previous code are invalidated too.
    $pdo->prepare('DELETE FROM join_grants WHERE teacher_id = ? AND used_at IS NULL')
        ->execute([$user['id']]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'teacher_code.regenerated', 'teacher_code', $newId);
send(['code' => $code]);
