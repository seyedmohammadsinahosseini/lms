<?php
declare(strict_types=1);

// OTMS runtime configuration. Secrets are read from environment variables or
// from an optional INI file outside the public document root. Never commit the
// real file; use backend/.env.example as the list of supported keys.

function otms_load_env_file(): void {
    $explicit = getenv('OTMS_ENV_FILE');
    $candidates = [];
    if (is_string($explicit) && $explicit !== '') $candidates[] = $explicit;
    $candidates[] = dirname(__DIR__) . '/config/otms.env';

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
otms_load_env_file();

function otms_env(string $key, string $default = '', bool $allowEmpty = false): string {
    $value = getenv($key);
    if ($value === false) return $default;
    if ($value === '' && !$allowEmpty) return $default;
    return (string)$value;
}

function otms_env_bool(string $key, bool $default = false): bool {
    $value = getenv($key);
    if ($value === false || $value === '') return $default;
    return filter_var($value, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) ?? $default;
}

function otms_app_env(): string {
    return otms_env('OTMS_APP_ENV', 'local');
}

function otms_is_production(): bool {
    return otms_app_env() === 'production';
}

function otms_app_key(): string {
    $key = otms_env('OTMS_APP_KEY');
    if ($key === '') {
        if (otms_is_production()) {
            throw new RuntimeException('OTMS_APP_KEY must be configured in production.');
        }
        return 'local-development-key-change-before-deployment';
    }
    return $key;
}

function otms_storage_path(): string {
    $default = dirname(__DIR__) . '/storage/uploads';
    return rtrim(otms_env('OTMS_STORAGE_PATH', $default), DIRECTORY_SEPARATOR);
}

function otms_public_base_url(): string {
    return rtrim(otms_env('OTMS_PUBLIC_BASE_URL', ''), '/');
}

function otms_demo_mode(): bool {
    return otms_env_bool('OTMS_DEMO_MODE', false);
}

function otms_teacher_registration_enabled(): bool {
    return otms_env_bool(
        'OTMS_ALLOW_TEACHER_REGISTRATION',
        otms_app_env() === 'local'
    );
}

$OTMS_DB_HOST = otms_env('OTMS_DB_HOST', '127.0.0.1');
$OTMS_DB_PORT = otms_env('OTMS_DB_PORT', '3306');
$OTMS_DB_NAME = otms_env('OTMS_DB_NAME', 'otms');
$OTMS_DB_USER = otms_env('OTMS_DB_USER', 'root');
$OTMS_DB_PASS = otms_env('OTMS_DB_PASS', '', true);

date_default_timezone_set('UTC');

function db(): PDO {
    static $conn = null;
    if ($conn instanceof PDO) return $conn;

    global $OTMS_DB_HOST, $OTMS_DB_PORT, $OTMS_DB_NAME, $OTMS_DB_USER, $OTMS_DB_PASS;
    try {
        $conn = new PDO(
            "mysql:host={$OTMS_DB_HOST};port={$OTMS_DB_PORT};dbname={$OTMS_DB_NAME};charset=utf8mb4",
            $OTMS_DB_USER,
            $OTMS_DB_PASS,
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
        error_log('OTMS database connection failed: ' . $e->getMessage());
        throw new RuntimeException('Database unavailable.');
    }
}
