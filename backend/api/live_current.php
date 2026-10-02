<?php
declare(strict_types=1);
require_once __DIR__ . '/../live_service.php';
require_method('GET');
$user = require_auth();
$classId = filter_var($_GET['class_id'] ?? null, FILTER_VALIDATE_INT);
if (!$classId) fail('class_id is required.', 422, 'VALIDATION_ERROR');
class_access_or_fail((int)$classId, $user);
$stmt = db()->prepare(
    "SELECT id, class_id, provider, provider_room_id, status, starts_at, ended_at
     FROM live_sessions WHERE class_id = ? AND status = 'live' ORDER BY id DESC LIMIT 1"
);
$stmt->execute([$classId]);
$session = $stmt->fetch();
send(['session' => $session ? [
    'id' => (int)$session['id'], 'class_id' => (int)$session['class_id'],
    'provider' => $session['provider'], 'status' => $session['status'],
    'starts_at' => iso_utc($session['starts_at']), 'ended_at' => iso_utc($session['ended_at']),
] : null]);
