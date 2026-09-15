<?php
require_once __DIR__ . '/../helpers.php';
require_method('POST');

$b = body();
$email = trim($b['email'] ?? '');
$password = $b['password'] ?? '';
if ($email === '' || $password === '') fail('Email and password are required.');

$stmt = db()->prepare('SELECT * FROM users WHERE email = ?');
$stmt->execute([$email]);
$user = $stmt->fetch();

if (!$user || !password_verify($password, $user['password_hash'])) {
    fail('Invalid email or password.', 401);
}

$token = new_token();
db()->prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?,?, DATE_ADD(NOW(), INTERVAL 30 DAY))')
    ->execute([$token, $user['id']]);

send(['token' => $token, 'user' => public_user($user)]);
