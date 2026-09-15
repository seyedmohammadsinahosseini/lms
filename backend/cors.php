<?php
// CORS handling for the Flutter web client.
//
// The origin is checked against an allowlist rather than echoed back: blindly
// reflecting whatever a caller sends lets any website drive this API from a
// visitor's browser. Native builds (Android/iOS) and same-origin requests send
// no Origin header, so CORS does not apply to them either way.
//
// Additional origins -- a real deployment, a LAN URL -- go in
// OTMS_ALLOWED_ORIGINS as a comma-separated list:
//
//   Apache:  SetEnv OTMS_ALLOWED_ORIGINS "https://otms.example.com,http://192.168.1.15:8080"
//   CLI:     OTMS_ALLOWED_ORIGINS="https://otms.example.com" php -S 127.0.0.1:8080

function cors_origin_is_allowed(string $origin): bool {
    // Local development on any port: `flutter run -d chrome` serves the app
    // from a random localhost port, and the Android emulator reaches the host
    // machine as 10.0.2.2.
    if (preg_match(
        '#^https?://(localhost|127\.0\.0\.1|\[::1\]|10\.0\.2\.2)(:\d+)?$#',
        $origin
    )) {
        return true;
    }

    $configured = getenv('OTMS_ALLOWED_ORIGINS');
    if ($configured !== false && $configured !== '') {
        foreach (explode(',', $configured) as $candidate) {
            if (rtrim(trim($candidate), '/') === $origin) return true;
        }
    }
    return false;
}

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';

if ($origin !== '' && cors_origin_is_allowed($origin)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Vary: Origin');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, Authorization');
    header('Access-Control-Max-Age: 86400');
} elseif ($origin !== '') {
    // Untrusted browser origin: omit the allow-origin header so the browser
    // blocks the response. Vary keeps caches from mixing the two cases up.
    header('Vary: Origin');
    error_log('OTMS CORS: blocked origin ' . $origin);
}

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
    // Preflights always end here: an allowed origin has been answered above, an
    // untrusted one gets no allow-origin header, which surfaces as a clean CORS
    // error in the browser rather than a connection failure.
    http_response_code(204);
    exit;
}
