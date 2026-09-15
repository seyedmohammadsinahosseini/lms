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

// Saves an uploaded file (field name $field) into /uploads, returns relative path or null.
function save_upload(string $field): ?string {
    if (empty($_FILES[$field]) || $_FILES[$field]['error'] !== UPLOAD_ERR_OK) return null;
    $dir = __DIR__ . '/uploads';
    if (!is_dir($dir)) mkdir($dir, 0777, true);
    $orig = $_FILES[$field]['name'];
    $ext = pathinfo($orig, PATHINFO_EXTENSION);
    $safeExt = preg_match('/^[A-Za-z0-9]{1,8}$/', $ext) ? ".$ext" : '';
    $name = bin2hex(random_bytes(8)) . $safeExt;
    $target = "$dir/$name";
    if (!move_uploaded_file($_FILES[$field]['tmp_name'], $target)) return null;
    return "uploads/$name";
}

function new_token(): string {
    return bin2hex(random_bytes(32));
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
