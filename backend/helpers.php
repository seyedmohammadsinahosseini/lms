<?php
declare(strict_types=1);

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/cors.php';

header('Content-Type: application/json; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: no-referrer');
header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'");

set_exception_handler(static function (Throwable $e): void {
    error_log(sprintf(
        'OTMS unhandled %s: %s in %s:%d',
        get_class($e),
        $e->getMessage(),
        $e->getFile(),
        $e->getLine()
    ));
    if (!headers_sent()) {
        send_error('INTERNAL_ERROR', 'An unexpected server error occurred.', 500);
    }
});

function send_json(mixed $data, int $code = 200): never {
    http_response_code($code);
    $json = json_encode(
        $data,
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
    );
    if ($json === false) {
        error_log('OTMS json_encode failed: ' . json_last_error_msg());
        http_response_code(500);
        echo '{"ok":false,"error":{"code":"ENCODING_ERROR","message":"Response encoding failed."}}';
        exit;
    }
    echo $json;
    exit;
}

// Backward-compatible success helper used by existing endpoints.
function send(mixed $data, int $code = 200): never {
    send_json($data, $code);
}

function send_error(
    string $errorCode,
    string $message,
    int $httpCode = 400,
    array $fields = []
): never {
    $error = ['code' => $errorCode, 'message' => $message];
    if ($fields !== []) $error['fields'] = $fields;
    send_json(['ok' => false, 'error' => $error], $httpCode);
}

function fail(
    string $message,
    int $code = 400,
    string $errorCode = 'BAD_REQUEST',
    array $fields = []
): never {
    send_error($errorCode, $message, $code, $fields);
}

function body(): array {
    $contentType = strtolower((string)($_SERVER['CONTENT_TYPE'] ?? ''));
    if (str_contains($contentType, 'application/json')) {
        $raw = file_get_contents('php://input');
        if ($raw === false || trim($raw) === '') return [];
        try {
            $data = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            fail('The request body is not valid JSON.', 400, 'INVALID_JSON');
        }
        if (!is_array($data) || array_is_list($data)) {
            fail('The JSON body must be an object.', 400, 'INVALID_JSON');
        }
        return $data;
    }
    return $_POST ?: [];
}

function require_method(string ...$methods): void {
    $actual = strtoupper((string)($_SERVER['REQUEST_METHOD'] ?? ''));
    $allowed = array_map('strtoupper', $methods);
    if (!in_array($actual, $allowed, true)) {
        header('Allow: ' . implode(', ', $allowed));
        fail('Method not allowed.', 405, 'METHOD_NOT_ALLOWED');
    }
}

function is_mutating_request(): bool {
    return in_array(
        strtoupper((string)($_SERVER['REQUEST_METHOD'] ?? 'GET')),
        ['POST', 'PUT', 'PATCH', 'DELETE'],
        true
    );
}

// ---- Input validation -----------------------------------------------------

function input_string(
    array $data,
    string $key,
    int $maxLength,
    bool $required = true,
    int $minLength = 0
): ?string {
    $value = $data[$key] ?? null;
    if ($value === null) {
        if ($required) fail("{$key} is required.", 422, 'VALIDATION_ERROR', [$key => 'Required']);
        return null;
    }
    if (!is_string($value)) {
        fail("{$key} must be a string.", 422, 'VALIDATION_ERROR', [$key => 'Invalid type']);
    }
    $value = trim($value);
    $length = mb_strlen($value);
    if ($required && $length === 0) {
        fail("{$key} is required.", 422, 'VALIDATION_ERROR', [$key => 'Required']);
    }
    if ($length < $minLength || $length > $maxLength) {
        fail(
            "{$key} must be between {$minLength} and {$maxLength} characters.",
            422,
            'VALIDATION_ERROR',
            [$key => 'Invalid length']
        );
    }
    return $value === '' && !$required ? null : $value;
}

function input_int(
    array $data,
    string $key,
    int $min = 0,
    int $max = PHP_INT_MAX,
    bool $required = true
): ?int {
    $value = $data[$key] ?? null;
    if ($value === null || $value === '') {
        if ($required) fail("{$key} is required.", 422, 'VALIDATION_ERROR', [$key => 'Required']);
        return null;
    }
    $validated = filter_var($value, FILTER_VALIDATE_INT);
    if ($validated === false || $validated < $min || $validated > $max) {
        fail("{$key} is invalid.", 422, 'VALIDATION_ERROR', [$key => 'Invalid integer']);
    }
    return (int)$validated;
}

