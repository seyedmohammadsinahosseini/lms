<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
$b = body();
$current = (string)($b['current_password'] ?? '');
$next = (string)($b['new_password'] ?? '');
if (mb_strlen($next) < 10 || mb_strlen($next) > 200) {
    fail('New password must be at least 10 characters.', 422, 'VALIDATION_ERROR', ['new_password' => 'Minimum 10 characters']);
}

$stmt = db()->prepare('SELECT password_hash FROM users WHERE id = ?');
$stmt->execute([$user['id']]);
$hash = (string)$stmt->fetchColumn();
if (!password_verify($current, $hash)) {
    fail('Current password is incorrect.', 422, 'CURRENT_PASSWORD_INVALID');
}
if (password_verify($next, $hash)) {
    fail('New password must be different.', 422, 'PASSWORD_UNCHANGED');
}

$pdo = db();
$pdo->beginTransaction();
try {
    $pdo->prepare('UPDATE users SET password_hash = ? WHERE id = ?')
        ->execute([password_hash($next, PASSWORD_DEFAULT), $user['id']]);
    $pdo->prepare('DELETE FROM sessions WHERE user_id = ? AND id <> ?')
        ->execute([$user['id'], $user['_session_id']]);
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
audit_event((int)$user['id'], 'profile.password_changed', 'user', (int)$user['id']);
send(['success' => true, 'other_sessions_revoked' => true]);
