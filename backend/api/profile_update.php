<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('PATCH', 'POST');
$user = require_auth();
$b = body();
$name = input_string($b, 'full_name', 120, true, 2);

db()->prepare('UPDATE users SET full_name = ? WHERE id = ?')->execute([$name, $user['id']]);
$user['full_name'] = $name;
audit_event((int)$user['id'], 'profile.update', 'user', (int)$user['id']);
send(['user' => public_user($user)]);
