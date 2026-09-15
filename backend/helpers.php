<?php
require_once __DIR__ . '/cors.php';
require_once __DIR__ . '/config.php';

header('Content-Type: application/json; charset=utf-8');

function body(): array {
    // Prefer a JSON body when present (raw input is empty for multipart form
    // uploads, so those fall through to $_POST).
    $raw = file_get_contents('php://input');
    if ($raw !== '' && $raw !== false) {
        $data = json_decode($raw, true);
        if (is_array($data)) return $data;
    }
    return $_POST ?: [];
}

function send($data, int $code = 200): void {
    http_response_code($code);
    echo json_encode($data);
    exit;
}

function fail(string $message, int $code = 400): void {
    send(['error' => $message], $code);
}

function require_method(string $method): void {
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== $method) {
        fail('Method not allowed', 405);
    }
}

function bearer_token(): ?string {
    $hdr = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($hdr === '' && function_exists('apache_request_headers')) {
        $h = apache_request_headers();
        $hdr = $h['Authorization'] ?? $h['authorization'] ?? '';
    }
    if (preg_match('/Bearer\s+(\S+)/i', $hdr, $m)) return $m[1];
    return null;
}

// Returns the authenticated user row, or sends 401 and exits.
function require_auth(): array {
    $token = bearer_token();
    if (!$token) fail('Not authenticated', 401);
    $stmt = db()->prepare(
        'SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
         WHERE s.token = ? AND s.expires_at > NOW()'
    );
    $stmt->execute([$token]);
    $user = $stmt->fetch();
    if (!$user) fail('Session expired', 401);
    return $user;
}

function require_role(array $user, string $role): void {
    if ($user['role'] !== $role) fail('Forbidden', 403);
}

function public_user(array $u): array {
    return [
        'id' => (int)$u['id'],
        'full_name' => $u['full_name'],
        'email' => $u['email'],
        'role' => $u['role'],
    ];
}

// Confirms the given class belongs to this teacher; sends 403/404 otherwise.
function owned_class_or_fail(int $classId, int $teacherId): array {
    $stmt = db()->prepare('SELECT * FROM classes WHERE id = ?');
    $stmt->execute([$classId]);
    $cls = $stmt->fetch();
    if (!$cls) fail('Class not found', 404);
    if ((int)$cls['teacher_id'] !== $teacherId) fail('Forbidden', 403);
    return $cls;
}

// Confirms the student is enrolled in the class; sends 403 otherwise.
function enrolled_or_fail(int $classId, int $studentId): void {
    $stmt = db()->prepare('SELECT 1 FROM enrollments WHERE class_id = ? AND student_id = ?');
    $stmt->execute([$classId, $studentId]);
    if (!$stmt->fetch()) fail('Not enrolled in this class', 403);
}

// Maximum accepted upload size. Keep this at or below the PHP settings
// `upload_max_filesize` and `post_max_size` of the deployment (XAMPP ships 40M).
function max_upload_bytes(): int {
    return 8 * 1024 * 1024;
}

// Extensions that may be stored. Uploads land inside the web root, so anything
// a web server might *execute* (php, phtml, phar, ...) or *interpret* as active
// content (html, svg, xhtml -> stored XSS against the app's own origin) must
// never get through. An allowlist, not a denylist.
function upload_allowed_extensions(): array {
    return [
        'pdf', 'doc', 'docx', 'odt', 'rtf', 'txt', 'md',
        'ppt', 'pptx', 'odp', 'xls', 'xlsx', 'ods', 'csv',
        'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic',
        'mp4', 'mov', 'm4v', 'webm', 'mp3', 'wav', 'm4a', 'ogg',
        'zip', '7z', 'rar', 'tar', 'gz',
    ];
}

// PHP discards the whole request body once it exceeds post_max_size, which
// would make an oversized upload look like an empty request (and be reported as
// a confusing "not found"). Reject it up front instead.
function guard_request_size(): void {
    $length = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
    if ($length > 0 && $length > max_upload_bytes() + 64 * 1024) {
        fail('File is too large. Maximum size is 8 MB.', 413);
    }
}
guard_request_size();

