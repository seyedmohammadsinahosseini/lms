<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');

$b = body();
$email = strtolower(trim((string)($b['email'] ?? '')));
$password = (string)($b['password'] ?? '');
if ($email === '' || $password === '') {
    fail('Email and password are required.', 422, 'VALIDATION_ERROR');
}

$subject = $email . '|' . client_ip();
enforce_rate_limit('login', $subject, 10, 900, 900);
$stmt = db()->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch();
if (!$user || !password_verify($password, (string)$user['password_hash'])) {
    // A constant response avoids revealing whether the address exists.
    usleep(random_int(100000, 250000));
    fail('Invalid email or password.', 401, 'INVALID_CREDENTIALS');
}

clear_rate_limit('login', $subject);
$session = issue_session((int)$user['id'], (string)($_SERVER['HTTP_USER_AGENT'] ?? ''));
audit_event((int)$user['id'], 'auth.login', 'user', (int)$user['id']);
send([...$session, 'user' => public_user($user)]);
