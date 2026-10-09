<?php
declare(strict_types=1);

// LMS runtime configuration. Secrets are read from environment variables or
// from an optional INI file outside the public document root. Never commit the
// real file; use backend/.env.example as the list of supported keys.

function lms_load_env_file(): void {
    $explicit = getenv('LMS_ENV_FILE');
    $candidates = [];
    if (is_string($explicit) && $explicit !== '') $candidates[] = $explicit;
    $candidates[] = dirname(__DIR__) . '/config/lms.env';

    foreach ($candidates as $path) {
        if (!is_file($path) || !is_readable($path)) continue;
        $values = parse_ini_file($path, false, INI_SCANNER_RAW);
        if (!is_array($values)) continue;
        foreach ($values as $key => $value) {
            if (getenv((string)$key) === false) {
                putenv((string)$key . '=' . (string)$value);
                $_ENV[(string)$key] = (string)$value;
            }
        }
        break;
    }
}
lms_load_env_file();

function lms_env(string $key, string $default = '', bool $allowEmpty = false): string {
    $value = getenv($key);
    if ($value === false) return $default;
    if ($value === '' && !$allowEmpty) return $default;
    return (string)$value;
}

function lms_env_bool(string $key, bool $default = false): bool {
    $value = getenv($key);
    if ($value === false || $value === '') return $default;
    return filter_var($value, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) ?? $default;
}

function lms_app_env(): string {
    return lms_env('LMS_APP_ENV', 'local');
}

function lms_is_production(): bool {
    return lms_app_env() === 'production';
}

function lms_app_key(): string {
    $key = lms_env('LMS_APP_KEY');
    if ($key === '') {
        if (lms_is_production()) {
            throw new RuntimeException('LMS_APP_KEY must be configured in production.');
        }
        return 'local-development-key-change-before-deployment';
    }
    return $key;
}

function lms_storage_path(): string {
    $default = dirname(__DIR__) . '/storage/uploads';
    return rtrim(lms_env('LMS_STORAGE_PATH', $default), DIRECTORY_SEPARATOR);
}

function lms_public_base_url(): string {
    return rtrim(lms_env('LMS_PUBLIC_BASE_URL', ''), '/');
}

function lms_demo_mode(): bool {
    return lms_env_bool('LMS_DEMO_MODE', false);
}

function lms_teacher_registration_enabled(): bool {
    return lms_env_bool(
        'LMS_ALLOW_TEACHER_REGISTRATION',
        lms_app_env() === 'local'
    );
}

$LMS_DB_HOST = lms_env('LMS_DB_HOST', '127.0.0.1');
$LMS_DB_PORT = lms_env('LMS_DB_PORT', '3306');
$LMS_DB_NAME = lms_env('LMS_DB_NAME', 'lms');
$LMS_DB_USER = lms_env('LMS_DB_USER', 'root');
$LMS_DB_PASS = lms_env('LMS_DB_PASS', '', true);

date_default_timezone_set('UTC');

function db(): PDO {
    static $conn = null;
    if ($conn instanceof PDO) return $conn;

    global $LMS_DB_HOST, $LMS_DB_PORT, $LMS_DB_NAME, $LMS_DB_USER, $LMS_DB_PASS;
    try {
        $conn = new PDO(
            "mysql:host={$LMS_DB_HOST};port={$LMS_DB_PORT};dbname={$LMS_DB_NAME};charset=utf8mb4",
            $LMS_DB_USER,
            $LMS_DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::ATTR_STRINGIFY_FETCHES => false,
            ]
        );
        $conn->exec("SET time_zone = '+00:00'");
        return $conn;
    } catch (PDOException $e) {
        error_log('LMS database connection failed: ' . $e->getMessage());
        throw new RuntimeException('Database unavailable.');
    }
}