function input_bool(array $data, string $key, bool $default = false): bool {
    if (!array_key_exists($key, $data)) return $default;
    $value = filter_var($data[$key], FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE);
    if ($value === null) {
        fail("{$key} must be true or false.", 422, 'VALIDATION_ERROR', [$key => 'Invalid boolean']);
    }
    return $value;
}

function input_enum(array $data, string $key, array $allowed, ?string $default = null): string {
    $value = $data[$key] ?? $default;
    if (!is_string($value) || !in_array($value, $allowed, true)) {
        fail("{$key} is invalid.", 422, 'VALIDATION_ERROR', [$key => 'Allowed: ' . implode(', ', $allowed)]);
    }
    return $value;
}

function input_datetime(array $data, string $key, bool $required = false): ?string {
    $value = $data[$key] ?? null;
    if ($value === null || $value === '') {
        if ($required) fail("{$key} is required.", 422, 'VALIDATION_ERROR', [$key => 'Required']);
        return null;
    }
    if (!is_string($value)) {
        fail("{$key} must be an ISO-8601 date/time.", 422, 'VALIDATION_ERROR', [$key => 'Invalid date']);
    }
    try {
        $date = new DateTimeImmutable($value);
    } catch (Throwable) {
        fail("{$key} is not a valid date/time.", 422, 'VALIDATION_ERROR', [$key => 'Invalid date']);
    }
    return $date->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d H:i:s');
}

function valid_https_url(?string $url, bool $allowLocalHttp = false): ?string {
    if ($url === null || trim($url) === '') return null;
    $url = trim($url);
    if (mb_strlen($url) > 500 || filter_var($url, FILTER_VALIDATE_URL) === false) {
        fail('The URL is invalid.', 422, 'VALIDATION_ERROR', ['url' => 'Invalid URL']);
    }
    $scheme = strtolower((string)parse_url($url, PHP_URL_SCHEME));
    $httpAllowed = $allowLocalHttp && !otms_is_production() && $scheme === 'http';
    if ($scheme !== 'https' && !$httpAllowed) {
        fail('Only HTTPS URLs are allowed.', 422, 'VALIDATION_ERROR', ['url' => 'HTTPS required']);
    }
    return $url;
}

// ---- Authentication and CSRF ---------------------------------------------

function token_hash(string $raw): string {
    return hash('sha256', $raw);
}

function new_token(): string {
    return bin2hex(random_bytes(32));
}

function bearer_token(): ?string {
    $header = (string)($_SERVER['HTTP_AUTHORIZATION'] ?? '');
    if ($header === '' && function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
        $header = (string)($headers['Authorization'] ?? $headers['authorization'] ?? '');
    }
    return preg_match('/^Bearer\s+([A-Fa-f0-9]{64})$/', trim($header), $match)
        ? $match[1]
        : null;
}

function request_session_token(): array {
    $bearer = bearer_token();
    if ($bearer !== null) return [$bearer, 'bearer'];
    $cookie = $_COOKIE['otms_session'] ?? null;
    if (is_string($cookie) && preg_match('/^[A-Fa-f0-9]{64}$/', $cookie)) {
        return [$cookie, 'cookie'];
    }
    return [null, null];
}

function request_wants_cookie_session(): bool {
    return strtolower((string)($_SERVER['HTTP_X_OTMS_CLIENT'] ?? '')) === 'web';
}

