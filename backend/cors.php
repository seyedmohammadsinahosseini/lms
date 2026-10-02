<?php
declare(strict_types=1);

// Strict CORS allowlist. Native clients and same-origin requests generally do
// not send Origin. Cross-origin web sessions are allowed only for configured
// origins and carry credentials for the HttpOnly session cookie.

function cors_origin_is_allowed(string $origin): bool {
    if (!otms_is_production()
        && preg_match('#^https?://(localhost|127\.0\.0\.1|\[::1\]|10\.0\.2\.2)(:\d+)?$#', $origin)) {
        return true;
    }
    $configured = getenv('OTMS_ALLOWED_ORIGINS');
    if (!is_string($configured) || $configured === '') return false;
    foreach (explode(',', $configured) as $candidate) {
        if (rtrim(trim($candidate), '/') === rtrim($origin, '/')) return true;
    }
    return false;
}

$origin = (string)($_SERVER['HTTP_ORIGIN'] ?? '');
if ($origin !== '' && cors_origin_is_allowed($origin)) {
    header("Access-Control-Allow-Origin: {$origin}");
    header('Access-Control-Allow-Credentials: true');
    header('Vary: Origin');
    header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization, X-CSRF-Token, X-OTMS-Client, Idempotency-Key');
    header('Access-Control-Max-Age: 86400');
} elseif ($origin !== '') {
    header('Vary: Origin');
    error_log('OTMS CORS blocked origin: ' . $origin);
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    http_response_code(204);
    exit;
}
