<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('POST');
$user = require_auth();
revoke_current_session($user);
audit_event((int)$user['id'], 'auth.logout', 'user', (int)$user['id']);
send(['success' => true]);