function cookie_is_secure(): bool {
    if (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') return true;
    return otms_is_production();
}

function set_session_cookie(string $token, int $expiresAt): void {
    setcookie('otms_session', $token, [
        'expires' => $expiresAt,
        'path' => '/',
        'secure' => cookie_is_secure(),
        'httponly' => true,
        'samesite' => 'Strict',
    ]);
}

function clear_session_cookie(): void {
    setcookie('otms_session', '', [
        'expires' => time() - 3600,
        'path' => '/',
        'secure' => cookie_is_secure(),
        'httponly' => true,
        'samesite' => 'Strict',
    ]);
}

function issue_session(int $userId, ?string $deviceName = null): array {
    $rawToken = new_token();
    $rawCsrf = new_token();
    $days = otms_demo_mode() ? 1 : 30;
    $expiresAt = time() + $days * 86400;
    db()->prepare(
        'INSERT INTO sessions (token_hash, csrf_token_hash, user_id, device_name, expires_at, last_used_at)
         VALUES (?,?,?,?,?,UTC_TIMESTAMP())'
    )->execute([
        token_hash($rawToken),
        token_hash($rawCsrf),
        $userId,
        $deviceName === null ? null : mb_substr($deviceName, 0, 160),
        gmdate('Y-m-d H:i:s', $expiresAt),
    ]);

    $cookieSession = request_wants_cookie_session();
    if ($cookieSession) set_session_cookie($rawToken, $expiresAt);
    return [
        'token' => $cookieSession ? null : $rawToken,
        'csrf_token' => $rawCsrf,
        'expires_at' => gmdate('c', $expiresAt),
        'transport' => $cookieSession ? 'cookie' : 'bearer',
    ];
}

function require_auth(): array {
    [$rawToken, $transport] = request_session_token();
    if (!is_string($rawToken)) fail('Not authenticated.', 401, 'UNAUTHENTICATED');

    $stmt = db()->prepare(
        'SELECT s.id AS session_id, s.csrf_token_hash, s.expires_at, u.*
         FROM sessions s JOIN users u ON u.id = s.user_id
         WHERE s.token_hash = ? AND s.expires_at > UTC_TIMESTAMP()'
    );
    $stmt->execute([token_hash($rawToken)]);
    $user = $stmt->fetch();
    if (!$user) {
        if ($transport === 'cookie') clear_session_cookie();
        fail('Session expired.', 401, 'SESSION_EXPIRED');
    }

    if ($transport === 'cookie' && is_mutating_request()) {
        $csrf = (string)($_SERVER['HTTP_X_CSRF_TOKEN'] ?? '');
        if ($csrf === '' || !hash_equals((string)$user['csrf_token_hash'], token_hash($csrf))) {
            fail('CSRF token is missing or invalid.', 403, 'CSRF_FAILED');
        }
    }

    $user['_auth_transport'] = $transport;
    $user['_session_id'] = (int)$user['session_id'];
    unset($user['session_id'], $user['csrf_token_hash'], $user['password_hash']);

    // Low-cost opportunistic expiry cleanup and usage timestamp update.
    if (random_int(1, 20) === 1) {
        db()->prepare('UPDATE sessions SET last_used_at = UTC_TIMESTAMP() WHERE id = ?')
            ->execute([$user['_session_id']]);
        db()->exec('DELETE FROM sessions WHERE expires_at <= UTC_TIMESTAMP()');
    }
    return $user;
}

function rotate_csrf_token(array $user): string {
    $raw = new_token();
    db()->prepare('UPDATE sessions SET csrf_token_hash = ? WHERE id = ?')
        ->execute([token_hash($raw), (int)$user['_session_id']]);
    return $raw;
}

function revoke_current_session(array $user): void {
    db()->prepare('DELETE FROM sessions WHERE id = ?')->execute([(int)$user['_session_id']]);
    if (($user['_auth_transport'] ?? '') === 'cookie') clear_session_cookie();
}

function require_role(array $user, string $role): void {
    if (($user['role'] ?? '') !== $role) fail('Forbidden.', 403, 'FORBIDDEN');
}

function public_user(array $user): array {
    return [
        'id' => (int)$user['id'],
        'full_name' => (string)$user['full_name'],
        'email' => (string)$user['email'],
        'role' => (string)$user['role'],
        'avatar_file_id' => isset($user['avatar_file_id']) ? (int)$user['avatar_file_id'] : null,
    ];
}

// ---- Rate limiting --------------------------------------------------------

function client_ip(): string {
    if (otms_env_bool('OTMS_TRUST_PROXY', false)) {
        foreach (['HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR'] as $key) {
            $candidate = trim(explode(',', (string)($_SERVER[$key] ?? ''))[0]);
            if (filter_var($candidate, FILTER_VALIDATE_IP)) return $candidate;
        }
    }
    $remote = (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown');
    return filter_var($remote, FILTER_VALIDATE_IP) ? $remote : 'unknown';
}

function privacy_hash(string $value): string {
    return hash_hmac('sha256', strtolower(trim($value)), otms_app_key());
}

function enforce_rate_limit(
    string $bucket,
    string $subject,
    int $maxHits,
    int $windowSeconds,
    int $blockSeconds = 0
): void {
    $subjectHash = privacy_hash($subject);
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $stmt = $pdo->prepare(
            'SELECT * FROM rate_limits WHERE bucket = ? AND subject_hash = ? FOR UPDATE'
        );
        $stmt->execute([$bucket, $subjectHash]);
        $row = $stmt->fetch();
        $now = time();
        if (!$row) {
            $pdo->prepare(
                'INSERT INTO rate_limits (bucket, subject_hash, hit_count, window_started_at)
                 VALUES (?,?,1,UTC_TIMESTAMP())'
            )->execute([$bucket, $subjectHash]);
            $pdo->commit();
            return;
        }

        $blockedUntil = $row['blocked_until'] ? strtotime($row['blocked_until'] . ' UTC') : 0;
        if ($blockedUntil > $now) {
            $pdo->commit();
            header('Retry-After: ' . ($blockedUntil - $now));
            fail('Too many requests. Try again later.', 429, 'RATE_LIMITED');
        }

        $windowStart = strtotime($row['window_started_at'] . ' UTC') ?: 0;
        if ($windowStart + $windowSeconds <= $now) {
            $pdo->prepare(
                'UPDATE rate_limits SET hit_count = 1, window_started_at = UTC_TIMESTAMP(), blocked_until = NULL
                 WHERE bucket = ? AND subject_hash = ?'
            )->execute([$bucket, $subjectHash]);
            $pdo->commit();
            return;
        }

        $hits = (int)$row['hit_count'] + 1;
        $blocked = $hits > $maxHits && $blockSeconds > 0
            ? gmdate('Y-m-d H:i:s', $now + $blockSeconds)
            : null;
        $pdo->prepare(
            'UPDATE rate_limits SET hit_count = ?, blocked_until = ? WHERE bucket = ? AND subject_hash = ?'
        )->execute([$hits, $blocked, $bucket, $subjectHash]);
        $pdo->commit();

        if ($hits > $maxHits) {
            header('Retry-After: ' . max(1, $blockSeconds ?: ($windowStart + $windowSeconds - $now)));
            fail('Too many requests. Try again later.', 429, 'RATE_LIMITED');
        }
    } catch (Throwable $e) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $e;
    }
}

