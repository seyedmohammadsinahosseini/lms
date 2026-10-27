<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');

enforce_rate_limit('register', client_ip(), 8, 3600, 3600);
$b = body();
$name = input_string($b, 'full_name', 120, true, 2);
$email = strtolower((string)input_string($b, 'email', 160, true, 3));
$password = (string)($b['password'] ?? '');
$role = input_enum($b, 'role', ['student', 'teacher']);
$inviteCode = isset($b['teacher_invite']) && is_string($b['teacher_invite'])
    ? trim($b['teacher_invite'])
    : null;

if (filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
    fail('Enter a valid email address.', 422, 'VALIDATION_ERROR', ['email' => 'Invalid email']);
}
if (mb_strlen($password) < 10 || mb_strlen($password) > 200) {
    fail('Password must be at least 10 characters.', 422, 'VALIDATION_ERROR', ['password' => 'Minimum 10 characters']);
}

enforce_rate_limit('register_email', $email . '|' . client_ip(), 4, 3600, 3600);

$pdo = db();
$pdo->beginTransaction();
try {
    $invite = null;
    if ($role === 'teacher' && !lms_teacher_registration_enabled()) {
        if ($inviteCode === null || $inviteCode === '') {
            fail('A valid teacher invitation is required.', 403, 'TEACHER_INVITE_REQUIRED');
        }
        $stmt = $pdo->prepare(
            'SELECT * FROM teacher_invites
             WHERE code_hash = ? AND used_at IS NULL AND expires_at > UTC_TIMESTAMP()
             FOR UPDATE'
        );
        $stmt->execute([token_hash($inviteCode)]);
        $invite = $stmt->fetch();
        if (!$invite) fail('The teacher invitation is invalid or expired.', 403, 'INVALID_TEACHER_INVITE');
    }

    $stmt = $pdo->prepare('SELECT 1 FROM users WHERE email = ?');
    $stmt->execute([$email]);
    if ($stmt->fetchColumn()) fail('Email already registered.', 409, 'EMAIL_EXISTS');

    $stmt = $pdo->prepare(
        'INSERT INTO users (full_name, email, password_hash, role) VALUES (?,?,?,?)'
    );
    $stmt->execute([$name, $email, password_hash($password, PASSWORD_DEFAULT), $role]);
    $userId = (int)$pdo->lastInsertId();

    if ($role === 'teacher') {
        $pdo->prepare('INSERT INTO teacher_codes (teacher_id, code) VALUES (?,?)')
            ->execute([$userId, generate_teacher_code()]);
        if ($invite) {
            $pdo->prepare('UPDATE teacher_invites SET used_by = ?, used_at = UTC_TIMESTAMP() WHERE id = ?')
                ->execute([$userId, $invite['id']]);
        }
    }
    $pdo->commit();

    $session = issue_session($userId, (string)($_SERVER['HTTP_USER_AGENT'] ?? ''));
    audit_event($userId, 'auth.register', 'user', $userId, ['role' => $role]);
    send([
        ...$session,
        'user' => ['id' => $userId, 'full_name' => $name, 'email' => $email, 'role' => $role, 'avatar_file_id' => null],
    ], 201);
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
