<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
if (!otms_demo_mode()) fail('Demo mode is disabled.', 404, 'NOT_FOUND');
enforce_rate_limit('demo_login', client_ip(), 20, 3600, 3600);
$b = body();
$demoPublicId = input_string($b, 'demo_id', 32, true, 32);
$accessKey = input_string($b, 'access_key', 128, true, 32);
$role = input_enum($b, 'role', ['teacher', 'student']);
$stmt = db()->prepare(
    'SELECT u.* FROM demo_sessions d JOIN users u ON u.demo_session_id = d.id
     WHERE d.public_id = ? AND d.access_key_hash = ? AND d.expires_at > UTC_TIMESTAMP()
       AND u.role = ? LIMIT 1'
);
$stmt->execute([$demoPublicId, token_hash((string)$accessKey), $role]);
$user = $stmt->fetch();
if (!$user) fail('Demo session is invalid or expired.', 401, 'DEMO_EXPIRED');
$session = issue_session((int)$user['id'], 'OTMS portfolio demo');
audit_event((int)$user['id'], 'demo.login', 'user', (int)$user['id'], ['role' => $role]);
send([...$session, 'user' => public_user($user)]);