function clear_rate_limit(string $bucket, string $subject): void {
    db()->prepare('DELETE FROM rate_limits WHERE bucket = ? AND subject_hash = ?')
        ->execute([$bucket, privacy_hash($subject)]);
}

// Compatibility wrappers used by older tests/endpoints.
function login_attempts_exceeded(string $email, string $ip): bool {
    // Enforcement is atomic in enforce_rate_limit; this function intentionally
    // returns false and callers should invoke record_login_failure on failure.
    return false;
}
function record_login_failure(string $email, string $ip): void {
    enforce_rate_limit('login', $email . '|' . $ip, 10, 900, 900);
}
function clear_login_failures(string $email, string $ip): void {
    clear_rate_limit('login', $email . '|' . $ip);
}

// ---- Authorization helpers ------------------------------------------------

function owned_class_or_fail(int $classId, int $teacherId): array {
    $stmt = db()->prepare('SELECT * FROM classes WHERE id = ?');
    $stmt->execute([$classId]);
    $class = $stmt->fetch();
    if (!$class) fail('Class not found.', 404, 'NOT_FOUND');
    if ((int)$class['teacher_id'] !== $teacherId) fail('Forbidden.', 403, 'FORBIDDEN');
    return $class;
}

function enrolled_or_fail(int $classId, int $studentId): void {
    $stmt = db()->prepare('SELECT 1 FROM enrollments WHERE class_id = ? AND student_id = ?');
    $stmt->execute([$classId, $studentId]);
    if (!$stmt->fetchColumn()) fail('Not enrolled in this class.', 403, 'NOT_ENROLLED');
}

