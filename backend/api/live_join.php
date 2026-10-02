<?php
declare(strict_types=1);
require_once __DIR__ . '/../live_service.php';
require_method('POST');
$user = require_auth();
$b = body();
$sessionId = (int)input_int($b, 'session_id', 1);
$stmt = db()->prepare('SELECT * FROM live_sessions WHERE id = ?');
$stmt->execute([$sessionId]);
$session = $stmt->fetch();
if (!$session || $session['status'] !== 'live') fail('Live session is not available.', 404, 'LIVE_NOT_FOUND');
$class = class_access_or_fail((int)$session['class_id'], $user);
$moderator = $user['role'] === 'teacher' && (int)$class['teacher_id'] === (int)$user['id'];
$join = live_join_details($session, $user, $moderator);
audit_event((int)$user['id'], 'live.joined', 'live_session', $sessionId);
send(['session' => [
    'id' => $sessionId, 'class_id' => (int)$session['class_id'], 'status' => 'live',
    'starts_at' => iso_utc($session['starts_at']), ...$join,
]]);
