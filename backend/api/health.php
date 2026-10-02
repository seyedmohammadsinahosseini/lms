<?php
declare(strict_types=1);
require_once __DIR__ . '/../helpers.php';
require_method('GET');
try {
    db()->query('SELECT 1')->fetchColumn();
    $database = 'ok';
} catch (Throwable) {
    $database = 'unavailable';
}
$status = $database === 'ok' ? 200 : 503;
send(['status' => $database === 'ok' ? 'ok' : 'degraded', 'database' => $database, 'time' => gmdate(DATE_ATOM), 'version' => '2.0.0'], $status);
