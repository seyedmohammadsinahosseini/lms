<?php
// PDO connection for the OTMS database.
//
// Every value can be overridden from the environment, so a deployment never
// needs credentials committed to the repository. The defaults keep a stock
// XAMPP install (root, empty password) working with no setup:
//
//   Apache:  SetEnv OTMS_DB_PASS "..."
//   CLI:     OTMS_DB_PASS="..." php -S 127.0.0.1:8080
//
// Never point a public deployment at the default credentials.

// Reads an environment variable, falling back to $default when unset. An empty
// value counts as unset unless $allowEmpty is set (the DB password of a stock
// XAMPP root account really is the empty string).
function otms_env(string $key, string $default, bool $allowEmpty = false): string {
    $value = getenv($key);
    if ($value === false) return $default;
    if ($value === '' && !$allowEmpty) return $default;
    return $value;
}

$OTMS_DB_HOST = otms_env('OTMS_DB_HOST', '127.0.0.1');
$OTMS_DB_NAME = otms_env('OTMS_DB_NAME', 'otms');
$OTMS_DB_USER = otms_env('OTMS_DB_USER', 'root');
$OTMS_DB_PASS = otms_env('OTMS_DB_PASS', '', true);

function db(): PDO {
    static $conn = null;
    if ($conn === null) {
        global $OTMS_DB_HOST, $OTMS_DB_NAME, $OTMS_DB_USER, $OTMS_DB_PASS;
        try {
            $conn = new PDO(
                "mysql:host=$OTMS_DB_HOST;dbname=$OTMS_DB_NAME;charset=utf8mb4",
                $OTMS_DB_USER,
                $OTMS_DB_PASS,
                [
                    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES => false,
                ]
            );
        } catch (PDOException $e) {
            // The message contains the DSN, the user name and often the host
            // name; log it and tell the client nothing.
            error_log('OTMS database connection failed: ' . $e->getMessage());
            if (function_exists('fail')) {
                fail('Database unavailable.', 500);
            }
            http_response_code(500);
            echo json_encode(['error' => 'Database unavailable.']);
            exit;
        }
    }
    return $conn;
}