function class_access_or_fail(int $classId, array $user): array {
    $stmt = db()->prepare('SELECT * FROM classes WHERE id = ?');
    $stmt->execute([$classId]);
    $class = $stmt->fetch();
    if (!$class) fail('Class not found.', 404, 'NOT_FOUND');
    if (($user['role'] ?? '') === 'teacher') {
        if ((int)$class['teacher_id'] !== (int)$user['id']) fail('Forbidden.', 403, 'FORBIDDEN');
    } else {
        enrolled_or_fail($classId, (int)$user['id']);
    }
    return $class;
}

function lesson_access_or_fail(int $lessonId, array $user): array {
    $stmt = db()->prepare('SELECT * FROM lessons WHERE id = ?');
    $stmt->execute([$lessonId]);
    $lesson = $stmt->fetch();
    if (!$lesson) fail('Lesson not found.', 404, 'NOT_FOUND');
    $class = class_access_or_fail((int)$lesson['class_id'], $user);
    return [$lesson, $class];
}

function assessment_access_or_fail(int $assessmentId, array $user): array {
    $stmt = db()->prepare('SELECT * FROM assessments WHERE id = ?');
    $stmt->execute([$assessmentId]);
    $assessment = $stmt->fetch();
    if (!$assessment) fail('Assessment not found.', 404, 'NOT_FOUND');
    class_access_or_fail((int)$assessment['class_id'], $user);
    return $assessment;
}

function homework_access_or_fail(int $homeworkId, array $user): array {
    $stmt = db()->prepare('SELECT * FROM homework WHERE id = ?');
    $stmt->execute([$homeworkId]);
    $homework = $stmt->fetch();
    if (!$homework) fail('Homework not found.', 404, 'NOT_FOUND');
    class_access_or_fail((int)$homework['class_id'], $user);
    return $homework;
}

// ---- Files ----------------------------------------------------------------

function max_upload_bytes(): int {
    return 8 * 1024 * 1024;
}

function upload_allowed_extensions(): array {
    return [
        'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt', 'md',
        'ppt', 'pptx', 'odp', 'xls', 'xlsx', 'ods', 'csv',
        'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic',
        'mp4', 'mov', 'm4v', 'webm', 'mp3', 'wav', 'm4a', 'ogg',
        'zip', '7z', 'rar', 'tar', 'gz',
    ];
}

function guard_request_size(): void {
    $length = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
    if ($length > max_upload_bytes() + 128 * 1024) {
        fail('File is too large. Maximum size is 8 MB.', 413, 'FILE_TOO_LARGE');
    }
}
guard_request_size();

function upload_error_message(int $error): string {
    return match ($error) {
        UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE => 'File is too large.',
        UPLOAD_ERR_PARTIAL => 'The upload was interrupted before completion.',
        UPLOAD_ERR_NO_FILE => 'No file was uploaded.',
        UPLOAD_ERR_NO_TMP_DIR => 'The server upload directory is unavailable.',
        UPLOAD_ERR_CANT_WRITE => 'The server could not write the uploaded file.',
        UPLOAD_ERR_EXTENSION => 'A server extension rejected the uploaded file.',
        default => 'The upload failed.',
    };
}

function mime_matches_extension(string $mime, string $ext): bool {
    $mime = strtolower($mime);
    $strict = [
        'pdf' => ['application/pdf'],
        'png' => ['image/png'],
        'jpg' => ['image/jpeg'],
        'jpeg' => ['image/jpeg'],
        'gif' => ['image/gif'],
        'webp' => ['image/webp'],
        'txt' => ['text/plain'],
        'csv' => ['text/plain', 'text/csv', 'application/csv'],
        'mp3' => ['audio/mpeg', 'audio/mp3'],
        'wav' => ['audio/wav', 'audio/x-wav'],
        'mp4' => ['video/mp4'],
        'webm' => ['video/webm', 'audio/webm'],
        'zip' => ['application/zip', 'application/x-zip'],
    ];
    if (isset($strict[$ext])) return in_array($mime, $strict[$ext], true);
    // OOXML/ODF/archive formats are ZIP containers; legacy office formats and
    // uncommon media frequently use generic vendor/octet-stream MIME values.
    return $mime !== 'text/html'
        && $mime !== 'image/svg+xml'
        && !str_contains($mime, 'php')
        && !str_contains($mime, 'javascript');
}

