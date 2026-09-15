<?php
require_once __DIR__ . '/../helpers.php';
require_method('POST');

$b = body();
$name = trim($b['full_name'] ?? '');
$email = trim($b['email'] ?? '');
$password = $b['password'] ?? '';
$role = $b['role'] ?? '';

if ($name === '' || $email === '' || $password === '') fail('All fields are required.');
if (!filter_var($email, FILTER_VALIDATE_EMAIL)) fail('Invalid email format.');
if (strlen($password) < 6) fail('Password must be at least 6 characters.');
if (!in_array($role, ['student', 'teacher'], true)) fail('Invalid role.');

$stmt = db()->prepare('SELECT 1 FROM users WHERE email = ?');
$stmt->execute([$email]);
if ($stmt->fetch()) fail('Email already registered.', 409);

$hash = password_hash($password, PASSWORD_DEFAULT);
$stmt = db()->prepare('INSERT INTO users (full_name, email, password_hash, role) VALUES (?,?,?,?)');
$stmt->execute([$name, $email, $hash, $role]);
$userId = (int)db()->lastInsertId();

// Teachers get an initial join code.
if ($role === 'teacher') {
    do {
        $code = strtoupper(bin2hex(random_bytes(3))); // 6 hex chars
        $c = db()->prepare('SELECT 1 FROM teacher_codes WHERE code = ?');
        $c->execute([$code]);
    } while ($c->fetch());
    db()->prepare('INSERT INTO teacher_codes (teacher_id, code) VALUES (?,?)')->execute([$userId, $code]);
}

// Auto-login: issue a session token.
$token = new_token();
db()->prepare('INSERT INTO sessions (token, user_id, expires_at) VALUES (?,?, DATE_ADD(NOW(), INTERVAL 30 DAY))')
    ->execute([$token, $userId]);

send([
    'token' => $token,
    'user' => ['id' => $userId, 'full_name' => $name, 'email' => $email, 'role' => $role],
], 201);
