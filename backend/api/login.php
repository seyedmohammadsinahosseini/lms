<?php
require_once __DIR__ . '/../helpers.php';
require_method('POST');

$b = body();
$email = trim($b['email'] ?? '');
$password = $b['password'] ?? '';
if ($email === '' || $password === '') fail('Email and password are required.');

$ip = client_ip();
if (login_attempts_exceeded($email, $ip)) {
    fail('Too many failed attempts. Please try again in a few minutes.', 429);
}

$stmt = db()->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user || !password_verify($password, $user['password_hash'])) {
    record_login_failure($email, $ip);
    fail('Invalid email or password.', 401);
}

clear_login_failures($email, $ip);

// Housekeeping: drop sessions that have already expired.
db()->query('DELETE FROM sessions WHERE expires_at < NOW()');

$token = new_token();
db()->prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?,?, DATE_ADD(NOW(), INTERVAL 30 DAY))')
    ->execute([$token, $user['id']]);

send(['token' => $token, 'user' => public_user($user)]);