// Saves an uploaded file (field name $field) into /uploads, returns relative
// path, or null when no file was submitted. Rejects anything disallowed with a
// 4xx so callers do not silently misreport a rejected file as "no file sent".
function save_upload(string $field): ?string {
    if (empty($_FILES[$field])) return null;

    $error = $_FILES[$field]['error'];
    if ($error === UPLOAD_ERR_INI_SIZE || $error === UPLOAD_ERR_FORM_SIZE) {
        fail('File is too large.', 413);
    }
    if ($error !== UPLOAD_ERR_OK) return null;

    $size = (int)($_FILES[$field]['size'] ?? 0);
    if ($size <= 0) fail('The uploaded file is empty.');
    if ($size > max_upload_bytes()) fail('File is too large. Maximum size is 8 MB.', 413);

    $orig = (string)($_FILES[$field]['name'] ?? '');
    $ext = strtolower(pathinfo($orig, PATHINFO_EXTENSION));
    if (!in_array($ext, upload_allowed_extensions(), true)) {
        fail('This file type is not allowed. Upload a document, image, media file or archive.', 415);
    }

    $dir = __DIR__ . '/uploads';
    if (!is_dir($dir) && !mkdir($dir, 0755, true)) fail('Upload directory is not writable.', 500);

    // The stored name is generated, never taken from the client, and the
    // extension is known-good at this point.
    $name = bin2hex(random_bytes(8)) . '.' . $ext;
    $target = "$dir/$name";
    if (!move_uploaded_file($_FILES[$field]['tmp_name'], $target)) {
        fail('Could not store the uploaded file.', 500);
    }
    @chmod($target, 0644);
    return "uploads/$name";
}

function new_token(): string {
    return bin2hex(random_bytes(32));
}

// ---- Login throttling ------------------------------------------------------
// Caps password guesses per account per address so that online brute force of a
// 6-character minimum password is impractical. Deliberately counts failures for
// an (email, ip) pair, so one attacker cannot lock a victim out from elsewhere.
const LOGIN_MAX_ATTEMPTS = 10;
const LOGIN_WINDOW_MINUTES = 15;

function client_ip(): string {
    // REMOTE_ADDR only: X-Forwarded-For is caller-controlled unless a trusted
    // reverse proxy is configured to rewrite it, and trusting it would let an
    // attacker reset their own counter at will.
    return (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown');
}

function login_attempts_exceeded(string $email, string $ip): bool {
    $cutoff = date('Y-m-d H:i:s', time() - LOGIN_WINDOW_MINUTES * 60);
    $stmt = db()->prepare(
        'SELECT COUNT(*) FROM login_attempts
         WHERE email = ? AND ip = ? AND attempted_at > ?'
    );
    $stmt->execute([$email, $ip, $cutoff]);
    return (int)$stmt->fetchColumn() >= LOGIN_MAX_ATTEMPTS;
}

function record_login_failure(string $email, string $ip): void {
    db()->prepare('INSERT INTO login_attempts (email, ip) VALUES (?,?)')
        ->execute([$email, $ip]);
    // Opportunistic cleanup so the table cannot grow without bound.
    $cutoff = date('Y-m-d H:i:s', time() - LOGIN_WINDOW_MINUTES * 4 * 60);
    db()->prepare('DELETE FROM login_attempts WHERE attempted_at < ?')->execute([$cutoff]);
}

function clear_login_failures(string $email, string $ip): void {
    db()->prepare('DELETE FROM login_attempts WHERE email = ? AND ip = ?')
        ->execute([$email, $ip]);
}

// Read access to a class: teacher owns it OR student is enrolled. Returns class row.
function class_access_or_fail(int $classId, array $user): array {
    $stmt = db()->prepare('SELECT * FROM classes WHERE id = ?');
    $stmt->execute([$classId]);
    $cls = $stmt->fetch();
    if (!$cls) fail('Class not found', 404);
    if ($user['role'] === 'teacher') {
        if ((int)$cls['teacher_id'] !== (int)$user['id']) fail('Forbidden', 403);
    } else {
        enrolled_or_fail($classId, (int)$user['id']);
    }
    return $cls;
}

// Given a lesson id, returns [lesson, class] after checking access, else fails.
function lesson_access_or_fail(int $lessonId, array $user): array {
    $stmt = db()->prepare('SELECT * FROM lessons WHERE id = ?');
    $stmt->execute([$lessonId]);
    $lesson = $stmt->fetch();
    if (!$lesson) fail('Lesson not found', 404);
    $cls = class_access_or_fail((int)$lesson['class_id'], $user);
    return [$lesson, $cls];
}