/** @return array{id:int,download_path:string,original_name:string,mime_type:string,byte_size:int}|null */
function save_upload(string $field, int $ownerUserId): ?array {
    if (!isset($_FILES[$field])) return null;
    $file = $_FILES[$field];
    $error = (int)($file['error'] ?? UPLOAD_ERR_NO_FILE);
    if ($error === UPLOAD_ERR_NO_FILE) return null;
    if ($error !== UPLOAD_ERR_OK) {
        $status = in_array($error, [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true) ? 413 : 422;
        fail(upload_error_message($error), $status, 'UPLOAD_FAILED');
    }

    $size = (int)($file['size'] ?? 0);
    if ($size <= 0) fail('The uploaded file is empty.', 422, 'EMPTY_FILE');
    if ($size > max_upload_bytes()) fail('File is too large. Maximum size is 8 MB.', 413, 'FILE_TOO_LARGE');

    $originalName = basename((string)($file['name'] ?? 'file'));
    $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
    if (!in_array($extension, upload_allowed_extensions(), true)) {
        fail('This file type is not allowed.', 415, 'UNSUPPORTED_FILE_TYPE');
    }

    $tmp = (string)($file['tmp_name'] ?? '');
    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $mime = (string)$finfo->file($tmp);
    if (!mime_matches_extension($mime, $extension)) {
        fail('The file content does not match its extension.', 415, 'FILE_TYPE_MISMATCH');
    }

    $storageDir = otms_storage_path();
    if (!is_dir($storageDir) && !mkdir($storageDir, 0700, true)) {
        fail('Private upload storage is unavailable.', 500, 'STORAGE_UNAVAILABLE');
    }
    $storageName = bin2hex(random_bytes(24)) . '.' . $extension;
    $target = $storageDir . DIRECTORY_SEPARATOR . $storageName;
    if (!move_uploaded_file($tmp, $target)) {
        fail('Could not store the uploaded file.', 500, 'STORAGE_WRITE_FAILED');
    }
    @chmod($target, 0600);

    try {
        $sha = hash_file('sha256', $target);
        db()->prepare(
            'INSERT INTO stored_files
             (owner_user_id, storage_name, original_name, mime_type, byte_size, sha256)
             VALUES (?,?,?,?,?,?)'
        )->execute([$ownerUserId, $storageName, mb_substr($originalName, 0, 255), $mime, $size, $sha]);
        $id = (int)db()->lastInsertId();
        return [
            'id' => $id,
            'storage_name' => $storageName,
            'download_path' => 'file_download.php?id=' . $id,
            'original_name' => $originalName,
            'mime_type' => $mime,
            'byte_size' => $size,
        ];
    } catch (Throwable $e) {
        @unlink($target);
        throw $e;
    }
}

function file_download_path(?int $fileId, ?string $legacyPath = null, ?int $userId = null): ?string {
    if ($fileId !== null && $fileId > 0) {
        if ($userId === null) return 'file_download.php?id=' . $fileId;
        $expires = time() + 300;
        $payload = $fileId . '|' . $userId . '|' . $expires;
        $signature = hash_hmac('sha256', $payload, otms_app_key());
        return 'file_download.php?id=' . $fileId . '&uid=' . $userId
            . '&exp=' . $expires . '&sig=' . $signature;
    }
    // Legacy paths are never exposed directly. A migration/import endpoint can
    // move them into stored_files; until then they are intentionally unavailable.
    return null;
}

function signed_download_user(int $fileId): ?array {
    $userId = filter_var($_GET['uid'] ?? null, FILTER_VALIDATE_INT);
    $expires = filter_var($_GET['exp'] ?? null, FILTER_VALIDATE_INT);
    $signature = (string)($_GET['sig'] ?? '');
    if (!$userId || !$expires || $expires < time() || $expires > time() + 600
        || !preg_match('/^[a-f0-9]{64}$/', $signature)) return null;
    $expected = hash_hmac('sha256', $fileId . '|' . $userId . '|' . $expires, otms_app_key());
    if (!hash_equals($expected, $signature)) return null;
    $stmt = db()->prepare('SELECT * FROM users WHERE id = ?');
    $stmt->execute([$userId]);
    return $stmt->fetch() ?: null;
}

function discard_saved_upload(?array $file): void {
    if ($file === null) return;
    if (isset($file['id'])) {
        try {
            db()->prepare('DELETE FROM stored_files WHERE id = ?')->execute([(int)$file['id']]);
        } catch (Throwable $e) {
            error_log('OTMS failed to remove uploaded-file row: ' . $e->getMessage());
        }
    }
    if (!empty($file['storage_name'])) {
        @unlink(otms_storage_path() . DIRECTORY_SEPARATOR . basename((string)$file['storage_name']));
    }
}

function delete_stored_file_if_unreferenced(?int $fileId): void {
    if (!$fileId) return;
    $stmt = db()->prepare(
        'SELECT sf.storage_name,
          (SELECT COUNT(*) FROM contents c WHERE c.file_id = sf.id) +
          (SELECT COUNT(*) FROM submission_versions sv WHERE sv.file_id = sf.id) +
          (SELECT COUNT(*) FROM users u WHERE u.avatar_file_id = sf.id) AS refs
         FROM stored_files sf WHERE sf.id = ?'
    );
    $stmt->execute([$fileId]);
    $row = $stmt->fetch();
    if (!$row || (int)$row['refs'] > 0) return;
    db()->prepare('DELETE FROM stored_files WHERE id = ?')->execute([$fileId]);
    @unlink(otms_storage_path() . DIRECTORY_SEPARATOR . $row['storage_name']);
}

// ---- Common operations ----------------------------------------------------

function generate_teacher_code(): string {
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    for ($attempt = 0; $attempt < 10; $attempt++) {
        $code = '';
        for ($i = 0; $i < 10; $i++) $code .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        $stmt = db()->prepare('SELECT 1 FROM teacher_codes WHERE code = ?');
        $stmt->execute([$code]);
        if (!$stmt->fetchColumn()) return $code;
    }
    throw new RuntimeException('Could not allocate a unique teacher code.');
}

function create_join_grant(int $studentId, int $teacherId): string {
    $raw = new_token();
    db()->prepare(
        'INSERT INTO join_grants (token_hash, student_id, teacher_id, expires_at)
         VALUES (?,?,?,DATE_ADD(UTC_TIMESTAMP(), INTERVAL 10 MINUTE))'
    )->execute([token_hash($raw), $studentId, $teacherId]);
    return $raw;
}

function audit_event(
    ?int $actorId,
    string $eventType,
    ?string $entityType = null,
    ?int $entityId = null,
    array $metadata = []
): void {
    try {
        db()->prepare(
            'INSERT INTO audit_events
             (actor_user_id, event_type, entity_type, entity_id, metadata_json, ip_hash)
             VALUES (?,?,?,?,?,?)'
        )->execute([
            $actorId,
            mb_substr($eventType, 0, 80),
            $entityType === null ? null : mb_substr($entityType, 0, 60),
            $entityId,
            $metadata === [] ? null : json_encode($metadata, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            privacy_hash(client_ip()),
        ]);
    } catch (Throwable $e) {
        // Auditing must not turn a successful user operation into a 500, but
        // its failure remains visible to operators.
        error_log('OTMS audit write failed: ' . $e->getMessage());
    }
}

function pagination(int $defaultPerPage = 30, int $maxPerPage = 100): array {
    $page = max(1, filter_var($_GET['page'] ?? 1, FILTER_VALIDATE_INT) ?: 1);
    $perPage = filter_var($_GET['per_page'] ?? $defaultPerPage, FILTER_VALIDATE_INT) ?: $defaultPerPage;
    $perPage = min($maxPerPage, max(1, $perPage));
    return [$page, $perPage, ($page - 1) * $perPage];
}

function iso_utc(?string $sqlDate): ?string {
    if ($sqlDate === null || $sqlDate === '') return null;
    return (new DateTimeImmutable($sqlDate, new DateTimeZone('UTC')))->format(DATE_ATOM);
}
