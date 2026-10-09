<?php
declare(strict_types=1);
require_once __DIR__ . '/../live_service.php';
require_method('POST');
$user = require_auth();
require_role($user, 'teacher');
$b = body();
$classId = (int)input_int($b, 'class_id', 1);
owned_class_or_fail($classId, (int)$user['id']);
enforce_rate_limit('live_start', (string)$user['id'], 10, 3600, 3600);
$provider = lms_env('LMS_LIVE_PROVIDER', 'jitsi');
if (!in_array($provider, ['jitsi', 'jaas'], true)) $provider = 'jitsi';
if ($provider === 'jitsi' && lms_is_production()) {
    fail('A managed or self-hosted authenticated Live provider is required in production.', 503, 'LIVE_PROVIDER_NOT_CONFIGURED');
}

$pdo = db();
$pdo->beginTransaction();
try {
    $stmt = $pdo->prepare(
        "SELECT * FROM live_sessions WHERE class_id = ? AND status = 'live'
         ORDER BY id DESC LIMIT 1 FOR UPDATE"
    );
    $stmt->execute([$classId]);
    $session = $stmt->fetch();
    if (!$session) {
        $room = 'lms-' . $classId . '-' . bin2hex(random_bytes(12));
        $baseUrl = $provider === 'jaas' ? 'https://8x8.vc' : rtrim(lms_env('LMS_JITSI_BASE_URL', 'https://meet.jit.si'), '/');
        $pdo->prepare(
            "INSERT INTO live_sessions
             (class_id, created_by, provider, provider_room_id, join_url, status, starts_at)
             VALUES (?,?,?,?,?,'live',UTC_TIMESTAMP())"
        )->execute([$classId, $user['id'], $provider, $room, $baseUrl . '/' . $room]);
        $id = (int)$pdo->lastInsertId();
        $stmt = $pdo->prepare('SELECT * FROM live_sessions WHERE id = ?');
        $stmt->execute([$id]);
        $session = $stmt->fetch();
    }
    $pdo->commit();
} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    throw $e;
}
$join = live_join_details($session, $user, true);
audit_event((int)$user['id'], 'live.started', 'live_session', (int)$session['id'], ['class_id' => $classId]);
send(['session' => [
    'id' => (int)$session['id'], 'class_id' => (int)$session['class_id'],
    'status' => $session['status'], 'starts_at' => iso_utc($session['starts_at']), ...$join,
]], 201);
