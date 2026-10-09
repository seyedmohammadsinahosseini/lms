<?php
declare(strict_types=1);
require_once __DIR__ . '/helpers.php';

function base64url_encode(string $value): string {
    return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
}

function jaas_token(string $room, array $user, bool $moderator): string {
    $appId = lms_env('LMS_JAAS_APP_ID');
    $keyId = lms_env('LMS_JAAS_KEY_ID');
    $keyFile = lms_env('LMS_JAAS_PRIVATE_KEY_FILE');
    if ($appId === '' || $keyId === '' || $keyFile === '' || !is_readable($keyFile)) {
        throw new RuntimeException('JaaS credentials are incomplete.');
    }
    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT', 'kid' => $appId . '/' . $keyId];
    $payload = [
        'aud' => 'jitsi', 'iss' => 'chat', 'sub' => $appId,
        'room' => $room, 'iat' => $now - 10, 'nbf' => $now - 10, 'exp' => $now + 7200,
        'context' => ['user' => [
            'id' => (string)$user['id'], 'name' => $user['full_name'],
            'email' => $user['email'], 'moderator' => $moderator,
        ]],
    ];
    $encoded = base64url_encode(json_encode($header, JSON_UNESCAPED_SLASHES)) . '.'
        . base64url_encode(json_encode($payload, JSON_UNESCAPED_SLASHES));
    $privateKey = openssl_pkey_get_private((string)file_get_contents($keyFile));
    if ($privateKey === false) throw new RuntimeException('JaaS private key is invalid.');
    if (!openssl_sign($encoded, $signature, $privateKey, OPENSSL_ALGO_SHA256)) {
        throw new RuntimeException('Could not sign the JaaS token.');
    }
    return $encoded . '.' . base64url_encode($signature);
}

function live_join_details(array $session, array $user, bool $moderator): array {
    $provider = $session['provider'];
    if ($provider === 'jaas') {
        $appId = lms_env('LMS_JAAS_APP_ID');
        $token = jaas_token($session['provider_room_id'], $user, $moderator);
        return [
            'provider' => 'jaas',
            'room' => $session['provider_room_id'],
            'join_url' => 'https://8x8.vc/' . rawurlencode($appId) . '/'
                . rawurlencode($session['provider_room_id']) . '?jwt=' . rawurlencode($token),
            'token' => $token,
        ];
    }
    return [
        'provider' => 'jitsi', 'room' => $session['provider_room_id'],
        'join_url' => rtrim(lms_env('LMS_JITSI_BASE_URL', 'https://meet.jit.si'), '/')
            . '/' . rawurlencode($session['provider_room_id']),
        'token' => null,
    ];
}
