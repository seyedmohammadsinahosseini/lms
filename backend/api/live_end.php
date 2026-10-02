<?php
declare(strict_types=1);
require_once __DIR__ . '/../live_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$sessionId = (int)input_int($b, 'session_id', 1);
$stmt = db()->prepare('SELECT * FROM live_sessions WHERE id = ?');
$stmt->execute([$sessionId]);
$session = $stmt->fetch();
if (!$session) fail('Live session not found.', 404, 'NOT_FOUND');
owned_class_or_fail((int)$session['class_id'], (int)$user['id']);
db()->prepare("UPDATE live_sessions SET status = 'ended', ended_at = UTC_TIMESTAMP() WHERE id = ? AND status = 'live'")
    ->execute([$sessionId]);
audit_event((int)$user['id'], 'live.ended', 'live_session', $sessionId);
send(['success' => true]);
